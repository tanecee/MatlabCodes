function parameters = parametersOFDM()

parameters.Nfft=256; %IFFT/FFT boyutu; subcarrier sayısı
parameters.Nsym=14; %Ofdm sembol sayısı yani zaman dilimini ayarlama
parameters.actScs=parameters.Nfft/2; %aktif alt taşıyıcı sayısı
%aktif 128 alt taşıyıcının yarısı veri yarısı pilot olacak şekilde ayrım
parameters.dataScs=parameters.actScs/2;
parameters.pilotScs=parameters.actScs/2;
%Bu indeksler 65–192 aralığına yayılır (256’lık FFT’de orta bant)
parameters.dataInd= (1:2:2*parameters.dataScs)+ parameters.Nfft/4;
parameters.pilotInd = (2:2:2*parameters.pilotScs) + parameters.Nfft/4;
%+1/−1 desenleri; sembol paritesine göre (tek/çift) pilot işaretleri değişerek faz tahmini ve kanal kestirimi için güçlü referans veriyor.
parameters.pilot1=repmat([1 ; -1],parameters.pilotScs/2,1);
parameters.pilot2=repmat([-1 ; 1],parameters.pilotScs/2,1);
parameters.sync=zadoffChuSeq(8,255); %255 uzunlukta Zadoff–Chu preamble (senkronizasyon için korelasyonda sivri bir pik üretir).
parameters.cpLength=parameters.Nfft/4; %her OFDM sembolüne eklenecek dairesel önek (CP) uzunluğu.
parameters.wformLength=(parameters.Nfft+parameters.cpLength)*parameters.Nsym; %toplam zaman domeni sample sayısı.
parameters.M=4; %4-QAM (QPSK)
parameters.sample_rate=20e6; %pluto ayarına uygun olarak sample hızı
end



