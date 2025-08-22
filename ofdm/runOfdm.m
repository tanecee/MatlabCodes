function [ber_results, num_errors_results] = runOfdm(p, sample_rate, rx_data)
p=parametersOFDM();

sample_rate=20e6;
cfo=3000;
SNR_dB=0:5:20;

ber_results = zeros(size(SNR_dB));
num_errors_results = zeros(size(SNR_dB));

for k = 1:length(SNR_dB)
[tx, tx_bits] = ofdmTx(p);
n = (0:length(tx)-1).';
rx_data = tx .* exp(1j*2*pi*cfo*n/sample_rate);
rx_data = awgn(rx_data, SNR_dB(k), 'measured');
fprintf('SNR = %2d dB, CFO = %d Hz ', SNR_dB(k), cfo);
[ber, num_err] = ofdmRx(rx_data, tx_bits, p, sample_rate, cfo);
fprintf('BER = %.4g, errors = %d\n', ber, num_err);
ber_results(k) = ber;
num_errors_results(k) = num_err;
end



figure;
plot(SNR_dB, ber_results, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
title('BER vs. SNR');
xlabel('SNR (dB)');
ylabel('Bit Error Rate');
grid on;
end