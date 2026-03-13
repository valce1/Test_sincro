
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
