%% OFDM RX Script (usb:0 Pluto)

%% Parametreler
fs   = 10e6;      % örnekleme hızı
fc   = 2.4e9;     % taşıyıcı frekans

%% Pluto RX kur
rx = sdrrx('Pluto', ...
    'RadioID','usb:0', ...   % RX Pluto ID
    'CenterFrequency', fc, ...
    'BasebandSampleRate', fs, ...
    'SamplesPerFrame', 4096, ...
    'OutputDataType','double');

%% Spektrum analizörü (RX)
specRX = dsp.SpectrumAnalyzer( ...
    'SampleRate', fs, ...
    'SpectrumType','Power density', ...
    'Title','RX OFDM Spectrum');

disp('OFDM RX başlatıldı...');

%% Sürekli RX alımı
while true
    r = rx();
    specRX(r);
end
