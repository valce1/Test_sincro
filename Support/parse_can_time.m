
function [t_sec, t_start] = parse_can_time(time_col)
% PARSE_CAN_TIME  Converte la colonna timestamp CAN in secondi (vettore double).
%
% Gestisce due formati:
%   Numerico   "1234.5678"   → trattato come ms se mediana > 1000, altrimenti s
%   HH:MM:SS   "00:01:23.456" → converte in secondi
%
% Output:
%   t_sec   : vettore tempi relativo all'inizio del file (t(1) = 0) [s]
%   t_start : timestamp assoluto del primo messaggio [s] (offset sottratto)
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

    % Rende il vettore relativo all'inizio del file; conserva l'offset assoluto
    t_start = t_sec(1);
    t_sec   = t_sec - t_start;
end

