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
            
            %% 1. 채널 초기화
            obj.clearChannels(ServiceChannels, ControlChannels);


            %% 2. Satellite beam의 채널 선택 (Action a_t 선택)
            for beamIndex = 1:numel(Satellite.Beams)
                beam = Satellite.Beams(beamIndex);
                selectedChannel = randi(numel(ServiceChannels));
                beam.SelectedChannel = selectedChannel;
            end
            

            %% 3. Satellite가 해당 채널로 DL 전송
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
            
            

            %% 4. UT와 APJ의 현재 RF 환경 sensing
            % - UT : o_{t+1}에 해당하는 새 observation 생성 / APJ : 자기 위치에서 별도 observation 생성
            for utIndex = 1:numel(UTs)
                UTs(utIndex).ObservationManager.observe(ServiceChannels, Satellite);
            end

            APJ.ObservationManager.observe(ServiceChannels, Satellite);

            % DebugHelper.printObservationSensing(UTs(1), UTs(1).ObservationManager, ServiceChannels, Satellite);
            % DebugHelper.printObservationSensing(APJ, APJ.ObservationManager, ServiceChannels, Satellite);


            %% 5. UT의 HARQ 수행
            harqResults = cell(1, numel(UTs));
            sinrResults_dB = zeros(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                [packetType, SINR_dB] = UTs(utIndex).performHARQ(ServiceChannels, ControlChannels, Satellite);

                harqResults{utIndex} = packetType;
                sinrResults_dB(utIndex) = SINR_dB;
            end

            % DebugHelper.printChannels(ServiceChannels, ControlChannels);
            % DebugHelper.printChannelDetail(ControlChannels);

            %% 6. Beam이 UT feedback 수신 및 State Update
            for beamIndex = 1:numel(Satellite.Beams)
                Satellite.Beams(beamIndex).receiveFeedback(ControlChannels, Satellite);
            end
            
            DebugHelper.printBeamState(Satellite.Beams(1));


            %% 7. Transition 완성 + Replay Buffer + DQN 학습(S_t, a_t, r_t, S_{t+1})

            %% 8. APJ 동작
            
          


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