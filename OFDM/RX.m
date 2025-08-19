%% ofdm_pluto_rx.m — BPSK OFDM Receiver with Pluto (SNR & BER, no helpers)
clear; clc;

%% -------- System Parameters (must match TX) --------
NFFT        = 128; CPLen = 32; K = 90; deltaF = 30e3; Fs = NFFT*deltaF;
pilotSpacing = 9; Nzc = 62; numDataSym = 300;
pilotSeedBase = 2025; payloadSeed = 999;          % must match TX

% RF
fc = 2.45e9; rxGain = 40;                          % tune 20..60 dB

% Capture
sampsPerFrame = 65536; searchBlocks = 10;
corrThreshFac = 0.5;

useScopes = license('test','Signal_Toolbox') || license('test','DSP_System_Toolbox');

%% -------- Subcarrier Maps --------
mid = NFFT/2 + 1;
negBins = (mid-K/2):(mid-1); posBins = (mid+1):(mid+K/2);
activeBins = [negBins, posBins]; symLen = NFFT + CPLen;

zcNegBins = (mid - Nzc/2):(mid-1); zcPosBins = (mid+1):(mid+Nzc/2);
pilotPosWithinActive = 1:pilotSpacing:K;
dataMask = true(1,K); dataMask(pilotPosWithinActive) = false;
dataBins = activeBins(dataMask); numDataCarriers = nnz(dataMask);

%% -------- Recreate S1 for correlation --------
root_u = 25; zcSeq = localZC(root_u,Nzc).';
X_S1_shift = zeros(1,NFFT);
X_S1_shift(zcNegBins) = zcSeq(1:Nzc/2);
X_S1_shift(zcPosBins) = zcSeq(Nzc/2+1:end);
refS1 = ifft(ifftshift(X_S1_shift), NFFT);
refS1 = [refS1(end-CPLen+1:end), refS1]; refS1 = refS1/max(abs(refS1));

%% -------- Pluto RX --------
rx = sdrrx('Pluto','CenterFrequency',fc,'BasebandSampleRate',Fs,...
    'SamplesPerFrame',sampsPerFrame,'OutputDataType','double');

disp('Receiving... searching for S1 peak');
buf = []; startIdx = [];
for b=1:searchBlocks
    y = rx(); buf = [buf; y]; %#ok<AGROW>
    c = abs(conv(buf, conj(flipud(refS1(:))), 'same'));
    [pks,locs] = findpeaks(c,'MinPeakHeight',corrThreshFac*max(c));
    if ~isempty(locs)
        startIdx = locs(1) - symLen + 1; if startIdx<1, startIdx=1; end; break;
    end
end
if isempty(startIdx), warning('S1 not detected. Increase rxGain/searchBlocks or lower corrThreshFac.'); return; end
fprintf('Frame start index ≈ %d\n', startIdx);

needSamples = (2 + numDataSym)*symLen + symLen;
while numel(buf)-startIdx+1 < needSamples, buf = [buf; rx()]; end

ptr = startIdx;

%% -------- Extract S1 (skip), S2 (pilot) --------
ptr = ptr + symLen;                    % skip S1
s2_td = buf(ptr:ptr+symLen-1); ptr = ptr + symLen;
S2_fd = fftshift(fft(s2_td(CPLen+1:end), NFFT));
S2_act = S2_fd(activeBins).';

% Known full-band pilot
rng(pilotSeedBase); pilotFull = sign(randn(1,K));

% Channel estimate
Hhat = S2_act ./ pilotFull;            % 1xK
e2   = S2_act - Hhat .* pilotFull;     % error
Ps2  = mean(abs(Hhat.*pilotFull).^2);
Pn2  = mean(abs(e2).^2);
snr_s2_dB = 10*log10(Ps2/max(Pn2,eps));
fprintf('SNR (from S2 pilot) ≈ %.2f dB\n', snr_s2_dB);

%% -------- Data symbols: equalize, SNR/BER --------
% Re-generate TX bits deterministically for BER reference
rng(payloadSeed);
refBits = randi([0 1], numDataCarriers*numDataSym, 1);

snr_hist = zeros(1,numDataSym);
rxBits   = zeros(numDataCarriers*numDataSym,1);
idx = 1;

eqDataAll = complex(zeros(numDataCarriers,numDataSym));

for s = 1:numDataSym
    sym_td  = buf(ptr:ptr+symLen-1); ptr = ptr + symLen;
    SYM_fd  = fftshift(fft(sym_td(CPLen+1:end), NFFT)).';
    Y_act   = SYM_fd(activeBins);              % 1xK

    % Comb pilots for this symbol
    rng(pilotSeedBase + s);
    pilotsSym = sign(randn(1,numel(pilotPosWithinActive)));

    % Update Hhat on pilot bins (simple tracking)
    Hhat(pilotPosWithinActive) = Y_act(pilotPosWithinActive) ./ pilotsSym;

    % Equalize all active bins
    Xhat_act = Y_act ./ (Hhat + eps);

    % --- Pilot-based SNR on this symbol
    Yp = Y_act(pilotPosWithinActive);
    Hp = Hhat(pilotPosWithinActive);
    Xp = pilotsSym;
    ep = Yp - Hp .* Xp;
    Psp = mean(abs(Hp.*Xp).^2);
    Pnp = mean(abs(ep).^2);
    snr_hist(s) = 10*log10(Psp/max(Pnp,eps));

    % Extract data carriers & BPSK decisions
    dataEq = Xhat_act(dataMask).';
    eqDataAll(:,s) = dataEq;
    bitsHat = real(dataEq) < 0;               % BPSK: +1->0, -1->1

    % Save for BER
    rxBits(idx:idx+numDataCarriers-1) = bitsHat;
    idx = idx + numDataCarriers;
end

% BER
bitErrs = sum(rxBits ~= refBits);
BER = bitErrs / numel(refBits);
fprintf('BER = %d / %d  =>  %.3e\n', bitErrs, numel(refBits), BER);

% Average SNR (pilot-based)
snr_mean_dB = mean(snr_hist);
fprintf('Avg SNR (pilot-based over data symbols) ≈ %.2f dB\n', snr_mean_dB);

%% -------- (Optional) Scopes --------
if useScopes
    try
        SA = dsp.SpectrumAnalyzer('SampleRate',Fs,'SpectrumType','Power-density',...
            'Title','Received Signal','ShowLegend',true);
        SA(buf(max(startIdx-2*symLen,1):startIdx + 10*symLen)); release(SA);
    catch, end
end

% Constellation
figure; plot(real(eqDataAll(:)), imag(eqDataAll(:)), '.'); grid on; axis equal;
title(sprintf('Equalized BPSK Constellation  |  BER=%.2e, SNR≈%.1f dB', BER, snr_mean_dB));
xlabel('In-Phase'); ylabel('Quadrature');

% SNR vs symbol index
figure; plot(1:numDataSym, snr_hist, '-'); grid on;
xlabel('OFDM Symbol #'); ylabel('SNR (dB)'); title('Pilot-based SNR per symbol');

disp('Done.');

%% -------- Helper --------
function zc = localZC(u,Nzc)
    n = 0:Nzc-1; zc = exp(-1j*pi*u.*n.*(n+1)/Nzc).';
end
