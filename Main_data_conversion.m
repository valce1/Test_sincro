clear variables; close all; clc;

% add to path needed files
addpath(genpath('Support\'));

path_data = 'Data\';
known_file_type = '.tdms';

path_results = 'Results\';

% Ottieni tutti i nomi dei file nella directory
file_list = dir(path_data);

labview_epoch = datetime(1904, 1, 1);

opt.columns_name = {'Tempo','Sincro','Controllo_Y3','Pressione_monte','Pressione_valle','Pressione_BP4'};
opt.fs = 10000; %[Hz]

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


       save(strcat(path_results,file_list(i).name(1:end-5),".mat"),'data');
        
    end
end
