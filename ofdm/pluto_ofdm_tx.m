function pluto_ofdm_tx()
fc = 2.4e9;
Fs = 1e6; 
txGain = -10; 
p = parametersOFDM();
[txWave, ~, ~] = ofdmTx(p); 

TX = comm.SDRTxPluto('RadioID', 'usb:1', ...
                         'CenterFrequency', fc, ...
                         'BasebandSampleRate', p.sample_rate, ...
                         'Gain', txGain);
TX.CenterFrequency = fc;
TX.BasebandSampleRate = Fs;
TX.Gain = txGain;

txWave = 0.6 * txWave ./ max(1, max(abs(txWave)));
transmitRepeat(TX, txWave);
tx=TX;
end