classdef TimeSlot
    properties
        ReconnaissanceDuration
    end

    methods
        function obj = TimeSlot()
            env;
            obj.ReconnaissanceDuration = reconnaissanceDuration;
        end

        
        % function [result, actualTargetACK] = run(obj, slotIndex, UTs, Satellite, APJ, ServiceChannels, ControlChannels)
        function [harqResults, sinrResults_dB, actualTargetACK, successRatio] = run(obj, slotIndex, UTs, Satellite, APJ, ServiceChannels, ControlChannels)

            DebugHelper.printTimeSlot(slotIndex);
            

            %% 0. 채널 센싱 및 이전 Transition 완성
            
            %% 1. DQN 학습
          
            %% 2. 채널 초기화
            obj.clearChannels(ServiceChannels, ControlChannels);


            %% 3. Satellite beam의 채널 선택
            for beamIndex = 1:numel(Satellite.Beams)
                beam = Satellite.Beams(beamIndex);
                selectedChannel = randi(numel(ServiceChannels));
                beam.SelectedChannel = selectedChannel;
            end
            

            %% 4. Satellite가 Data를 Service 채널에 Beam을 통해 전송
            dataPackets = cell(1, numel(Satellite.Beams));

            % 패킷 생성
            for beamIndex = 1:numel(Satellite.Beams)
                beam = Satellite.Beams(beamIndex);
                selectedChannel = beam.SelectedChannel;
                destinationUTId = beam.AssociatedUTId;
                dataPackets{beamIndex} = Packet(PacketType.DATA, NodeType.Satellite, Satellite.Id, NodeType.UT, destinationUTId, beam.Id, ChannelType.Service, selectedChannel);
            end

            % Service Channel에 패킷 추가
            for beamIndex = 1:numel(dataPackets)
                packet = dataPackets{beamIndex};
                selectedChannel = packet.ChannelId;
                ServiceChannels(selectedChannel).addPacket(packet);
            end
            
            

            
            %% 5. APJ 동작
            
            
            

            %% 6. UT의 HARQ 수행
            harqResults = cell(1, numel(UTs));
            sinrResults_dB = zeros(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                [packetType, SINR_dB] = UTs(utIndex).performHARQ(ServiceChannels, ControlChannels, Satellite);

                harqResults{utIndex} = packetType;
                sinrResults_dB(utIndex) = SINR_dB;
            end

            DebugHelper.printChannels(ServiceChannels, ControlChannels);
            

            %% 7. UT & APJ의 결과 확인 및 reward 저장
          


            %% 결과 반환
            % Target UT ACK 여부
            actualTargetACK = (harqResults{1} == PacketType.ACK);
            
            % 전체 성공 개수
            numACK = 0;
            
            for utIndex = 1:numel(UTs)
                if harqResults{utIndex} == PacketType.ACK
                    numACK = numACK + 1;
                end
            end
            
            % 전체 성공률
            successRatio = numACK / numel(UTs);
            
        end




        %% 채널 초기화
        function clearChannels(obj, ServiceChannels, ControlChannels)
            for channelIndex = 1:numel(ServiceChannels)
                ServiceChannels(channelIndex).clearPacket();
            end

            for channelIndex = 1:numel(ControlChannels)
                ControlChannels(channelIndex).clearPacket();
            end

        end
    end
end