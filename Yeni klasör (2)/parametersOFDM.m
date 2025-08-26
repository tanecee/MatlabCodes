function parameters = parametersOFDM()

parameters.Nfft=256; %alttaşıyıcı sayısı
parameters.Nsym=14; %Ofdm sembol sayısı yani zaman dilimini ayarlama
parameters.actScs=parameters.Nfft/2;
parameters.dataScs=parameters.actScs/2;
parameters.pilotScs=parameters.actScs/2;
parameters.dataInd= (1:2:2*parameters.dataScs)+ parameters.Nfft/4;
parameters.pilotInd = (2:2:2*parameters.pilotScs) + parameters.Nfft/4;

parameters.pilot1=repmat([1 ; -1],parameters.pilotScs/2,1);
parameters.pilot2=repmat([-1 ; 1],parameters.pilotScs/2,1);
parameters.sync=zadoffChuSeq(8,255);
parameters.cpLength=parameters.Nfft/4;
parameters.wformLength=(parameters.Nfft+parameters.cpLength)*parameters.Nsym;
parameters.M=4;
parameters.sample_rate=20e6;
end

