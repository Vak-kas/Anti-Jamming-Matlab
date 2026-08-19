classdef TimeSlot
    properties
        ReconnaissanceDuration
        % BeamLearnRate
    end
    methods
        function obj = TimeSlot()
            env;
            obj.ReconnaissanceDuration = reconnaissanceDuration;
            % obj.BeamLearnRate = beamLearnRate;
        end

        function [harqResults, sinrResults_dB, actualTargetACK, successRatio] = run(obj, slotIndex, UTs, Satellite, APJ, ServiceChannels, ControlChannels)
            DebugHelper.printTimeSlot(slotIndex);

            %% 1. 채널 초기화
            obj.clearChannels(ServiceChannels, ControlChannels);

            %% 2. Satellite beam의 채널 선택 (Action a_t 선택) + Transition 완성 + 학습
            currentSlotOccupancy = zeros(1, numel(ServiceChannels));
            % mainLearnerIndex = mod(slotIndex-1, numel(Satellite.Beams)) + 1;   % Multi-Timescale: 라운드로빈 순번

            for beamIndex = 1:numel(Satellite.Beams)
                beam = Satellite.Beams(beamIndex);
                state = beam.StateManager.getState();
                beam.StateManager.setCurrentOccupancy(currentSlotOccupancy);
                occupancy = beam.StateManager.getCurrentOccupancy();

                % occupancy가 확정되는 유일한 순간 — 이전 슬롯 transition을 완성
                beam.Agent.setCurrentState(state);
                beam.Agent.setCurrentOccupancy(occupancy);
                beam.Agent.completeTransition();

                % 방금 완성된 transition으로 즉시 학습 (다음 행동 선택 전에 최신 가중치 반영)
                [lossValue, trainingInfo] = beam.Agent.train();
                if beamIndex == 1
                    DebugHelper.printAgentTraining(beam, lossValue, trainingInfo);
                end

                % 이번 슬롯 행동 선택 (a_t)
                [selectedChannel, selectionMethod, randomValue, qValues] = beam.Agent.selectAction(state, occupancy);
                % selectedChannel = randi(numel(ServiceChannels));

                beam.SelectedChannel = selectedChannel;
                currentSlotOccupancy(selectedChannel) = currentSlotOccupancy(selectedChannel) + 1;

                if beamIndex == 1
                    % DebugHelper.recordBeamPolicy(slotIndex, qValues);
                end
            end

            %% 3. Satellite가 해당 채널로 DL 전송
            dataPackets = cell(1, numel(Satellite.Beams));
            for beamIndex = 1:numel(Satellite.Beams)
                beam = Satellite.Beams(beamIndex);
                selectedChannel = beam.SelectedChannel;
                destinationUTId = beam.AssociatedUTId;
                dataPackets{beamIndex} = Packet(PacketType.DATA, NodeType.Satellite, Satellite.Id, NodeType.UT, destinationUTId, beam.Id, ChannelType.Service, selectedChannel);
            end
            for beamIndex = 1:numel(dataPackets)
                packet = dataPackets{beamIndex};
                selectedChannel = packet.ChannelId;
                ServiceChannels(selectedChannel).addPacket(packet);
            end

            %% 4. UT와 APJ의 현재 RF 환경 sensing
            for utIndex = 1:numel(UTs)
                UTs(utIndex).ObservationManager.observe(ServiceChannels, Satellite);
            end
            APJ.ObservationManager.observe(ServiceChannels, Satellite);

            %% 5. UT의 HARQ 수행
            harqResults = cell(1, numel(UTs));
            sinrResults_dB = zeros(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                [packetType, SINR_dB] = UTs(utIndex).performHARQ(ServiceChannels, ControlChannels, Satellite);
                harqResults{utIndex} = packetType;
                sinrResults_dB(utIndex) = SINR_dB;
            end

            %% 6. Beam이 UT feedback 수신 및 reward 저장
            actualACK = false(1, numel(Satellite.Beams));
            for beamIndex = 1:numel(Satellite.Beams)
                beam = Satellite.Beams(beamIndex);
                actualACK(beamIndex) = beam.receiveFeedback(ControlChannels, Satellite);
                beam.Agent.setReward(actualACK(beamIndex));
            end

            %% 결과 반환
            actualTargetACK = (harqResults{1} == PacketType.ACK);
            numACK = 0;
            for utIndex = 1:numel(UTs)
                if harqResults{utIndex} == PacketType.ACK
                    numACK = numACK + 1;
                end
            end
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