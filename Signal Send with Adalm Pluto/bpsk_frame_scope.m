
%% Ortak Parametreler
M        = 2;                  % BPSK
Fs       = 1e6;                % örnekleme hızı
Rsym     = 250e3;              % sembol hızı
sps      = round(Fs/Rsym);     % örnek/sembol
rolloff  = 0.35;
fltSpan  = 10;
Nsym     = 256;                % veri sembol sayısı
Nzc      = 63; 
rootIdx  = 25;
zc       = zadoffChuSeq(rootIdx, Nzc);   % preamble
frameLen = Nzc + Nsym;          % sembol cinsinden blok uzunluğu
numRepeats = 200;               % TX'te tekrarlama sayısı

%% RRC filtre
rrc      = rcosdesign(rolloff, fltSpan, sps, 'sqrt');

%% ---------------- TX Bölümü ----------------
% Rasgele veri
bits     = randi([0 1], Nsym*log2(M), 1);
dataSym  = pskmod(bits, M, pi/M, 'gray');

% Tek frame
frameBlock = [zc; dataSym];

% Tekrar et
txSym    = repmat(frameBlock, numRepeats, 1);

% RRC filtreleme
txWave   = upfirdn(txSym, rrc, sps, 1);
txWave   = txWave / max(abs(txWave)) * 0.6;

% Pluto TX
tx = sdrtx('Pluto');
tx.CenterFrequency      = 2.4e9;
tx.BasebandSampleRate   = Fs;
tx.Gain                 = -10;
disp('TX başlatılıyor...');
transmitRepeat(tx, txWave);

pause(1); % TX stabil olana kadar bekle

%% ---------------- RX Bölümü ----------------
rx = sdrrx('Pluto');
rx.CenterFrequency    = 2.4e9;
rx.BasebandSampleRate = Fs;
rx.SamplesPerFrame    = 4096;
rx.OutputDataType     = 'double';
rx.GainSource         = 'Manual';
rx.Gain               = 30;

% Capture
numFrames = 1; % uzun tutuyoruz
y = [];
disp('RX veri alınıyor...');
for k = 1:numFrames
    y = [y; rx()]; %#ok<AGROW>
end

%% RX filtreleme ve downsample
rxFilt = upfirdn(y, rrc, 1, sps); % TX ile uyumlu downsample
rxFilt = rxFilt / max(abs(rxFilt)); % normalize

%% Korelasyon
corrVals = abs(conv(rxFilt, flipud(conj(zc))));

% Korelasyon eşik değeri
threshold = 0.7 * max(corrVals);  % 0.7 çarpanı ile yüksek peak seç

% İlk frame peak'ini bul
peakIdxs = find(corrVals > threshold);
frameStart = peakIdxs(1);  % ilk eşik aşan peak

% RRC filtre gecikmesini düzelt
filterDelay = fltSpan * sps / 2;
frameStart = frameStart - length(zc) - filterDelay + 1;
if frameStart < 1
    frameStart = 1;
end

% Frame çıkarma
frameEnd = frameStart + frameLen - 1;
if frameEnd > length(rxFilt)
    frameEnd = length(rxFilt);
end
rxFrame = rxFilt(frameStart:frameEnd);

% Veri kısmı
rxData = rxFrame(length(zc)+1:end);
%% --- Frame başlangıcını grafikte işaretle ---
figure; 
plot(corrVals,'LineWidth',1); grid on; hold on;
xlabel('Örnek (sembol-hızı alanı)'); ylabel('Korelasyon genliği');
title('Zadoff–Chu Korelasyon (Frame İşaretli)');

yl = ylim;

% 1) Korelasyon alanındaki "ham" peak (eşik aşan ilk tepe)
peakAtCorr = peakIdxs(1);
plot(peakAtCorr, corrVals(peakAtCorr), 'ro', 'MarkerSize',6, 'LineWidth',1.2);
text(peakAtCorr, yl(2)*0.92, ' İlk Büyük Peak', 'Color','r', 'FontWeight','bold', ...
    'HorizontalAlignment','center');

% 2) Filtre gecikmesi düzeltildikten sonra hesaplanan frame başlangıcı
xline(frameStart, 'g-', 'LineWidth',1.2);
text(frameStart, yl(2)*0.80, ' Frame Start', 'Color','g', 'FontWeight','bold', ...
    'HorizontalAlignment','left');

% 3) Preamble (ZC) aralığını göster
xline(frameStart + Nzc - 1, 'g--', 'LineWidth',1);
patch([frameStart frameStart+Nzc-1 frameStart+Nzc-1 frameStart], ...
      [yl(1) yl(1) yl(2) yl(2)], ...
      [0.8 1.0 0.8], 'FaceAlpha',0.15, 'EdgeColor','none');
text(frameStart + Nzc/2, yl(2)*0.68, ' ZC (preamble)', 'Color',[0 0.5 0], ...
    'HorizontalAlignment','center');

% 4) Sonraki frame başlangıçlarını (görüş alanındaysa) çiz
starts = frameStart : frameLen : length(rxFilt);
for s = starts(2:end) % ilki zaten çizildi
    xline(s, 'b-.', 'LineWidth',1);
end
if numel(starts) > 1
    text(starts(min(2,end)), yl(2)*0.56, ' Sonraki frame başlangıçları', ...
        'Color','b', 'HorizontalAlignment','left');
end

legend({'Korelasyon','İlk Peak','Frame Start','ZC Bitişi'}, 'Location','best');
hold off;

%% CFO ve Faz Düzeltme
% Preamble bölgesi (sembol hızında)
rxZC = rxFilt(frameStart : frameStart + Nzc - 1);

% Faz hatası hesapla
phi = angle(rxZC .* conj(zc));
phi = unwrap(phi);
k = (0:Nzc-1).';

% Doğruya uydur
p = polyfit(k, phi, 1);
slope     = p(1);
intercept = p(2);

% CFO bilgisi (isteğe bağlı)
Fs_sym = Fs / sps;
f_cfo  = slope * Fs_sym / (2*pi);

% Tüm sinyali düzelt
n = (0:length(rxFilt)-1).';
rot = exp(-1j*(slope*n + intercept));
rxFiltCorr = rxFilt .* rot;

% Frame'i düzeltilmiş sinyalden çıkar
rxFrameCorr = rxFiltCorr(frameStart : frameStart + frameLen - 1);
rxDataCorr  = rxFrameCorr(length(zc)+1:end);

%% Scatterplot (CFO/Faz düzeltilmiş)
scatterplot(rxDataCorr);
title('CFO/Faz Düzeltilmiş BPSK Scatterplot');


%% Görselleştirme
figure;
plot(corrVals);
xlabel('Örnek');
ylabel('Korelasyon genliği');
title('Zadoff-Chu Korelasyon Grafiği');
grid on;

scatterplot(rxData);
title('Senkronize Edilmiş BPSK Scatterplot');





%% Temizlik
release(tx);
release(rx);
