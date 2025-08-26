function [tx, tx_bits, ofdmGrid] = ofdmTx(p)
p=parametersOFDM;

num_data_symbols = p.Nsym*p.dataScs; %Toplam veri sembölü
bitStream_Length = num_data_symbols * log2(p.M); %Üretilen bit sayısı
tx_bits = randi([0 1], bitStream_Length, 1); 
%bit dizisi QAM sembollerine çevrilir ve ortalama sembol gücü 1'e ölçeklenir.
qam_symbols = qammod(tx_bits, p.M, 'InputType', 'bit', 'UnitAveragePower', true); 
ofdmGrid = zeros(p.Nfft, p.Nsym);

for i = 1:p.Nsym %Her sütun bir OFDM sembolünün örnekelrini temsil eder.
    if mod(i, 2)
        ofdmGrid(p.pilotInd, i) = p.pilot1;
    else
        ofdmGrid(p.pilotInd, i) = p.pilot2;
    end
    ofdmGrid(p.dataInd, i) = qam_symbols((i-1)*p.dataScs+1:i*p.dataScs); %Veri sembollerini dataInd konumlarına yerleştirilir
end

tx = zeros(p.wformLength, 1);
sample_counter = 1;

for i = 1:p.Nsym
    ifft_output = ifft(fftshift(ofdmGrid(:, i)), p.Nfft) * sqrt(p.Nfft);
    cp_samples = ifft_output(end-p.cpLength+1:end);
    ofdm_symbol = [cp_samples; ifft_output];
    tx(sample_counter:sample_counter+length(ofdm_symbol)-1) = ofdm_symbol;
    sample_counter = sample_counter + length(ofdm_symbol);
end

tx = tx / max(abs(tx));
tx = [p.sync; tx];
%fftshift + ifft: grid’i merkez-DC’den IFFT’nin beklediği sıralamaya uygun şekilde kaydırıp zaman domenine geçilir.
%*sqrt(Nfft): enerji ölçekleme (IFFT’nin 1/√N normuna göre sabitleme).
%CP: sembol sonundaki cpLength örneği başa kopyalanır.
%Dalga formunu normalize edip başına sync (ZC) preamble eklenir.
end



