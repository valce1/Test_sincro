clear variables; close all; clc;

% add to path needed files
addpath(genpath('Support\'));

path_data = 'C:\Users\User\Desktop\Progetti_Aziende\Tesmec\2024\Campagna_sperimentale\Data\NI\Analog\';
known_file_type = '.tdms';



path_results = 'Results_NI_Analog\';

% Ottieni tutti i nomi dei file nella directory
file_list = dir(path_data);

labview_epoch = datetime(1904, 1, 1);

opt.columns_name = {'Tempo','Pressione_monte','Pressione_valle','Pressione_BP4',...
    'Sincro','Controllo_Y3'};
opt.fs = 10000; %[Hz]

% opt.columns_name = {'Tempo_CAN',...
%     'Primo_byte_CAN','Secondo_byte_CAN','Terzo_byte_CAN','Quarto_byte_CAN',...
%     'Quinto_byte_CAN','Sesto_byte_CAN','Settimo_byte_CAN','Ottavo_byte_CAN',...
%     'ID_CAN'};

% k = 1;

% Ciclo attraverso tutti i file nella directory
for i = 1:length(file_list)
    % Ignora le directory speciali '.' e '..'
    if strcmp(file_list(i).name, '.') || strcmp(file_list(i).name, '..')
        continue;
    end
    
    % Costruisci il percorso completo del file
    file_path = fullfile(path_data, file_list(i).name);
    
    [~, ~, file_extension] = fileparts(file_path);

    % Controlla se il file è un file regolare e non una directory
    if ~isdir(file_path) && strcmpi(file_extension, known_file_type)


        % Richiama la funzione di importazione sul file
        % https://github.com/johndgiese/matlab/blob/master/convertTDMS.m
        % cercare questo propsDataType==68 e si capisce il perchè di questa
        % conversione
        data = Tesmec_load_file_labview(file_path,opt);
        data.Tempo = (data.Tempo-695422+5/24)*86400;
        data.Tempo = labview_epoch + seconds(data.Tempo);
        data.Tempo_incrementale = [0:1/opt.fs:(length(data.Tempo)-1)*(1/opt.fs)];
        % Fai qualcosa con i dati importati, ad esempio:
        disp(['File importato: ' file_list(i).name]);
        disp(data); % Stampa i dati importati

        save
        
%         dati_processed{k}.Tempo_CAN = labview_epoch + seconds(dati_raw{k}.Tempo_CAN);
%         dati_processed{k}.ID_CAN = dec2hex(dati_raw{k}.ID_CAN);
%         for l=1:1:length(dati_processed{k}.Tempo_CAN)
%             if strfind(dati_processed{k}.ID_CAN,"FD08")~=[]
%                 dati_processed{k}.Viscosity(f) = bitor(bitshift(dati_raw{k}.Secondo_byte_CAN(l), 8), dati_raw{k}.Primo_byte_CAN(l));
%                 dati_processed{k}.Viscosity(f) = dati_processed{k}.Viscosity(f) * 0.015625; % datasheet conversion in cP
%                 dati_processed{k}.Density(f) = bitor(bitshift(dati_raw{k}.Quarto_byte_CAN(l), 8), dati_raw{k}.Terzo_byte_CAN(l));
%                 dati_processed{k}.Density(f) = dati_processed{k}.Density(f) * 0.00003052; % datasheet conversion in g/cm^3
%                 dati_processed{k}.Dielectric_constant(f) = bitor(bitshift(dati_raw{k}.Ottavo_byte_CAN(l), 8), dati_raw{k}.Settimo_byte_CAN(l));
%                 dati_processed{k}.Dielectric_constant(f) = dati_processed{k}.Dielectric_constant(f) * 0.00012207; % datasheet conversion
%                 f=f+1;
%             end
% 
%             if strfind(dati_processed{k}.ID_CAN,"FA67")~=[]
%                 dati_processed{k}.Rp(f) =  0;%da sistemare%%bitor(bitshift(dati_raw{k}.Secondo_byte_CAN(l), 8), dati_raw{k}.Primo_byte_CAN(l));
%                 dati_processed{k}.Rp(f) = dati_processed{k}.Rp(f) * 1000; % datasheet conversion in ohm
%             % da capire che indice mettere se f o un altro
%             end
% 
%              if strfind(dati_processed{k}.ID_CAN,"FEEE")~=[]
%                 dati_processed{k}.Temperature(f) = bitor(bitshift(dati_raw{k}.Quarto_byte_CAN(l), 8), dati_raw{k}.Terzo_byte_CAN(l));
%                 dati_processed{k}.Temperature(f) = (dati_processed{k}.Temperature(f) * 0.03125) - 273; % datasheet conversion in °C
%             % da capire che indice mettere se f o un altro
%              end
% 
%              if strfind(dati_processed{k}.ID_CAN,"FF31")~=[]
%                 dati_processed{k}.Diag(f) = bitor(bitshift(dati_raw{k}.Terzo_byte_CAN(l), 8), dati_raw{k}.Secondo_byte_CAN(l));
%                 % il primo bit non ho capito
%                 % da capire che indice mettere se f o un altro
%             end
%         end

%         k = k+1;
        % Esegui altre operazioni sui dati se necessario

       save(strcat(path_results,file_list(i).name(1:end-5),".mat"),'data');
        
    end
end
