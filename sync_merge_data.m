clear; close all; clc;

%% ========================================================================
%  SYNC_MERGE_DATA
%  Per ogni test carica i dati da tre fonti (CDAQ, CAN250, CAN500),
%  sincronizza sul primo fronte di salita del segnale di sincronismo,
%  taglia i dati prima del fronte e li uniforma alla durata minima comune,
%  poi salva il risultato in Results/<test_id>.mat come struttura con
%  tre tabelle: test_data.CDAQ, test_data.CAN250, test_data.CAN500.
%
%  Segnale di sincronismo:
%    CDAQ  → canale analogico 'Sincro' (0–24 V); soglia: SYNC_THR_CDAQ [V]
%    CAN   → messaggio 0x1FF, bit 0 di B0 (segnale binario 0/1)
%             Fallback CAN250: bit PressStartBut (bit 1 di B0) del msg 0x703
% ========================================================================

addpath(genpath('Support/'));

%% --- Percorsi -----------------------------------------------------------
path_cdaq    = fullfile('Data', 'CDAQ');
path_can250  = fullfile('Data', 'CAN250');
path_can500  = fullfile('Data', 'CAN500');
path_results = 'Results';

if ~exist(path_results, 'dir'), mkdir(path_results); end

%% --- Configurazione CDAQ ------------------------------------------------
fs_cdaq       = 10000;          % [Hz] frequenza di campionamento CDAQ
labview_epoch = datetime(1904, 1, 1);
cdaq_channels = {'Tempo','Sincro','Controllo_Y3','Pressione_monte', ...
                 'Pressione_valle','Pressione_BP4'};
SYNC_THR_CDAQ = 5;              % [V] soglia fronte di salita segnale analogico

%% --- Opzioni importazione CAN -------------------------------------------
varNames_can = {'time','txrx','channel','canID','type','DLC', ...
                'B0','B1','B2','B3','B4','B5','B6','B7'};
varTypes_can = repmat({'string'}, 1, numel(varNames_can));
opts_can     = delimitedTextImportOptions( ...
    'VariableNames', varNames_can, ...
    'VariableTypes', varTypes_can, ...
    'Delimiter',     ' ', ...
    'DataLines',     14);

%% --- ID messaggi CAN da estrarre ----------------------------------------
msg250 = ["0x703"; "0x1CFD08C1"; "0x1CFD08C2"; "0x18FEEE00"; "0x18FEEEC1"; ...
          "0x18FEEEC2"; "0x18FEEF00"; "0x18FEF700"; "0xCF00400"; "0xC000003"; "0x1FF"];
msg500 = ["0x703"; "0x100"; "0x150"; "0x151"; "0x153"; "0x155"; "0x10B"; "0x1FF"];

%% --- Trova i test dai file CDAQ (test_XXX.tdms → ID = XXX) --------------
cdaq_files = dir(fullfile(path_cdaq, 'test_*.tdms'));
if isempty(cdaq_files)
    error('Nessun file TDMS trovato in: %s', path_cdaq);
end
fprintf('Trovati %d test da elaborare.\n\n', numel(cdaq_files));

%% ========================================================================
%  Ciclo sui test
%% ========================================================================
for t = 1:numel(cdaq_files)

    fname   = cdaq_files(t).name;   % es. 'test_001.tdms'
    test_id = fname(6:end-5);       % es. '001'
    fprintf('=== Test %s ===\n', test_id);

    % ---- 1. Carica dati CDAQ --------------------------------------------
    opt_cdaq.columns_name = cdaq_channels;
    opt_cdaq.fs           = fs_cdaq;
    cdaq_file = fullfile(path_cdaq, fname);

    raw_cdaq = Tesmec_load_file_labview(cdaq_file, opt_cdaq);

    N_cdaq = numel(raw_cdaq.Sincro);
    t_cdaq = (0 : N_cdaq-1)' / fs_cdaq;   % vettore tempo [s] dall'inizio

    % ---- 2. Fronte di salita del sync CDAQ ------------------------------
    above     = raw_cdaq.Sincro(:) >= SYNC_THR_CDAQ;
    edge_cdaq = find(diff([false; above]) == 1, 1, 'first');

    if isempty(edge_cdaq)
        warning('Nessun fronte di salita sync CDAQ per il test %s – salto.\n', test_id);
        continue
    end
    t0_cdaq = t_cdaq(edge_cdaq);
    fprintf('  CDAQ  sync @ %.4f s  (campione %d)\n', t0_cdaq, edge_cdaq);

    % ---- 3. Carica dati CAN ---------------------------------------------
    file250 = fullfile(path_can250, sprintf('%s.trc', test_id));
    file500 = fullfile(path_can500, sprintf('%s.trc', test_id));

    data250  = readtable(file250, opts_can);
    data500  = readtable(file500, opts_can);

    t_raw250 = parse_can_time(data250.time);
    t_raw500 = parse_can_time(data500.time);

    % ---- 4. Fronte di salita del sync CAN -------------------------------
    % CAN500: messaggio 0x1FF, bit 0 di B0 (posizione 8 in stringa dec2bin a 8 bit)
    t0_can500 = find_can_sync(data500, t_raw500, "0x1FF", 8);
    if isnan(t0_can500)
        warning('Nessun sync in CAN500 per test %s – salto.\n', test_id);
        continue
    end

    % CAN250: prima cerca 0x1FF; se assente, usa PressStartBut da 0x703 (bit 1, pos 7)
    t0_can250 = find_can_sync(data250, t_raw250, "0x1FF", 8);
    if isnan(t0_can250)
        fprintf('  CAN250: 0x1FF non trovato, uso PressStartBut (0x703 bit1)\n');
        t0_can250 = find_can_sync(data250, t_raw250, "0x703", 7);
    end
    if isnan(t0_can250)
        warning('Nessun sync in CAN250 per test %s – salto.\n', test_id);
        continue
    end

    fprintf('  CAN250 sync @ %.4f s\n', t0_can250);
    fprintf('  CAN500 sync @ %.4f s\n', t0_can500);

    % ---- 5. Sposta origine temporale al fronte di salita e taglia il pre-sync --

    % CDAQ: taglia i campioni prima del fronte
    idx_range = edge_cdaq : N_cdaq;
    t_cdaq_s  = t_cdaq(idx_range) - t0_cdaq;
    Sincro_s  = raw_cdaq.Sincro(idx_range);
    CtrlY3_s  = raw_cdaq.Controllo_Y3(idx_range);
    Pmonte_s  = raw_cdaq.Pressione_monte(idx_range);
    Pvalle_s  = raw_cdaq.Pressione_valle(idx_range);
    PBP4_s    = raw_cdaq.Pressione_BP4(idx_range);

    % CAN250: mantieni solo righe con timestamp >= sync edge
    keep250   = t_raw250 >= t0_can250;
    data250_s = data250(keep250, :);
    t250_s    = t_raw250(keep250) - t0_can250;

    % CAN500
    keep500   = t_raw500 >= t0_can500;
    data500_s = data500(keep500, :);
    t500_s    = t_raw500(keep500) - t0_can500;

    % ---- 6. Calcola fine comune e taglia la parte finale ----------------
    t_end = min([t_cdaq_s(end), t250_s(end), t500_s(end)]);
    fprintf('  Finestra comune: 0 → %.4f s\n', t_end);

    % CDAQ
    last_cdaq = find(t_cdaq_s <= t_end, 1, 'last');
    t_cdaq_s  = t_cdaq_s(1 : last_cdaq);
    Sincro_s  = Sincro_s(1 : last_cdaq);
    CtrlY3_s  = CtrlY3_s(1 : last_cdaq);
    Pmonte_s  = Pmonte_s(1 : last_cdaq);
    Pvalle_s  = Pvalle_s(1 : last_cdaq);
    PBP4_s    = PBP4_s(1 : last_cdaq);

    % CAN250
    cut250       = t250_s <= t_end;
    data250_trim = data250_s(cut250, :);
    t250_trim    = t250_s(cut250);

    % CAN500
    cut500       = t500_s <= t_end;
    data500_trim = data500_s(cut500, :);
    t500_trim    = t500_s(cut500);

    % ---- 7. Costruisci struttura di output ------------------------------

    % Tabella CDAQ
    CDAQ_table = table(t_cdaq_s, Sincro_s, CtrlY3_s, Pmonte_s, Pvalle_s, PBP4_s, ...
        'VariableNames', {'time_s','Sincro','Controllo_Y3', ...
                          'Pressione_monte','Pressione_valle','Pressione_BP4'});

    % Tabelle CAN (cell array CANmsg, compatibile con Conversione_logCAN_mat)
    CAN250_table = decode_can_data(data250_trim, t250_trim, msg250, 250);
    CAN500_table = decode_can_data(data500_trim, t500_trim, msg500, 500);

    % Struttura finale
    test_data.CDAQ   = CDAQ_table;
    test_data.CAN250 = CAN250_table;
    test_data.CAN500 = CAN500_table;

    % ---- 8. Salva -------------------------------------------------------
    out_file = fullfile(path_results, sprintf('%s.mat', test_id));
    save(out_file, 'test_data');
    fprintf('  Salvato → %s\n\n', out_file);

end
fprintf('Elaborazione completata.\n');


%% ========================================================================
%  Funzioni locali
%% ========================================================================

function t_sec = parse_can_time(time_col)
% PARSE_CAN_TIME  Converte la colonna timestamp CAN in secondi (vettore double).
%
% Gestisce due formati:
%   Numerico   "1234.5678"   → trattato come ms se mediana > 1000, altrimenti s
%   HH:MM:SS   "00:01:23.456" → converte in secondi
%
    str_arr = strtrim(string(time_col));
    n       = numel(str_arr);
    t_sec   = zeros(n, 1);

    for i = 1:n
        s = char(str_arr(i));
        if contains(s, ':')
            parts   = strsplit(s, ':');
            t_sec(i) = str2double(parts{1})*3600 + ...
                       str2double(parts{2})*60   + ...
                       str2double(parts{3});
        else
            t_sec(i) = str2double(s);
        end
    end

    % Se i valori sono in millisecondi (mediana > 1000) converte in secondi
    if median(t_sec, 'omitnan') > 1000
        t_sec = t_sec / 1000;
    end

    % Rende il vettore relativo all'inizio del file
    t_sec = t_sec - t_sec(1);
end

% -------------------------------------------------------------------------

function t_edge = find_can_sync(data_tbl, t_vec, msg_id, bit_pos)
% FIND_CAN_SYNC  Trova il primo fronte di salita del bit di sync CAN.
%
%   data_tbl : tabella CAN completa
%   t_vec    : vettore tempi [s] corrispondente a data_tbl
%   msg_id   : stringa ID messaggio (es. "0x1FF")
%   bit_pos  : posizione del bit nella stringa dec2bin(B0, 8)
%              (8 = LSB / bit0,  1 = MSB / bit7)
%
    t_edge = NaN;
    idx    = find(data_tbl.canID == msg_id);
    if isempty(idx), return; end

    % Decodifica il bit dalla colonna B0 del messaggio selezionato
    b0_vals  = data_tbl.B0(idx);
    b0_dec   = hex2dec(b0_vals);                       % double array
    b0_bin   = string(dec2bin(b0_dec, 8));             % string array Nx1
    sync_bit = str2double(extractBetween(b0_bin, bit_pos, bit_pos));

    t_msg   = t_vec(idx);
    rising  = find(diff([0; sync_bit]) == 1, 1, 'first');
    if ~isempty(rising)
        t_edge = t_msg(rising);
    end
end

% -------------------------------------------------------------------------

function CANmsg = decode_can_data(data_tbl, t_vec, msg_ids, baudrate)
% DECODE_CAN_DATA  Decodifica i messaggi CAN dalla tabella già ritagliata.
%
% Restituisce cell array CANmsg (Nx4):
%   col 1: ID messaggio (string)
%   col 2: baud rate (250 o 500)
%   col 3: tabella MATLAB con dati decodificati (time_s + grandezze fisiche)
%   col 4: descrizione (string)
%
    CANmsg = cell(numel(msg_ids), 4);

    for i = 1:numel(msg_ids)
        CANmsg{i,1} = msg_ids(i);
        CANmsg{i,2} = baudrate;

        mask     = data_tbl.canID == msg_ids(i);
        d        = data_tbl(mask, :);           % righe del messaggio corrente
        time_s   = t_vec(mask);                 % [s] dall'inizio sincronizzato
        AllBytes = strcat(d.B0,d.B1,d.B2,d.B3,d.B4,d.B5,d.B6,d.B7);

        tab  = table();
        desc = msg_ids(i);

        if baudrate == 250
            switch msg_ids(i)
                case "0x703"
                    desc          = "rpm - dutyY3 - actY3";
                    PressStartBut = extractBetween(string(dec2bin(hex2dec(d.B0),8)),7,7);
                    RpmAuto       = extractBetween(string(dec2bin(hex2dec(d.B0),8)),8,8);
                    RpmDec        = hex2dec(strcat(d.B2,d.B1));
                    PWMDec        = hex2dec(strcat(d.B4,d.B3));
                    Y3Dec_mA      = hex2dec(strcat(d.B6,d.B5));
                    tab = table(time_s,AllBytes,PressStartBut,RpmAuto,RpmDec,PWMDec,Y3Dec_mA);

                case "0x1CFD08C1"
                    desc         = "viscosità - densità - costante dielettrica (sens 1)";
                    ViscDec_cP   = hex2dec(strcat(d.B1,d.B0)) * 0.015625;
                    DensDec_gcm3 = hex2dec(strcat(d.B3,d.B2)) * 0.00003052;
                    CostDieDec   = hex2dec(strcat(d.B7,d.B6)) * 0.00012207;
                    tab = table(time_s,AllBytes,ViscDec_cP,DensDec_gcm3,CostDieDec);

                case "0x1CFD08C2"
                    desc         = "viscosità - densità - costante dielettrica (sens 2)";
                    ViscDec_cP   = hex2dec(strcat(d.B1,d.B0)) * 0.015625;
                    DensDec_gcm3 = hex2dec(strcat(d.B3,d.B2)) * 0.00003052;
                    CostDieDec   = hex2dec(strcat(d.B7,d.B6)) * 0.00012207;
                    tab = table(time_s,AllBytes,ViscDec_cP,DensDec_gcm3,CostDieDec);

                case "0x18FEEE00"
                    desc      = "temperatura olio";
                    TempDec_C = hex2dec(d.B1) - 40;
                    tab = table(time_s,AllBytes,TempDec_C);

                case "0x18FEEEC1"
                    desc      = "temperatura olio (sens 1)";
                    TempDec_C = hex2dec(strcat(d.B3,d.B2)) * 0.03125 - 273;
                    tab = table(time_s,AllBytes,TempDec_C);

                case "0x18FEEEC2"
                    desc      = "temperatura olio (sens 2)";
                    TempDec_C = hex2dec(strcat(d.B3,d.B2)) * 0.03125 - 273;
                    tab = table(time_s,AllBytes,TempDec_C);

                case "0x18FEEF00"
                    desc     = "pressione olio motore";
                    PolioDec = hex2dec(d.B3) * 0.04;
                    tab = table(time_s,AllBytes,PolioDec);

                case "0x18FEF700"
                    desc       = "battery potential - kill switch";
                    killSwitch = extractBetween(string(dec2bin(hex2dec(d.B5),8)),8,8);
                    BattPotDec = hex2dec(strcat(d.B5,d.B4)) * 0.05;
                    tab = table(time_s,AllBytes,killSwitch,BattPotDec);

                case "0xCF00400"
                    desc     = "actual engine %torque - engine speed";
                    TorqDec  = hex2dec(d.B2) - 125;
                    SpeedDec = hex2dec(strcat(d.B4,d.B3)) * 0.125;
                    tab = table(time_s,AllBytes,TorqDec,SpeedDec);

                case "0xC000003"
                    desc   = "rpm motor set";
                    rpmDec = hex2dec(strcat(d.B2,d.B1)) * 0.125;
                    tab = table(time_s,AllBytes,rpmDec);

                case "0x1FF"
                    desc   = "syncro";
                    syncro = extractBetween(string(dec2bin(hex2dec(d.B0),8)),8,8);
                    tab = table(time_s,AllBytes,syncro);
            end

        else  % 500 kbaud
            switch msg_ids(i)
                case "0x703"
                    desc          = "rpm - dutyY3 - actY3";
                    PressStartBut = extractBetween(string(dec2bin(hex2dec(d.B0),8)),7,7);
                    RpmAuto       = extractBetween(string(dec2bin(hex2dec(d.B0),8)),8,8);
                    RpmDec        = hex2dec(strcat(d.B2,d.B1));
                    PWMDec        = hex2dec(strcat(d.B4,d.B3));
                    Y3Dec_mA      = hex2dec(strcat(d.B6,d.B5));
                    tab = table(time_s,AllBytes,PressStartBut,RpmAuto,RpmDec,PWMDec,Y3Dec_mA);

                case "0x100"
                    desc      = "battery - warm-up - temp olio - fuel - rpm";
                    PreRisc   = extractBetween(string(dec2bin(hex2dec(d.B1),8)),2,2);
                    TempDec_C = hex2dec(strcat(d.B3,d.B2));
                    RpmDec    = hex2dec(strcat(d.B7,d.B6));
                    FuelDec   = hex2dec(d.B4);
                    BattDec   = hex2dec(d.B0);
                    tab = table(time_s,AllBytes,PreRisc,TempDec_C,RpmDec,FuelDec,BattDec);

                case "0x150"
                    desc       = "attivazione ventola raffreddamento";
                    AttVentola = extractBetween(string(dec2bin(hex2dec(d.B0),8)),2,2);
                    tab = table(time_s,AllBytes,AttVentola);

                case "0x151"
                    desc   = "duty cycle PWM Y3";
                    PWMDec = hex2dec(strcat(d.B7,d.B6));
                    tab = table(time_s,AllBytes,PWMDec);

                case "0x153"
                    desc       = "current cycle PWM Y3";
                    CurrPWMDec = hex2dec(strcat(d.B7,d.B6));
                    tab = table(time_s,AllBytes,CurrPWMDec);

                case "0x155"
                    desc      = "temperatura olio - pressione BP4";
                    TempDec_C = hex2dec(strcat(d.B3,d.B2));
                    BP4Dec    = hex2dec(strcat(d.B7,d.B6));
                    tab = table(time_s,AllBytes,TempDec_C,BP4Dec);

                case "0x10B"
                    desc     = "ref Y3 - act Y3";
                    RefY3Dec = hex2dec(d.B6);
                    ActY3Dec = hex2dec(d.B7);
                    tab = table(time_s,AllBytes,RefY3Dec,ActY3Dec);

                case "0x1FF"
                    desc   = "syncro";
                    syncro = extractBetween(string(dec2bin(hex2dec(d.B0),8)),8,8);
                    tab = table(time_s,AllBytes,syncro);
            end
        end

        CANmsg{i,3} = tab;
        CANmsg{i,4} = desc;
    end
end
