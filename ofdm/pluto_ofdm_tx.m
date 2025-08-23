function pluto_ofdm_tx()
fc = 2.4e9;
p = parametersOFDM();
Fs = p.sample_rate; 
txGain = -10; 
p = parametersOFDM();
[txWave, ~, ~] = ofdmTx(p); 

TX = comm.SDRTxPluto('RadioID', 'usb:1', ...
                         'CenterFrequency', fc, ...
                         'BasebandSampleRate', Fs, ...
                         'Gain', txGain);
TX.CenterFrequency = fc;
TX.BasebandSampleRate = Fs;
TX.Gain = txGain;

txWave = 0.6 * txWave / max(abs(txWave)));
transmitRepeat(TX, txWave);
end