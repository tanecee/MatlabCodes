function [txWave, tx_bits, ofdmGrid, tx] = pluto_ofdm_tx()
p = parametersOFDM();
fc = 3.1e9;
Fs = p.sample_rate; 
txGain = -20; 
[txWave, tx_bits, ofdmGrid] = ofdmTx(p); 

data_symbols = ofdmGrid(p.dataInd, :);
data_symbols = data_symbols(:);
figure;
scatter(real(data_symbols), imag(data_symbols), 'b.');
title('Transmitted QPSK Constellation');
xlabel('Real Part');
ylabel('Imaginary Part');
grid on;
axis equal; 

N_fft = 2^14; 
freq_axis = (-N_fft/2:N_fft/2-1) * (Fs/N_fft); 
tx_spectrum = fftshift(fft(txWave, N_fft));
figure;
plot(freq_axis/1e6, 20*log10(abs(tx_spectrum)), 'b');
title('Transmitted OFDM Signal Spectrum');
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
grid on;
xlim([-Fs/2e6, Fs/2e6]); 

tx = comm.SDRTxPluto('RadioID', 'sn:1044734c9605000417001f00ddea4f2bb1', ...
                     'CenterFrequency', fc, ...
                     'BasebandSampleRate', Fs, ...
                     'Gain', txGain);
% tx.CenterFrequency = fc;
% tx.BasebandSampleRate = Fs;
% tx.Gain = txGain;

% txWave = 0.6 * txWave / max(abs(txWave));
% x = lowpass(txWave,Fs*p.actScs/p.Nfft/2,Fs);
% x = x./max(abs(x));
figure;
subplot(2,1,1);
plot(real(txWave), 'b');
title('Gönderilen OFDM Sinyali (Reel Kısım)');
xlabel('Örnek İndeksi');
ylabel('Genlik');
grid on;
transmitRepeat(tx,txWave);

end
