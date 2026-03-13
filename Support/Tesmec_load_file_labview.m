function loaded_data = Tesmec_load_file_labview(file_name,opt)
    
fprintf('---------------------------------------\n');
fprintf(' | Loading the %s file %s\n', file_name);
fprintf(' | -> Loading file ... \n');

% Load file
file_tdms = TDMS_readTDMSFile(file_name);
data = file_tdms.data(3:end); % first 2 columns are always empty
n = length(data{1});

fprintf('\bDone\n');
fprintf(' | -> Populating the output... \n');

% Add the new columns
for ii = 1 : 1 : length(opt.columns_name)
    loaded_data.(opt.columns_name{ii}) = data{ii};
end

fprintf('\bDone\n');
fprintf('---------------------------------------\n');

end

