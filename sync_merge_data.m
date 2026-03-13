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
varNames_can = {'time','txrx','canID','type', ...
                'B0','B1','B2','B3','B4','B5','B6','B7'};
varTypes_can = repmat({'string'}, 1, numel(varNames_can));
opts_can     = delimitedTextImportOptions( ...
    'VariableNames', varNames_can, ...
    'VariableTypes', varTypes_can, ...
    'Delimiter',     ' ', ...
    'DataLines',     15);

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

    data250 = rimuovi_missing(data250, opts_can);
    data500 = rimuovi_missing(data500, opts_can);
    
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
