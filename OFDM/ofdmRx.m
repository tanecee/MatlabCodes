function [ber, num_errors, rx_bits, rx_data_symbols] = ofdmRx(rx_data, tx_bits)
p = parametersOFDM;

%xcorr ile ZC preamble’ı aranır ve 
%En güçlü pik bulunduğunda, onun bittiği noktadan başlayarak OFDM dalgası kesilir.
[corr, lag] = xcorr(rx_data, p.sync);
[~, max_idx] = max(abs(corr));
start_idx = lag(max_idx) + length(p.sync) + 1;

if start_idx < 1 || start_idx + p.wformLength - 1 > length(rx_data)
    warning('Senkronizasyon indeksi geçersiz.');
    start_idx = 1; % Başlangıçtan itibaren al
    rx_data = rx_data(1:p.wformLength); 
else
    rx_data = rx_data(start_idx:start_idx + p.wformLength - 1);
end

%CP ile sembolün başı ve sonu aynı olduğundan, aradaki faz farkı CFO’ya karşılık gelir.
%Formül: Δf ≈ angle / (2π) * Fs / Nfft kodda: mean(phase_offsets)/(2π*Nfft)*Fs
%median(...): tekil sıçramalara dayanıklı faz tahmini.
%Bulunan Δf (Hz) ile tüm alıcı dalgaya CFO düzeltmesi uygulanır.

phase_offsets = zeros(p.Nsym, 1);
for i = 1:p.Nsym
    start_idx = (i-1)*(p.Nfft + p.cpLength) + 1;
    cp_samples = rx_data(start_idx:start_idx+p.cpLength-1);
    end_samples = rx_data(start_idx+p.Nfft:start_idx+p.Nfft+p.cpLength-1);
    phase_diff = median(angle(cp_samples .* conj(end_samples)));
    phase_offsets(i) = phase_diff;
end
residual_cfo = mean(phase_offsets) / (2 * pi * p.Nfft) * p.sample_rate;
t = (0:length(rx_data)-1).'./ p.sample_rate;
rx_data = rx_data .* exp(-1j * 2 * pi * residual_cfo * t);

%Burada normalize ve FFT'ye geçilir.
%CP atılıp fft ile frekansa dönülür ve fftshift ile tekrar merkez-DC dizilişe geçilir. 
rx_data = rx_data / max(abs(rx_data));

rx_grid = zeros(p.Nfft, p.Nsym);
for i = 1:p.Nsym
    start_idx = (i-1)*(p.Nfft + p.cpLength) + p.cpLength + 1;
    symbol_data = rx_data(start_idx:start_idx+p.Nfft-1);
    fft_output = fftshift(fft(symbol_data) / sqrt(p.Nfft));
    rx_grid(:, i) = fft_output;
end

%Her sembolde pilot konumlarındaki alma/pilot oranından kanal cevabı (H) kestirilir.
%Veri konumlarına lineer interpolasyon ile H yayılır (alt taşıyıcı ekseninde).
channel_grid = zeros(p.Nfft, p.Nsym);
for i = 1:p.Nsym
    pilot_sequence = p.pilot1;
    if mod(i, 2) == 0
        pilot_sequence = p.pilot2;
    end
    rx_pilots = rx_grid(p.pilotInd, i);
    channel_est = rx_pilots ./ pilot_sequence;
    all_indices = min(p.dataInd):max(p.dataInd);
    channel_grid(all_indices, i) = interp1(p.pilotInd, channel_est, all_indices, 'linear', 'extrap');
end

rx_data_symbols = zeros(p.dataScs, p.Nsym);
for i = 1:p.Nsym
    rx_data_symbols(:, i) = rx_grid(p.dataInd, i);
    rx_data_symbols(:, i) = rx_data_symbols(:, i) ./ channel_grid(p.dataInd, i);
end

rx_data_symbols = rx_data_symbols(:); 
rx_bits = qamdemod(rx_data_symbols, p.M, 'OutputType', 'bit', 'UnitAveragePower', true);
%qamdemod ile bitlere dön, BER ve hata sayısı hesapla.
num_errors = sum(rx_bits ~= tx_bits);
ber = num_errors / length(tx_bits);

figure(10);
scatter(real(rx_data_symbols), imag(rx_data_symbols), 'b.');
title('Received Constellation');
xlabel('Real Part');
ylabel('Imaginary Part');
grid on;

figure(15);
plot(20*log10(abs(fftshift(fft(rx_data, p.sample_rate)))), 'b');
title('Received Signal Spectrum');
xlabel('Frequency Bin');
ylabel('Magnitude (dB)');
grid on;

end

