function [ber_results, num_errors_results] = pluto_ofdm_rx()
    p = parametersOFDM();
    center_freq = 2.4e9; 
    SNR_dB = 0:5:20; 
    rx_gains = [0, 10, 20, 30, 40, 50]; 
    capture_length = p.wformLength * 10 + length(p.sync);

    if mod(capture_length, 2) == 1
        capture_length=capture_length+1;
    end

    rxPluto = comm.SDRRxPluto('RadioID', 'usb:0', ...
                              'CenterFrequency', center_freq, ...
                              'BasebandSampleRate', p.sample_rate, ...
                              'SamplesPerFrame', capture_length, ...
                              'OutputDataType', 'double');

    ber_results = zeros(size(SNR_dB));
    num_errors_results = zeros(size(SNR_dB));

    for k = 1:length(SNR_dB)
        rxPluto.Gain = rx_gains(k);  
        rx_data = rxPluto();  
        [ber, num_err] = ofdmRx(rx_data, tx_bits, p, p.sample_rate, cfo);
        ber_results(k) = ber;
        num_errors_results(k) = num_err;
    end

    figure;
    plot(SNR_dB, ber_results, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
    title('BER vs. SNR (Donanım)');
    xlabel('SNR (dB)');
    ylabel('Bit Error Rate');
    grid on;

    figure;
    subplot(2,1,1);
    plot(real(txWave), 'b');
    title('Gönderilen OFDM Sinyali (Reel Kısım)');
    xlabel('Örnek İndeksi');
    ylabel('Genlik');
    grid on;

    subplot(2,1,2);
    plot(real(rx_data), 'r');
    title('Alınan OFDM Sinyali (Reel Kısım)');
    xlabel('Örnek İndeksi');
    ylabel('Genlik');
    grid on;
    
    release(rxPluto);
end