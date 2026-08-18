classdef UT < Node
    properties
        IsTarget = false

        TxPower_dBm
        NoiseTemperature
        NoiseFigure_dB

        AssociatedBeamId
        SINRThreshold_dB

    end

    methods
        %% ========== 생성자 ========== %
        function obj = UT(id, position)
            env;

            obj@Node(id, NodeType.UT, position);

            obj.IsTarget = targetUTId==id;
    
            obj.RxGain_dBi = utRxGain_dBi;
            
            obj.TxPower_dBm = utTxPower_dBm;
            obj.NoiseTemperature = noiseTemperature;
            obj.NoiseFigure_dB = noiseFigure_dB;

            

            obj.AssociatedBeamId = id;
            obj.SINRThreshold_dB = sinrThreshold_dB;
            

        end

        %% ========== Service 채널에서 자신에게 오는 DATA 패킷 찾기 ==========
        function desiredPacket = findDesiredPacket(obj, ServiceChannels)        

            desiredPacket = Packet.empty;
        
            for channelIndex = 1:numel(ServiceChannels)
                packets = ServiceChannels(channelIndex).getPackets();
        
                for packetIndex = 1:numel(packets)
                    packet = packets(packetIndex);

                    if packet.Type == PacketType.DATA && packet.DestinationType == NodeType.UT && packet.DestinationId == obj.Id && packet.BeamId == obj.AssociatedBeamId
                        desiredPacket = packet;
                        return;
                    end
                end
            end
        end


        %% ========== HRAQ 수행 ==========
        function [packetType, SINR_dB] = performHARQ(obj, ServiceChannels, ControlChannels, Satellite)
            desiredPacket = obj.findDesiredPacket(ServiceChannels);
            
            % 오류 대비용
            if isempty(desiredPacket)
                packetType = [];
                SINR_dB = [];
                return;
            end

            selectedChannel = desiredPacket.ChannelId;
            packets = ServiceChannels(selectedChannel).getPackets();

            interferencePackets = packets;
            interferencePackets([packets.BeamId] == desiredPacket.BeamId) = [];

            centerFrequency_Hz = ServiceChannels(selectedChannel).CenterFrequency_Hz;
            bandwidth_Hz = ServiceChannels(selectedChannel).Bandwidth_Hz;

            SINR_dB = obj.calculateSINR(desiredPacket, interferencePackets, Satellite, centerFrequency_Hz, bandwidth_Hz);

            packetType = obj.generateHARQFeedback(SINR_dB);
            harqPacket = Packet(packetType, NodeType.UT, obj.Id, NodeType.Satellite, Satellite.Id, obj.AssociatedBeamId, ChannelType.Control, selectedChannel);

            ControlChannels(selectedChannel).addPacket(harqPacket);
        end



        %% ========== HARQ Feedback 결정 ==========
        function packetType = generateHARQFeedback(obj, SINR_dB)
            if SINR_dB >= obj.SINRThreshold_dB
                packetType = PacketType.ACK;
            else
                packetType = PacketType.NACK;
            end
        end


        %% ========== Downlink SINR 계산 ==========
        function SINR_dB = calculateSINR(obj, desiredPacket, interferencePackets, Satellite, centerFrequency_Hz, bandwidth_Hz)

            % 공통 값
            lambda = 3e8 / centerFrequency_Hz; % 파장
            distance = obj.distanceTo(Satellite); % Satellite -> 현재 UT 거리
            pathGain = (lambda / (4 * pi * distance))^2; % Free-Space Path Gain
            rxGain_linear = 10^(obj.RxGain_dBi / 10); % UT Rx Gain


            % 원하는 신호 전력 계산
            desiredBeamId = desiredPacket.BeamId;
            desiredBeam = Satellite.Beams(desiredBeamId);
            desiredTxPower_dBm = desiredBeam.TxPower_dBm;
            desiredTxPower_W = 10^((desiredTxPower_dBm - 30) / 10);

            % desiredTxGain_dBi = desiredBeam.MaxTxGain_dBi;
            desiredTxGain_dBi = desiredBeam.calculateTxGain(Satellite, obj.Position, centerFrequency_Hz);
            desiredTxGain_linear = 10^(desiredTxGain_dBi / 10);
            desiredPower_W = desiredTxPower_W * desiredTxGain_linear * rxGain_linear * pathGain;



            % 간섭 전력 합산
            interferencePower_W = 0;
            interferenceGain_dBi = zeros(1, numel(interferencePackets));
            interferencePowerEach_W = zeros(1, numel(interferencePackets));

            for interferenceIndex = 1:numel(interferencePackets)
                interferencePacket = interferencePackets(interferenceIndex);
                interferingBeamId = interferencePacket.BeamId;
                interferingBeam =  Satellite.Beams(interferingBeamId);
                interferenceTxPower_dBm = interferingBeam.TxPower_dBm;
                interferenceTxPower_W = 10^((interferenceTxPower_dBm - 30) / 10);

                % interferenceTxGain_dBi = interferingBeam.MaxTxGain_dBi;
                interferenceTxGain_dBi = interferingBeam.calculateTxGain(Satellite, obj.Position, centerFrequency_Hz);
                interferenceTxGain_linear = 10^(interferenceTxGain_dBi / 10);
                interferenceReceivedPower_W = interferenceTxPower_W * interferenceTxGain_linear * rxGain_linear * pathGain;
                
                % 디버그용 저장
                interferenceGain_dBi(interferenceIndex) = interferenceTxGain_dBi;
                interferencePowerEach_W(interferenceIndex) = interferenceReceivedPower_W;
                
                interferencePower_W = interferencePower_W + interferenceReceivedPower_W;   % 딱 한 번만
            end


            % 잡음 전력
            noiseFigure_linear = 10^(obj.NoiseFigure_dB / 10);
            noisePower_W = obj.k * obj.NoiseTemperature * bandwidth_Hz * noiseFigure_linear; % k T B F


            % 최종 SINR 계산
            SINR_linear = desiredPower_W / (interferencePower_W + noisePower_W);
            SINR_dB = 10 * log10(SINR_linear);


            % DebugHelper.printSINRCalculation(obj.Id, desiredBeamId, desiredPacket.ChannelId, distance, desiredTxPower_dBm, desiredTxGain_dBi, desiredPower_W, ...
            %     interferencePackets, interferenceGain_dBi, interferencePowerEach_W, interferencePower_W, noisePower_W, SINR_dB, obj.SINRThreshold_dB);

        end



      
    end
end