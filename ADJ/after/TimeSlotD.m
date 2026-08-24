classdef TimeSlotD
    % TimeSlotD
    %
    % DQN 재현성(Reproducibility) 테스트 전용 TimeSlot.
    %
    % - 환경(20개 Beam의 채널 경합, HARQ 등)은 기존 TimeSlot과 동일하게 진행시킨다.
    % - Target Beam(실제로는 targetBeamIndex로 지정된 Beam)이 그 슬롯에서
    %   completeTransition() 하기 직전에 만들어내는 진짜 transition
    %   (state, occupancy, action, reward, nextState, nextOccupancy)을 그대로 캡처해서,
    %   별도로 만든 Agent A / Agent B의 ReplayBuffer에 동일하게 주입하고 각자 학습시킨다.
    % - Agent A/B는 환경(채널 선택)에는 전혀 관여하지 않는다 (순수 관찰자/학습기).
    % - 매 슬롯 두 Agent의 Q-network를 같은 probe state로 비교해서
    %   (cosine similarity, argmax 일치 여부, weight L2 diff) 발산 여부를 기록한다.
    % - APJ 관련 로직(정찰/학습/공격)은 이 테스트 목적과 무관하므로 제외했다.
    %   (APJ 객체 자체는 UT.performHARQ 인터페이스 유지를 위해 그대로 전달만 함 — 재밍은 발생하지 않음)

    properties
        % 슬롯 간 유지할 상태 없음
    end

    methods
        function obj = TimeSlotD()
        end

        function [divergenceLog, channelLog] = run(obj, slotIndex, UTs, Satellite, APJ, ServiceChannels, ControlChannels, AgentA, AgentB, targetBeamIndex, divergenceLog, channelLog)
            DebugHelper.printTimeSlot(slotIndex);

            %% 1. 채널 초기화
            obj.clearChannels(ServiceChannels, ControlChannels);

            %% 2. Satellite beam의 채널 선택 (Action a_t 선택) + Transition 완성 + 학습
            currentSlotOccupancy = zeros(1, numel(ServiceChannels));

            targetTransition = [];  % Target Beam의 이번 슬롯 완성 transition 캡처용

            for beamIndex = 1:numel(Satellite.Beams)
                beam = Satellite.Beams(beamIndex);
                state = beam.StateManager.getState();
                beam.StateManager.setCurrentOccupancy(currentSlotOccupancy);
                occupancy = beam.StateManager.getCurrentOccupancy();

                beam.Agent.setCurrentState(state);
                beam.Agent.setCurrentOccupancy(occupancy);

                % Target Beam이면: completeTransition()이 Pending 필드를 비우기 전에
                % 이번 슬롯에 실제로 완성되는 transition을 캡처해둔다.
                if beamIndex == targetBeamIndex ...
                        && ~isempty(beam.Agent.PendingState) ...
                        && ~isempty(beam.Agent.PendingAction) ...
                        && ~isempty(beam.Agent.PendingReward) ...
                        && ~isempty(beam.Agent.CurrentState)
                    targetTransition.state        = beam.Agent.PendingState;
                    targetTransition.occupancy      = beam.Agent.PendingOccupancy;
                    targetTransition.action         = beam.Agent.PendingAction;
                    targetTransition.reward         = beam.Agent.PendingReward;
                    targetTransition.nextState      = beam.Agent.CurrentState;
                    targetTransition.nextOccupancy  = beam.Agent.CurrentOccupancy;
                end

                beam.Agent.completeTransition();

                [lossValue, trainingInfo] = beam.Agent.train();
                if beamIndex == 1
                    DebugHelper.printAgentTraining(beam, lossValue, trainingInfo);
                end

                [selectedChannel, selectionMethod, randomValue, qValues] = beam.Agent.selectAction(state, occupancy);

                beam.SelectedChannel = selectedChannel;
                currentSlotOccupancy(selectedChannel) = currentSlotOccupancy(selectedChannel) + 1;

                % Target Beam의 채널 선택 / Epsilon / Q-value를 매 슬롯 기록 (collapse 시점 진단용)
                if beamIndex == targetBeamIndex
                    channelEntry.slot = slotIndex;
                    channelEntry.channel = selectedChannel;
                    channelEntry.epsilon = beam.Agent.Epsilon;  % selectAction 내부에서 이미 decay된 이후 값
                    channelEntry.method = selectionMethod;      % "Random" or "DQN"
                    if isempty(qValues)
                        channelEntry.qValues = NaN(1, beam.Agent.NumActions);
                    else
                        channelEntry.qValues = qValues(:)';
                    end
                    channelLog(end + 1) = channelEntry; %#ok<AGROW>
                end
            end

            %% 2.5. Target Beam의 실제 transition을 Agent A / Agent B에 동일하게 주입 + 학습 + 비교
            if ~isempty(targetTransition)
                AgentA.ReplayBuffer.add(targetTransition.state, targetTransition.occupancy, ...
                    targetTransition.action, targetTransition.reward, ...
                    targetTransition.nextState, targetTransition.nextOccupancy);
                AgentB.ReplayBuffer.add(targetTransition.state, targetTransition.occupancy, ...
                    targetTransition.action, targetTransition.reward, ...
                    targetTransition.nextState, targetTransition.nextOccupancy);

                [lossA, ~] = AgentA.train();
                [lossB, ~] = AgentB.train();
                if isempty(lossA), lossA = NaN; end
                if isempty(lossB), lossB = NaN; end

                % 같은 probe state(이번 슬롯의 next state)로 두 Agent의 Q-vector 비교
                probeState = targetTransition.nextState;
                probeOccupancy = targetTransition.nextOccupancy;

                dlProbeState = AgentA.convertStateToDLArray(probeState);
                dlProbeOccupancy = dlarray(single(reshape(probeOccupancy, [], 1)), "CB");

                qA = extractdata(predict(AgentA.QNetwork, dlProbeState, dlProbeOccupancy));
                qB = extractdata(predict(AgentB.QNetwork, dlProbeState, dlProbeOccupancy));

                qCosSim = dot(qA(:), qB(:)) / (norm(qA(:)) * norm(qB(:)) + eps);
                [~, argmaxA] = max(qA);
                [~, argmaxB] = max(qB);
                argmaxMatch = double(argmaxA == argmaxB);

                weightDiffNorm = TimeSlotD.computeWeightDiffNorm(AgentA.QNetwork, AgentB.QNetwork);
                weightNormA = TimeSlotD.computeNetworkNorm(AgentA.QNetwork);
                weightNormB = TimeSlotD.computeNetworkNorm(AgentB.QNetwork);
                qL2Dist = norm(qA(:) - qB(:));

                entry.slot = slotIndex;
                entry.lossA = lossA;
                entry.lossB = lossB;
                entry.qCosSim = qCosSim;
                entry.argmaxMatch = argmaxMatch;
                entry.weightDiffNorm = weightDiffNorm;
                entry.weightNormA = weightNormA;
                entry.weightNormB = weightNormB;
                entry.qA = qA(:)';   % 채널별 Q-value 절대값 (Agent A)
                entry.qB = qB(:)';   % 채널별 Q-value 절대값 (Agent B)
                entry.qL2Dist = qL2Dist;
                divergenceLog(end + 1) = entry; %#ok<AGROW>

                if mod(slotIndex, 100) == 0
                    fprintf("[Slot %d] lossA=%.4f lossB=%.4f cosSim=%.4f argmaxMatch=%d weightDiffNorm=%.4f\n", ...
                        slotIndex, lossA, lossB, qCosSim, argmaxMatch, weightDiffNorm);
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

            %% 4. UT의 HARQ 수행 (APJ는 전달만 하고 이 테스트에서는 재밍을 걸지 않음)
            harqResults = cell(1, numel(UTs));
            sinrResults_dB = zeros(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                [packetType, SINR_dB] = UTs(utIndex).performHARQ(ServiceChannels, ControlChannels, Satellite, APJ);
                harqResults{utIndex} = packetType;
                sinrResults_dB(utIndex) = SINR_dB;
            end

            %% 5. Beam이 UT feedback 수신 및 reward 저장
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

    methods (Static)
        function normDiff = computeWeightDiffNorm(networkA, networkB)
            % 두 dlnetwork의 Learnables(가중치) L2 거리 총합
            learnA = networkA.Learnables;
            learnB = networkB.Learnables;
            normDiff = 0;
            for i = 1:height(learnA)
                valA = extractdata(learnA.Value{i});
                valB = extractdata(learnB.Value{i});
                normDiff = normDiff + norm(valA(:) - valB(:));
            end
        end

        function normVal = computeNetworkNorm(network)
            % 하나의 dlnetwork Learnables(가중치) 전체 L2 norm
            learn = network.Learnables;
            normVal = 0;
            for i = 1:height(learn)
                val = extractdata(learn.Value{i});
                normVal = normVal + norm(val(:));
            end
        end
    end
end