clc
clear
close all
set(0,'defaultAxesFontSize', 12)
set(0, 'DefaultLineLineWidth', 2);
rng('default');

addpath("data_CAN_txt\");
%% conversione .log --> .mat
% num byte  0   1  2  3  4  5  6  7
% 0x703 s 8 01 08 07 41 1C CD 01 00

varNames = {'time','txrx','channel','canID','type','DLC','B0','B1','B2','B3','B4','B5','B6','B7'} ;
varTypes = {'string','string','string','string','string','string','string',...
        'string','string','string','string','string','string','string'} ;
delimiter = ' ';
dataStartLine = 14;

opts = delimitedTextImportOptions('VariableNames',varNames,... 
                                'VariableTypes',varTypes,...
                                'Delimiter',delimiter,...
                                'DataLines', dataStartLine);


dfiles250 = dir('.\data_CAN_txt\TESMEC_CAN_250kbaud\*.log'); %tutti i file .txt nella directory
dfiles500 = dir('.\data_CAN_txt\TESMEC_CAN_500kbaud\*.log'); %tutti i file .txt nella directory
path_save1 = ".\data_CAN_mat\";

msg250 = ["0x703";"0x1CFD08C1";"0x1CFD08C2";"0x18FEEE00";"0x18FEEEC1";"0x18FEEEC2";"0x18FEEF00";"0x18FEF700";"0xCF00400";"0xC000003"];
msg500 = ["0x703";"0x100";"0x150";"0x151";"0x153";"0x155";"0x10B"];


for k = 1 : length(dfiles250)
    file250 = dfiles250(k).name  %nome file
    file500 = dfiles500(k).name;

%     file250 = "Test_100.log";  %nome file
%     file500 = "PROVA_100.log";

    data250=readtable(strcat("./data_CAN_txt/TESMEC_CAN_250kbaud/",file250),opts);
    data500=readtable(strcat("./data_CAN_txt/TESMEC_CAN_500kbaud/",file500),opts);

    CANmsg = cell(size(msg250,1)+size(msg500,1),4);
    for i=1:1:size(msg250,1)
        CANmsg{i,1}=msg250(i);
        CANmsg{i,2}=250;
    end
    for i=size(msg250,1)+1:1:size(msg250,1)+size(msg500,1)
        CANmsg{i,1}=msg500(i-size(msg250,1));
        CANmsg{i,2}=500;
    end
    
    for i=1:1:size(msg250,1)+size(msg500,1)        
        if CANmsg{i,2}==250
            % cerco msg nel file a 250kbaud
            data_app = data250(data250.canID == CANmsg{i,1},:); 
            timestamp = data_app.time;
            AllBytes = strcat(data_app.B0,data_app.B1,data_app.B2,data_app.B3,data_app.B4,data_app.B5,data_app.B6,data_app.B7);    
            switch CANmsg{i,1}
                case "0x703"
                    % la conversione hex --> dec legge da Dx a Sx
                    %  0  1  2  3  4  5  6  7 
                    % 01| B0 04| 9B 31|73 03| 00
                    %   | rpm  |dutyY3|actY3|
                    %             <--   <--
                    CANmsg{i,4} = "rpm - dutyY3 - actY3";                    
                    PressStartBut = extractBetween(string(dec2bin(hex2dec(data_app.B0),8)),7,7);
                    RpmAuto = extractBetween(string(dec2bin(hex2dec(data_app.B0),8)),8,8);
                    RpmHex = strcat(data_app.B2,data_app.B1);
                    RpmDec = hex2dec(RpmHex);
                    PWMHex = strcat(data_app.B4,data_app.B3);
                    PWMDec = hex2dec(PWMHex); 
                    Y3Hex = strcat(data_app.B6,data_app.B5);
                    Y3Dec_mA = hex2dec(Y3Hex);
                    tab = table(timestamp,AllBytes,PressStartBut,RpmAuto,RpmHex,RpmDec,PWMHex,PWMDec,Y3Hex,Y3Dec_mA);                    
                
                case "0x1CFD08C1" 
                    % proprietà olio
                    % viscosità [byte 0,1], densità[byte 2,3], costante dielettrica[byte 6,7]
                    CANmsg{i,4} = "viscosità - densità - costante dielettrica";
                    ViscHex =  strcat(data_app.B1,data_app.B0); 
                    ViscDec_cP =  hex2dec(ViscHex)*0.015625;
                    DensHex =  strcat(data_app.B3,data_app.B2); 
                    DensDec_gcm3 =  hex2dec(DensHex)*0.00003052;
                    CostDieHex =  strcat(data_app.B7,data_app.B6); 
                    CostDieDec =  hex2dec(CostDieHex)*0.00012207;
                    tab = table(timestamp,AllBytes,ViscHex,ViscDec_cP,DensHex,DensDec_gcm3,CostDieHex,CostDieDec);
                
                case "0x1CFD08C2"
                    % proprietà olio
                    % viscosità [byte 0,1], densità[byte 2,3], costante dielettrica[byte 6,7]
                    CANmsg{i,4} = "viscosità - densità - costante dielettrica";
                    ViscHex =  strcat(data_app.B1,data_app.B0); 
                    ViscDec_cP =  hex2dec(ViscHex)*0.015625;
                    DensHex =  strcat(data_app.B3,data_app.B2); 
                    DensDec_gcm3 =  hex2dec(DensHex)*0.00003052;
                    CostDieHex =  strcat(data_app.B7,data_app.B6); 
                    CostDieDec =  hex2dec(CostDieHex)*0.00012207;
                    tab = table(timestamp,AllBytes,ViscHex,ViscDec_cP,DensHex,DensDec_gcm3,CostDieHex,CostDieDec);
                
                case "0x18FEEE00"
                    % temperatura olio --> non è nel formato del datasheet
                    % su tabella CAN non ci sono info sulla conversione
                    CANmsg{i,4} = "temperatura olio - diverso da C1 e C2";
                    TempHex =  strcat(data_app.B1); 
                    TempDec_C = hex2dec(TempHex)-40;
                    tab = table(timestamp,AllBytes,TempHex,TempDec_C);
%                     tab = table(timestamp,AllBytes);
                
                case "0x18FEEEC1"
                    CANmsg{i,4} = "temperatura olio";
                    TempHex =  strcat(data_app.B3,data_app.B2); 
                    TempDec_C =  (hex2dec(TempHex)*0.03125)-273;
                    tab = table(timestamp,AllBytes,TempHex,TempDec_C);
                
                case "0x18FEEEC2"
                    CANmsg{i,4} = "temperatura olio";
                    TempHex =  strcat(data_app.B3,data_app.B2); 
                    TempDec_C =  (hex2dec(TempHex)*0.03125)-273;
                    tab = table(timestamp,AllBytes,TempHex,TempDec_C);
                
                case "0x18FEEF00"
                    % actual engine - percent torque
                    CANmsg{i,4} = "pressione olio motore";
                    PolioHex = data_app.B3;
                    PolioDec = hex2dec(PolioHex)*0.04;
                    tab = table(timestamp,AllBytes,PolioHex,PolioDec);
                
                case "0x18FEF700"
                    % electrical potential, battery potential
                    % mancano informazioni su conversione
                    CANmsg{i,4} = "battery potential - kill switch battery potential";
%                     ElPotHex = strcat(data_app.B3,data_app.B2);
%                     ElPotDec = hex2dec(ElPotHex);
                    killSwitch = extractBetween(string(dec2bin(hex2dec(data_app.B5),8)),8,8);

                    BattPotHex = strcat(data_app.B5,data_app.B4);
                    BattPotDec = hex2dec(BattPotHex)*0.05;

    
                    tab = table(timestamp,AllBytes,killSwitch,BattPotHex,BattPotDec);
                
                case "0xCF00400"
                    % actual engine - percent torque, engine speed
                    % controllare
                    CANmsg{i,4} = "actual engine %torque - engine speed";
                    TorqHex = data_app.B2;
                    TorqDec = hex2dec(TorqHex)-125;

                    SpeedHex =  strcat(data_app.B4,data_app.B3); 
                    SpeedDec =  hex2dec(SpeedHex)*0.125;

                    tab = table(timestamp,AllBytes,TorqHex,TorqDec,SpeedHex,SpeedDec);
                case "0xC000003"
                    CANmsg{i,4} = "rpm motor set";
                    rpmHex = strcat(data_app.B2,data_app.B1);
                    rpmDec = hex2dec(rpmHex)*0.125;

                    tab = table(timestamp,AllBytes,rpmHex,rpmDec);
            end
        else
            % cerco msg nel file a 500kbaud
            data_app = data500(data500.canID == CANmsg{i,1},:); 
            timestamp = data_app.time;
            AllBytes = strcat(data_app.B0,data_app.B1,data_app.B2,data_app.B3,data_app.B4,data_app.B5,data_app.B6,data_app.B7);    
            switch CANmsg{i,1}
                case "0x703"
                    CANmsg{i,4} = "rpm - dutyY3 - actY3";                    
                    PressStartBut = extractBetween(string(dec2bin(hex2dec(data_app.B0),8)),7,7);
                    RpmAuto = extractBetween(string(dec2bin(hex2dec(data_app.B0),8)),8,8);
                    RpmHex = strcat(data_app.B2,data_app.B1);
                    RpmDec = hex2dec(strcat(data_app.B2,data_app.B1));
                    PWMHex = strcat(data_app.B4,data_app.B3);
                    PWMDec = hex2dec(strcat(data_app.B4,data_app.B3)); 
                    Y3Hex = strcat(data_app.B6,data_app.B5);
                    Y3Dec_mA = hex2dec(strcat(data_app.B6,data_app.B5));
                    tab = table(timestamp,AllBytes,PressStartBut,RpmAuto,RpmHex,RpmDec,PWMHex,PWMDec,Y3Hex,Y3Dec_mA);
                
                case "0x100"
                    % battery voltage, procedura warm-up in corso,
                    % temperatura olio, fuel level, rpm
                    % non ci sono info su conversione
                    CANmsg{i,4} = "battery voltage - procedura warm-up - temperatura olio - fuel level - rpm";
                    PreRisc = extractBetween(string(dec2bin(hex2dec(data_app.B1),8)),2,2);% è il 6 bit da Dx, quindi il 2 da Sx
                    
                    TempHex =  strcat(data_app.B3,data_app.B2); 
                    TempDec_C = hex2dec(TempHex);
                    RpmHex = strcat(data_app.B7,data_app.B6);
                    RpmDec = hex2dec(RpmHex);
                    FuelHex = data_app.B4;
                    FuelDec = hex2dec(FuelHex); %percentuale?
                    BattHex = data_app.B0;
                    BattDec = hex2dec(BattHex); %volt?

                    tab = table(timestamp,AllBytes,PreRisc,TempHex,TempDec_C,RpmHex,RpmDec,FuelHex,FuelDec,BattHex,BattDec);
                
                case "0x150"
                    % attivazione ventola raffreddamento
                    % E1 00 00 20 00 00 00 00 in altri test ho A1 invece di
                    % E1, in altri 00. Ho sempre (?) quel 20 al centro 
                    CANmsg{i,4} = "attivazione ventola raffreddamento";

                    AttVentola = extractBetween(string(dec2bin(hex2dec(data_app.B0),8)),2,2);% è il 6 bit da Dx, quindi il 2 da Sx
                    % AttVentola = dec2bin(hex2dec(data_app.B0));
                    tab = table(timestamp,AllBytes,AttVentola);
                
                case "0x151"
                    % duty cycle PWM Y3
                    % gli altri bytes?
                    CANmsg{i,4} = "duty cycle PWM Y3";
                    PWMHex = strcat(data_app.B7,data_app.B6);
                    PWMDec = hex2dec(PWMHex);
                    tab = table(timestamp,AllBytes,PWMHex,PWMDec);
                
                case "0x153" 
                    % current cycle PWM Y3
                    % quali bytes?
                    CANmsg{i,4} = "current cycle PWM Y3";
                    CurrPWMHex = strcat(data_app.B7,data_app.B6);
                    CurrPWMDec = hex2dec(CurrPWMHex);
                    tab = table(timestamp,AllBytes,CurrPWMHex,CurrPWMDec);
                
                case "0x155"
                    % temperatura olio, pressione BP4
                    % quali bytes? controllare
                    CANmsg{i,4} = "temperatura olio - pressione BP4";
                    TempHex =  strcat(data_app.B3,data_app.B2); 
                    TempDec_C = hex2dec(TempHex);
                    BP4Hex = strcat(data_app.B7,data_app.B6); 
                    BP4Dec = hex2dec(BP4Hex);
                    tab = table(timestamp,AllBytes,TempHex,TempDec_C,BP4Hex,BP4Dec);
                case "0x10B"
                    CANmsg{i,4} = "ref Y3 - act Y3";
                    RefY3Hex =  strcat(data_app.B6); 
                    RefY3Dec = hex2dec(RefY3Hex);
                    ActY3Hex = strcat(data_app.B7); 
                    ActY3Dec = hex2dec(ActY3Hex);
                    tab = table(timestamp,AllBytes,RefY3Hex,RefY3Dec,ActY3Hex,ActY3Dec);

            end
        end
        CANmsg{i,3}=tab;
    end
    save(strcat(path_save1,"\CANmsg_",extractBetween(file250,6,8),".mat"),"CANmsg")
end


