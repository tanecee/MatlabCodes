function [ber_results, num_errors_results] = pluto_ofdm_rx()
    p = parametersOFDM();
    center_freq = 2.4e9;  
    SNR_dB = 0:5:20; 
    rx_gains = [0, 10, 20, 30, 40, 50]; 
    capture_length = p.wformLength * 10 + length(p.sync)+1;


    rxPluto = comm.SDRRxPluto('RadioID', 'usb:0', ...
                              'CenterFrequency', center_freq, ...
                              'BasebandSampleRate', p.sample_rate, ...
                              'SamplesPerFrame', capture_length, ...
                              'OutputDataType', 'double');

    ber_results = zeros(size(SNR_dB));
    num_errors_results = zeros(size(SNR_dB));

    for k = 1:length(SNR_dB)
        [~, tx_bits] = ofdmTx(p);  
        rxPluto.Gain = rx_gains(k);  
        rx_data = rxPluto();  
        fprintf('SNR = %2d dB, RX Gain = %2d dB ', SNR_dB(k), rx_gains(k));
        [ber, num_err] = ofdmRx(rx_data, tx_bits, p, p.sample_rate, cfo);
        fprintf('BER = %.4g, errors = %d\n', ber, num_err);
        ber_results(k) = ber;
        num_errors_results(k) = num_err;
    end

    figure;
    plot(SNR_dB, ber_results, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
    title('BER vs. SNR (Donanım)');
    xlabel('SNR (dB)');
    ylabel('Bit Error Rate');
    grid on;

    release(rxPluto);
end