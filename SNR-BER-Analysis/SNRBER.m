clc;
clear all;
close all;

N = 1e6;
SNR = 0:30;
modTypes = {'BPSK', 'QPSK', '8PSK', '16QAM'};
Modulation_values = [2, 4, 8, 16];
BER = zeros(length(modTypes), length(SNR));

bits = randi([0 1], N, 1); %rastgele bit üretir

for m = 1:length(Modulation_values)
    M = Modulation_values(m);
    k = log2(M); %M değerinin bit sayısı belirlenir
    
    %Eğer toplam M sayısı k'nın tam katı değilse eksik kalan bitleri
    %rastgele tamamlar. reshape işlemi için gereklidir.
    extraBits = mod(length(bits), k);
    if extraBits ~= 0
        bits_padded = [bits; randi([0 1], k-extraBits, 1)];
    else
        bits_padded = bits;
    end
    
    dataSymbols = bi2de(reshape(bits_padded, k, []).', 'left-msb');
    
    for snrIdx = 1:length(SNR)
        snr = SNR(snrIdx);
        
        % Modülasyon
        if M <= 8 && M ~= 4
            % BPSK ve 8PSK için
            txSig = pskmod(dataSymbols, M, 0, 'gray');
            rxSig = awgn(txSig, snr, 'measured');
            rxSymbols = pskdemod(rxSig, M, 0, 'gray');
        elseif M == 4
            % QPSK
            txSig = pskmod(dataSymbols, M, pi/4, 'gray');
            rxSig = awgn(txSig, snr, 'measured');
            rxSymbols = pskdemod(rxSig, M, pi/4, 'gray');
        else
            % 16-QAM
            txSig = qammod(dataSymbols, M, 'gray', 'UnitAveragePower', true);
            rxSig = awgn(txSig, snr, 'measured');
            rxSymbols = qamdemod(rxSig, M, 'gray', 'UnitAveragePower', true);
        end
        
        rxBits = de2bi(rxSymbols, k, 'left-msb').';
        rxBits = rxBits(:);
        rxBits = rxBits(1:length(bits)); % eklenen bitleri at
        
        BER(m, snrIdx) = sum(bits ~= rxBits) / length(bits);
    end
end

figure;
for m = 1:length(modTypes)
    semilogy(SNR, BER(m,:), '-o', 'LineWidth', 1.5); hold on;
end
grid on;
xlabel('SNR (dB)');
ylabel('Bit Error Rate (BER)');
title('BER vs SNR for Different Modulation Schemes');
legend(modTypes, 'Location', 'southwest');
