classdef ObservationManager < handle
    properties
        NumObservations = 0

        Owner
        NumChannels  % k

        CurrentObservation %현재 RF Sensing 결과 o_{t+1} (1*k)

    end


    methods
        % ========== 생성자 ==========
        function obj = ObservationManager(owner, numChannels)
            obj.Owner = owner;
            obj.NumChannels = numChannels;

            obj.CurrentObservation = zeros(1, obj.NumChannels);
        end



        % ========== 전체 Service Channel 센싱 ==========
        function observation = observe(obj, ServiceChannels, Satellite)
        
            observation = zeros(1, obj.NumChannels);
        
            % 모든 Service Channel 센싱
            for channelIndex = 1:obj.NumChannels
                observation(channelIndex) = obj.measureChannelPower_dBm(ServiceChannels(channelIndex), Satellite);
            end

            % 현재 Observation 저장
            obj.CurrentObservation = observation;

        end
      
       


        % ========== 채널별 수신 전력 측정 ==========
        function totalPower_dBm = measureChannelPower_dBm(obj, channel, Satellite)
            totalPower_W = 0;

            centerFrequency_Hz = channel.CenterFrequency_Hz;
            packets = channel.getPackets();

            for packetIndex = 1:numel(packets)
                packet = packets(packetIndex);

                % DATA 패킷만 센싱
                if packet.Type ~= PacketType.DATA
                    continue;
                end

                beam = Satellite.Beams(packet.BeamId);

                % 자신의 Serving Beam 신호 제외
                if obj.Owner.Type == NodeType.UT
                    if beam.Id == obj.Owner.AssociatedBeamId
                        continue;
                    end
                end

                receivedPower_W = obj.calculateReceivedPower_W(beam, Satellite, centerFrequency_Hz);
                totalPower_W = totalPower_W + receivedPower_W;
            end
            
            noisePower_W = obj.calculateNoisePower_W(channel.Bandwidth_Hz);
            totalPower_W = totalPower_W + noisePower_W;

            totalPower_dBm = 10 * log10(totalPower_W) + 30;
        end



        % ========== Beam 신호의 수신 전력 계산 ==========
        function receivedPower_W = calculateReceivedPower_W(obj, beam, Satellite, centerFrequency_Hz)

            % 공통 값
            lambda = 3e8 / centerFrequency_Hz; % 파장
            distance = obj.Owner.distanceTo(Satellite); % Satellite -> 현재 UT 거리
            pathGain = (lambda / (4 * pi * distance))^2; % Free-Space Path Gain
            rxGain_linear = 10^(obj.Owner.RxGain_dBi / 10); % UT Rx Gain
        
            
            txPower_W = 10^((beam.TxPower_dBm - 30) / 10); % Beam Tx Power
            txGain_dBi = beam.calculateTxGain(Satellite, obj.Owner.Position, centerFrequency_Hz); % Owner 위치 방향의 Beam Tx Gain
            txGain_linear = 10^(txGain_dBi / 10);
        

            % Received Power
            receivedPower_W = txPower_W * txGain_linear * rxGain_linear * pathGain;
        
        end

        % ========== Noise Power 계산 ==========
        function noisePower_W = calculateNoisePower_W(obj, bandwidth_Hz)
            noiseFigure_linear = 10^(obj.Owner.NoiseFigure_dB / 10);
            noisePower_W = obj.Owner.k * obj.Owner.NoiseTemperature * bandwidth_Hz * noiseFigure_linear;
        end

        % ========== 현재 Observation 반환 ==========
        function observation = getCurrentObservation(obj)
            observation = obj.CurrentObservation;
        end





    end

end