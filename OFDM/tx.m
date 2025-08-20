%% OFDM TX Script (usb:1 Pluto)

%% Parametreler
fs   = 10e6;      % örnekleme hızı
fc   = 2.4e9;     % taşıyıcı frekans
Nfft = 128;       % FFT boyutu
Ncp  = 16;        % CP uzunluğu
Nsym = 20;        % OFDM sembol sayısı
M    = 2;         % BPSK (2-PSK)

%% --- OFDM TX Sinyali ---
bits    = randi([0 1], Nfft*Nsym, 1);           % rastgele bitler
symbols = pskmod(bits, M, 0, 'gray');           % BPSK modülasyon

ofdm_time = [];
for k = 1:Nsym
    % 64 bitlik sembolleri seç
    sc = symbols((k-1)*64+1 : k*64);

    % Frekans domain vektörü (Nfft boyutlu, sıfırlar ile)
    X = zeros(Nfft,1);

    % Negatif ve pozitif subcarrier indeksleri
    negBins = (-32:-1);   % -32 .. -1
    posBins = (1:32);     % +1 .. +32
    mid = Nfft/2 + 1;     % DC taşıyıcının olduğu merkez

    % 64 taşıyıcıyı simetrik yerleştir
    X(mid+negBins) = sc(1:numel(negBins));          % negatif taraf
    X(mid+posBins) = sc(numel(negBins)+1:end);      % pozitif taraf

    % Zaman domeni sinyali (OFDM sembolü)
    x = ifft(ifftshift(X));

    % Cyclic Prefix ekle
    x_cp = [x(end-Ncp+1:end); x];

    % Bütün sembolleri ardışık birleştir
    ofdm_time = [ofdm_time; x_cp];
end


tx_waveform = 0.6 * ofdm_time / max(abs(ofdm_time));

%% Pluto TX başlat


tx = sdrtx('Pluto', ...
    'RadioID','usb:1', ...   % TX Pluto ID
    'CenterFrequency', fc, ...
    'BasebandSampleRate', fs, ...
    'Gain', 0);

tx.transmitRepeat(tx_waveform);

%% Spektrum gösterimi
specTX = dsp.SpectrumAnalyzer( ...
    'SampleRate', fs, ...
    'SpectrumType','Power density', ...
    'Title','TX OFDM Spectrum');

specTX(tx_waveform);
disp('OFDM TX başlatıldı...');

cleanupObj = onCleanup(@() release(tx));  % Ctrl-C/stop'ta serbest bırak
transmitRepeat(tx, tx_waveform);
disp('TX RUNNING... Press Ctrl-C to stop');
pause(inf);   % scripti canlı tut
