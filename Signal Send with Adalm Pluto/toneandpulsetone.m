%% Pluto Tone & Pulsed Tone Transmission
clear; clc; close all;

%% Pluto TX/RX ayarları
tx = sdrtx('Pluto');
tx.CenterFrequency      = 2.4e9;     % taşıyıcı (Hz)
tx.BasebandSampleRate   = 1e6;       % Fs
tx.Gain                 = -50;       % dB

rx = sdrrx('Pluto');
rx.CenterFrequency      = tx.CenterFrequency;
rx.BasebandSampleRate   = tx.BasebandSampleRate;
rx.SamplesPerFrame      = 4096;
rx.OutputDataType       = 'double';

Fs   = tx.BasebandSampleRate; % baseband örnekleme hızı
f0   = 100e3;                 % ton frekansı (baseband, Hz)
N    = 2^14;                  % buffer uzunluğu

%% --- 1) Sürekli Tone ---
n    = (0:N-1).';
tone = 0.6 * exp(1j*2*pi*f0*n/Fs); % kompleks ton

disp('Sürekli ton gönderiliyor...');
transmitRepeat(tx, tone);

% Spektrum gözlemleme
sa = spectrumAnalyzer('SampleRate', Fs, ...
    'PlotAsTwoSidedSpectrum', true, ...
    'Title','RX Spectrum (Tone)');
for k=1:200
    y = rx();
    sa(y);
end
release(sa);
release(tx);

%% --- 2) Pulsed Tone ---
pulseLen = 100;    % darbe uzunluğu (örnek)
guardLen = 100;    % boşluk uzunluğu (örnek)
onePulse = repelem(complex(0.6,0.6),pulseLen,1);% * exp(1j*2*pi*f0*(0:pulseLen-1).'/Fs);

% Hann penceresi ile yumuşatma
% w = hann(pulseLen);
% onePulse = onePulse .* w;

silence = zeros(guardLen,1);
frame   = [onePulse; silence];

disp('Pulsed tone gönderiliyor...');
tx = sdrtx('Pluto');
tx.CenterFrequency      = 2.4e9;
tx.BasebandSampleRate   = 1e6;
tx.Gain                 = -30;

transmitRepeat(tx, repmat(frame, 500, 1));

sa = spectrumAnalyzer('SampleRate', Fs, ...
    'PlotAsTwoSidedSpectrum', true, ...
    'Title','RX Spectrum (Pulsed Tone)');
for k=1:200
    y = rx();
    sa(y);
end
release(sa);
release(tx);
release(rx);
