
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
