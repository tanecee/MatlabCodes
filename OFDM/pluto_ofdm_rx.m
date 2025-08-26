function [ber_results, num_errors_results, rx_data] = pluto_ofdm_rx(tx_bits)
p = parametersOFDM();
center_freq = 3.1e9;
SNR_dB = 0:5:25; 
rx_gains = [10,50]; 
capture_length = 2^14; %(p.wformLength + length(p.sync)) *10;

if mod(capture_length, 2) == 1
    capture_length = capture_length + 1;
end

rxPluto = comm.SDRRxPluto('RadioID', 'sn:1044734c9605001104000100d5934f698c', ...
                          'CenterFrequency', center_freq, ...
                          'BasebandSampleRate', p.sample_rate, ...
                          'SamplesPerFrame', capture_length, ...
                          'OutputDataType', 'double', ...
                          'GainSource','Manual');

% [txWave, tx_bits] = ofdmTx(p);

ber_results = zeros(size(SNR_dB));
num_errors_results = zeros(size(SNR_dB));

for k = 1:length(rx_gains)
    rxPluto.Gain = rx_gains(k);
    rx_data = rxPluto();
    
    % t = (0:length(rx_data)-1).'/p.sample_rate;
    % [corr, lag] = xcorr(rx_data, p.sync);
    % [~, max_idx] = max(abs(corr));
    % max_idx = max_idx +lag(1);
    % if abs(corr(max_idx)) < 0.1 * max(abs(corr)) % Korelasyon piki zayıfsa uyarı
    %     fprintf('Uyarı: Zayıf senkronizasyon korelasyonu, CFO tahmini başarısız olabilir.\n');
    % end
    % sona doğru peak eleme kodu eklenecek
    % cfo_est = -angle(corr(max_idx)) / (2 * pi * length(p.sync) / p.sample_rate);

    [ber, num_errors, rx_bits, rx_data_symbols] = ofdmRx(rx_data, tx_bits);
    fprintf('SNR = %2d dB, Gain = %d dB, BER = %.4g, errors = %d\n', SNR_dB(k), rx_gains(k), ber, num_errors);
    ber_results(k) = ber;
    num_errors_results(k) = num_errors;
end

% figure;
% plot(SNR_dB, ber_results, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
% title('BER vs. SNR (Donanım)');
% xlabel('SNR (dB)');
% ylabel('Bit Error Rate');
% grid on;
% 
% 
% subplot(1,1,2);
% plot(real(rx_data), 'r');
% title('Alınan OFDM Sinyali (Reel Kısım)');
% xlabel('Örnek İndeksi');
% ylabel('Genlik');
% grid on;

release(rxPluto);
end