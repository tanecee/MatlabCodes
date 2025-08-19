%% ofdm_pluto_tx.m — BPSK OFDM Transmitter with Pluto (no helpers)
% Frame: [S1:ZC] [S2:full-band pilot] [S3..:data with comb pilots]
% Stop: type "release(tx)" in Command Window.

clear; clc;

%% -------- System Parameters --------
% OFDM
NFFT        = 128;
CPLen       = 32;
K           = 90;             % active tones (DC & edges nulled)
deltaF      = 30e3;           % 30 kHz spacing
Fs          = NFFT*deltaF;    % 3.84 MS/s
pilotSpacing = 9;             % comb pilot every 9 tones
Nzc         = 62;             % ZC occupied tones (31-DC-31)

% Mod/Frame
M              = 2;           % BPSK
numDataSym     = 300;         % data symbols per frame
pilotSeedBase  = 2025;        % pilots
payloadSeed    = 999;         % payload bits — RX uses same seed
txBackoff      = 0.8;         % PAPR headroom
minTxLen       = 48000;       % reduce underruns

% RF (Pluto)
fc     = 2.45e9;              % Hz (ISM band)
txGain = -10;                 % dB

% Optional scopes (if DSP System Toolbox present)
useScopes = license('test','Signal_Toolbox') || license('test','DSP_System_Toolbox');

%% -------- Subcarrier Maps --------
mid = NFFT/2 + 1;
negBins    = (mid - K/2) : (mid - 1);
posBins    = (mid + 1)   : (mid + K/2);
activeBins = [negBins, posBins];                     % K elements

zcNegBins = (mid - Nzc/2) : (mid - 1);
zcPosBins = (mid + 1)     : (mid + Nzc/2);
zcBins    = [zcNegBins, zcPosBins];

pilotPosWithinActive = 1:pilotSpacing:K;
dataMask = true(1,K); dataMask(pilotPosWithinActive) = false;
dataBins = activeBins(dataMask);
numDataCarriers = nnz(dataMask);

symLen = NFFT + CPLen;

%% -------- S1: ZC Sync --------
root_u = 25;                              % gcd(u,Nzc)=1
zcSeq  = localZC(root_u, Nzc).';
X_S1_shift = zeros(1,NFFT);
X_S1_shift(zcNegBins) = zcSeq(1:Nzc/2);
X_S1_shift(zcPosBins) = zcSeq(Nzc/2+1:end);
x_S1 = ifft(ifftshift(X_S1_shift), NFFT);
x_S1 = [x_S1(end-CPLen+1:end), x_S1];

%% -------- S2: Full-band BPSK pilot --------
rng(pilotSeedBase);
pilotFull = sign(randn(1,K));
X_S2_shift = zeros(1,NFFT); X_S2_shift(activeBins) = pilotFull;
x_S2 = ifft(ifftshift(X_S2_shift), NFFT);
x_S2 = [x_S2(end-CPLen+1:end), x_S2];

%% -------- S3..: Data (comb pilots) --------
rng(payloadSeed);
totalBits = numDataCarriers * numDataSym;
txBits    = randi([0 1], totalBits, 1);   % saved for BER reference (seeded)

txWave = zeros(1, symLen*numDataSym);
idx = 1;
for s = 1:numDataSym
    rng(pilotSeedBase + s);
    pilotsSym = sign(randn(1,numel(pilotPosWithinActive)));

    bitsThis  = txBits(idx:idx+numDataCarriers-1).';
    idx = idx + numDataCarriers;
    dataBPSK  = 1 - 2*bitsThis;           % 0->+1, 1->-1

    symVec = zeros(1,K);
    symVec(dataMask)       = dataBPSK;
    symVec(~dataMask)      = pilotsSym;

    X_shift = zeros(1,NFFT); X_shift(activeBins) = symVec;
    x = ifft(ifftshift(X_shift), NFFT);
    x = [x(end-CPLen+1:end), x];

    txWave((s-1)*symLen+1 : s*symLen) = x;
end

%% -------- Frame & Scaling --------
txFrame = [x_S1, x_S2, txWave];
txFrame = (txFrame / max(abs(txFrame))) * txBackoff;
if numel(txFrame) < minTxLen
    rep = ceil(minTxLen/numel(txFrame)); txFrame = repmat(txFrame,1,rep);
end
txFrame = txFrame(:);

%% -------- (Optional) Spectrum scope --------
if useScopes
    try
        SA = dsp.SpectrumAnalyzer('SampleRate',Fs,'SpectrumType','Power-density',...
            'Title','Transmitted Signal','ShowLegend',true);
        SA(txFrame); release(SA);
    catch, end
end

%% -------- Pluto TX --------
tx = sdrtx('Pluto','CenterFrequency',fc,'BasebandSampleRate',Fs,'Gain',txGain);
disp('Transmitting with transmitRepeat... (type "release(tx)" to stop)');
try, transmitRepeat(tx, txFrame); catch, while true, tx(txFrame); end, end

%% -------- Helper --------
function zc = localZC(u,Nzc)
    n = 0:Nzc-1; zc = exp(-1j*pi*u.*n.*(n+1)/Nzc).';
end
