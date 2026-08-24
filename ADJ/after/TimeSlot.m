classdef TimeSlot
    properties
        ReconnaissanceDuration
    end

    methods
        function obj = TimeSlot()
            env;
            obj.ReconnaissanceDuration = reconnaissanceDuration;
        end

        function run(obj, slotIndex, UTs, Satellite, APJ, ServiceChannels, ControlChannels)
            DebugHelper.printTimeSlot(slotIndex);

            %% 1. 채널 초기화
            obj.clearChannels(ServiceChannels, ControlChannels);

            %% 2. Satellite beam의 채널 선택 (Action a_t 선택) + Transition 완성 + 학습
            currentSlotOccupancy = zeros(1, numel(ServiceChannels));

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


            %% 4. APJ 정찰 / 학습 / 예측
            apj = APJ;

            % 4-0. 채점 대상: 저번 슬롯에서 "이번 슬롯"을 예측해둔 값
            previousPredictedChannel = apj.PredictedChannel;

            % 4-1. 이번 슬롯 Target의 실제 채널/SINR/Pseudo HARQ 관측 시도
            [observedChannel, estimatedSINR_dB, pseudoHARQ] = apj.observeTarget(ServiceChannels, Satellite);

            isEavesdropSuccessful = ~isempty(observedChannel);

            % 4-2. 예측 정확도 채점 (도청 성공 + 채점할 이전 예측이 있을 때만)
            if isEavesdropSuccessful && ~isempty(previousPredictedChannel)
                DebugHelper.recordAPJPrediction(slotIndex, previousPredictedChannel, observedChannel, numel(ServiceChannels));
            end

            % 4-3. 직전 슬롯 PendingState의 label 확정 -> 학습쌍 완성
            if isEavesdropSuccessful
                apj.Predictor.completeTrainingPair(observedChannel);
            end

            % 4-4. 학습
            [apjLossValue, apjTrainingInfo] = apj.Predictor.train();

            % 4-5. 이번 슬롯 O/A/H를 StateManager에 반영 (도청 성공한 슬롯만)
            if isEavesdropSuccessful
                observation = apj.ObservationManager.observe(ServiceChannels, Satellite);
                apj.StateManager.update(observation, observedChannel, pseudoHARQ);
            end

            currentApjState = apj.StateManager.getState();

            % 4-6. 이번 슬롯이 다음 슬롯 label의 PendingState가 됨 (정찰 성공 시에만)
            if isEavesdropSuccessful
                apj.Predictor.setPendingState(currentApjState);
            end

            % 4-7. 다음 슬롯 채널 예측 (정찰 기간 포함, 매 슬롯 시도 — 정확도 추적 목적)
            if apj.StateManager.isReady()
                [predictedChannel, ~] = apj.Predictor.predictChannel(currentApjState);
            else
                predictedChannel = [];
            end

            apj.PredictedChannel = predictedChannel;

            % 4-8. 공격 기간에만 실제 재밍 채널로 확정 (재밍 주입 로직은 아직 미구현)
            if slotIndex > obj.ReconnaissanceDuration
                apj.JammingChannel = predictedChannel;
            end

            %% 4. APJ 정찰 / 학습 / 예측 (Oracle 버전)
            % apj = APJ;
            % targetBeam = Satellite.Beams([Satellite.Beams.AssociatedUTId] == apj.TargetUTId);
            % 
            % % 0. 채점 대상: 저번 슬롯에서 만들어둔 예측
            % previousPredictedChannel = apj.PredictedChannel;
            % 
            % % 1. 실제 채널(Oracle이므로 도청/추정 없이 그대로 확보)
            % actualChannel = targetBeam.SelectedChannel;
            % 
            % % 2. 예측 정확도 채점
            % if ~isempty(previousPredictedChannel)
            %     DebugHelper.recordAPJPrediction(slotIndex, previousPredictedChannel, actualChannel, numel(ServiceChannels));
            % end
            % 
            % % 3. 학습쌍 완성 (Oracle이므로 항상 성공)
            % apj.Predictor.completeTrainingPair(actualChannel);
            % 
            % % 4. 학습
            % [apjLossValue, apjTrainingInfo] = apj.Predictor.train();
            % 
            % % 5. Oracle state = Target Beam의 실제 StateManager 그대로
            % oracleState = targetBeam.StateManager.getState();
            % 
            % % 6. 다음 슬롯 label의 PendingState로 저장
            % apj.Predictor.setPendingState(oracleState);
            % 
            % % 7. 다음 슬롯 채널 예측
            % if targetBeam.StateManager.isReady()
            %     [predictedChannel, ~] = apj.Predictor.predictChannel(oracleState);
            % else
            %     predictedChannel = [];
            % end
            % 
            % apj.PredictedChannel = predictedChannel;


            %% 4.5. APJ의 공격
            if slotIndex > obj.ReconnaissanceDuration && ~isempty(apj.PredictedChannel)
            
                jammingChannel = previousPredictedChannel;
                % 안전성 검사
                if ~isscalar(jammingChannel) || jammingChannel < 1 || jammingChannel > numel(ServiceChannels)
                    error("TimeSlot:InvalidJammingChannel", "Invalid jamming channel at slot %d: %s", slotIndex, mat2str(jammingChannel));
                end
                apj.JammingChannel = jammingChannel;
            
                % Target UT를 서비스하는 Beam 검색
            
                targetBeamIndex = find([Satellite.Beams.AssociatedUTId] == apj.TargetUTId, 1);
            
                if isempty(targetBeamIndex)
                    error("TimeSlot:TargetBeamNotFound", "Target UT %d에 연결된 Beam을 찾을 수 없습니다.", apj.TargetUTId);
                end
            
                targetBeamId = Satellite.Beams(targetBeamIndex).Id;
            
                jamPacket = Packet(PacketType.JAMMING, NodeType.APJ, apj.Id, ...
                    NodeType.UT, apj.TargetUTId, targetBeamId, ChannelType.Service, jammingChannel);
            
                ServiceChannels(jammingChannel).addPacket(jamPacket);
            
            end

            %% 5. UT의 HARQ 수행
            harqResults = cell(1, numel(UTs));
            sinrResults_dB = zeros(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                [packetType, SINR_dB] = UTs(utIndex).performHARQ(ServiceChannels, ControlChannels, Satellite, APJ);
                harqResults{utIndex} = packetType;
                sinrResults_dB(utIndex) = SINR_dB;

                if UTs(utIndex).IsTarget
                    DebugHelper.recordTargetUTOutcome(slotIndex, packetType, SINR_dB, obj.ReconnaissanceDuration);
                end
            end

            %% 6. Beam이 UT feedback 수신 및 reward 저장
            actualACK = false(1, numel(Satellite.Beams));
            for beamIndex = 1:numel(Satellite.Beams)
                beam = Satellite.Beams(beamIndex);
                actualACK(beamIndex) = beam.receiveFeedback(ControlChannels, Satellite);
                beam.Agent.setReward(actualACK(beamIndex));
            end

        end

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