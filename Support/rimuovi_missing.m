function T_pulita = rimuovi_missing(T,opts_can)
% RIMUOVI_MISSING Rimuove celle missing, "" e [] da ogni riga della tabella
%   T_pulita = rimuovi_missing(T)
%
%   Input:  T       - tabella MATLAB con celle missing/vuote
%   Output: T_pulita - tabella compattata senza valori mancanti

% Converti tutta la tabella in cell array
C = table2cell(T);

% Per ogni riga, rimuovi missing, "" e []
C_pulita = cell(size(C));

for i = 1:size(C, 1)
    riga = C(i, :);
    
    % Trova le celle valide (non missing, non "", non [])
    mask_valide = ~cellfun(@(x) ...
        isempty(x) || ...                          % elimina []
        (isstring(x) && x == "") || ...            % elimina ""
        (ischar(x) && strcmp(x, '')) || ...        % elimina '' char
        any(ismissing(string(x))), ...             % elimina <missing>
        riga);
    
    valori_validi = riga(mask_valide);
    
    % Metti i valori validi all'inizio della riga
    C_pulita(i, 1:length(valori_validi)) = valori_validi;
end

% Rimuovi le colonne completamente vuote alla fine
colonne_piene = any(~cellfun(@isempty, C_pulita), 1);
C_pulita = C_pulita(:, colonne_piene);

% Riconverti in tabella
T_pulita = array2table(C_pulita);
T_pulita = removevars(T_pulita, 1);              % per indice
T_pulita.Properties.VariableNames = opts_can.VariableNames;


end