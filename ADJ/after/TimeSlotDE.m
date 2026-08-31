classdef TimeSlotDE
    % TimeSlotDE  (DQN Estimate)
    %
    % ================================================================
    % RF Observation + Oracle Action/Occupancy + "SINR 추정" Reward
    % ================================================================
    %
    % TimeSlotD와의 유일한 차이:
    %   - TimeSlotD  : Shadow Reward = Target의 실제 HARQ 결과(Oracle)
    %   - TimeSlotDE : Shadow Reward = APJD가 "자기 위치" 기준으로 추정한
    %                  SINR을 SINRThreshold_dB와 비교해 ACK/NACK을
    %                  스스로 판정한 Pseudo-HARQ (APJD.estimateTargetSINR
    %                  + APJD.generatePseudoHARQ 재사용 — BC 파이프라인
    %                  APJ.m에서 쓰던 것과 동일한 로직)
    %
    %   즉 "Target UT가 이번 슬롯에 성공했겠구나/실패했겠구나"를 APJD가
    %   직접 관측하지 않고(도청 아님) 자기 위치의 링크버짓만으로
    %   추정해서 reward로 쓴다. Action/Occupancy는 TimeSlotD와 동일하게
    %   여전히 Oracle.
    %
    % Action:   Target actual action  (Oracle, 변경 없음)
    % Occupancy: Oracle (변경 없음)
    % Reward:   APJD 자체 SINR 추정 기반 Pseudo-HARQ  (신규 — 이 파일의 핵심)
    %
    % [검증용 로그]
    %   divergenceLog에 estimatedOutcome(추정 reward)과 actualACK(실제
    %   reward)를 둘 다 기록해서, mainDE.m에서 "추정이 실제와 얼마나
    %   일치했는가"(Reward Estimation Accuracy)를 정찰/공격 구간별로
    %   집계할 수 있게 한다.
    %
    % [출력 정책]
    %   TimeSlotD와 동일 — DebugHelper.printTargetVsShadowDQN(...) 하나만
    %   콘솔에 출력, 나머지는 주석 처리.

    properties
        ReconnaissanceDuration
        TopKJam   % 1 = Top-1만 재밍, 2 = Top-1+Top-2 동시 재밍(기본값)
    end

    methods

        function obj = TimeSlotDE(topKJam)
            env;
            obj.ReconnaissanceDuration = reconnaissanceDuration;

            if nargin < 1 || isempty(topKJam)
                topKJam = 2;
            end
            obj.TopKJam = topKJam;
        end


        function [divergenceLog, channelLog] = run(obj, slotIndex, UTs, Satellite, apjd, ...
                ServiceChannels, ControlChannels, targetBeamIndex, divergenceLog, channelLog)

            %% 1. Time Slot Header
            % DebugHelper.printTimeSlot(slotIndex);

            %% 2. Channel 초기화
            obj.clearChannels(ServiceChannels, ControlChannels);

            %% 3. Satellite Beam Action Selection
            currentSlotOccupancy = zeros(1, numel(ServiceChannels));

            targetBeam = [];
            targetAgent = [];
            targetState = [];
            targetOccupancy = [];
            targetAction = [];

            targetPrevState = [];
            targetPrevOccupancy = [];
            targetPrevAction = [];
            targetPrevReward = [];
            targetNextState = [];
            targetNextOccupancy = [];

            lossTarget = [];

            for beamIndex = 1:numel(Satellite.Beams)

                beam = Satellite.Beams(beamIndex);

                state = beam.StateManager.getState();

                beam.StateManager.setCurrentOccupancy(currentSlotOccupancy);
                occupancy = beam.StateManager.getCurrentOccupancy();

                if beamIndex == targetBeamIndex
                    targetBeam = beam;
                    targetAgent = beam.Agent;

                    targetPrevState = beam.Agent.PendingState;
                    targetPrevOccupancy = beam.Agent.PendingOccupancy;
                    targetPrevAction = beam.Agent.PendingAction;
                    targetPrevReward = beam.Agent.PendingReward;

                    targetNextState = state;
                    targetNextOccupancy = occupancy;
                end

                beam.Agent.setCurrentState(state);
                beam.Agent.setCurrentOccupancy(occupancy);

                beam.Agent.completeTransition();

                [lossValue, trainingInfo] = beam.Agent.train();

                if beamIndex == targetBeamIndex
                    lossTarget = lossValue;
                    % DebugHelper.printAgentTraining(beam, lossValue, trainingInfo);
                end

                [selectedChannel, selectionMethod, randomValue, qValues] = ...
                    beam.Agent.selectAction(state, occupancy);

                beam.SelectedChannel = selectedChannel;
                currentSlotOccupancy(selectedChannel) = ...
                    currentSlotOccupancy(selectedChannel) + 1;

                if beamIndex == targetBeamIndex
                    targetState = state;
                    targetOccupancy = occupancy;
                    targetAction = selectedChannel;

                    % DebugHelper.printTargetActionSelection( ...
                    %     slotIndex, beam, selectedChannel, ...
                    %     selectionMethod, randomValue, qValues);

                    channelEntry.slot = slotIndex;
                    channelEntry.channel = selectedChannel;
                    channelEntry.epsilon = beam.Agent.Epsilon;
                    channelEntry.method = selectionMethod;

                    if isempty(qValues)
                        channelEntry.qValues = NaN(1, beam.Agent.NumActions);
                    else
                        channelEntry.qValues = qValues(:)';
                    end

                    channelLog(end + 1) = channelEntry; %#ok<AGROW>
                end
            end

            if isempty(targetAgent)
                error( ...
                    "TimeSlotDE:TargetAgentNotFound", ...
                    "Target Beam %d의 Agent를 찾지 못했습니다.", ...
                    targetBeamIndex);
            end


            %% 4. APJD Attack Decision (Top-K Jamming)
            previousPredictedChannel = apjd.PredictedChannel;
            previousPredictedQValues = apjd.PredictedQValues;

            previousPredictedTop2Channel = [];
            if obj.TopKJam >= 2 && ~isempty(previousPredictedQValues)
                [~, rankedChannels] = sort(previousPredictedQValues(:), 'descend');
                if numel(rankedChannels) >= 2
                    previousPredictedTop2Channel = rankedChannels(2);
                end
            end

            isAttackPhase = slotIndex > obj.ReconnaissanceDuration;
            jammingChannels = [];

            if isAttackPhase

                if ~isempty(previousPredictedChannel)
                    jammingChannels = previousPredictedChannel;

                    if ~isempty(previousPredictedTop2Channel) && ...
                            previousPredictedTop2Channel ~= previousPredictedChannel
                        jammingChannels = [jammingChannels, previousPredictedTop2Channel]; %#ok<AGROW>
                    end

                    apjd.JammingChannel = jammingChannels(1);
                else
                    apjd.JammingChannel = [];
                end

            else
                apjd.JammingChannel = [];
            end

            if ~isempty(previousPredictedChannel)
                DebugHelper.recordAPJPrediction( ...
                    slotIndex, previousPredictedChannel, targetAction, numel(ServiceChannels));
            end

            % fprintf("\n");
            % fprintf("============================================================\n");
            % fprintf("APJD ATTACK STATUS - SLOT %d\n", slotIndex);
            % fprintf("============================================================\n");
            % (이하 동일 — 콘솔 출력 최소화 정책으로 주석 처리)


            %% 5. Satellite -> UT Downlink DATA 전송
            dataPackets = cell(1, numel(Satellite.Beams));

            for beamIndex = 1:numel(Satellite.Beams)

                beam = Satellite.Beams(beamIndex);

                dataPackets{beamIndex} = Packet( ...
                    PacketType.DATA, ...
                    NodeType.Satellite, ...
                    Satellite.Id, ...
                    NodeType.UT, ...
                    beam.AssociatedUTId, ...
                    beam.Id, ...
                    ChannelType.Service, ...
                    beam.SelectedChannel);
            end

            for beamIndex = 1:numel(dataPackets)
                packet = dataPackets{beamIndex};
                ServiceChannels(packet.ChannelId).addPacket(packet);
            end


            %% 5.5. APJD 실제 재밍 패킷 주입 (Top-K 채널 전부)
            if isAttackPhase && ~isempty(jammingChannels)

                targetBeamId = Satellite.Beams(targetBeamIndex).Id;

                for jammingChannel = jammingChannels

                    jamPacket = Packet( ...
                        PacketType.JAMMING, ...
                        NodeType.APJ, ...
                        apjd.Id, ...
                        NodeType.UT, ...
                        apjd.TargetUTId, ...
                        targetBeamId, ...
                        ChannelType.Service, ...
                        jammingChannel);

                    ServiceChannels(jammingChannel).addPacket(jamPacket);
                end
            end


            %% 6. Target UT / APJD RF Observation
            targetUT = UTs(apjd.TargetUTId);

            targetUTRFObservation = ...
                targetUT.ObservationManager.observe( ...
                    ServiceChannels, Satellite);

            apjdRFObservation = ...
                apjd.ObservationManager.observe( ...
                    ServiceChannels, Satellite);

            % (RAW RF OBSERVATION VECTOR 출력 — 주석 처리)


            %% 6.5. [신규] APJD 자체 SINR 추정 -> Pseudo-HARQ 산출
            %
            % 이 시점(섹션 5, 5.5 이후)에는 이번 슬롯의 DATA 패킷과
            % (공격 중이면) JAMMING 패킷까지 ServiceChannels에 전부
            % 주입되어 있으므로, APJD가 "자기 위치" 기준으로 계산하는
            % estimateTargetSINR에 재밍 효과가 실제로 반영된다.
            %
            % Target 실제 채널을 오라클로 아는 것과는 별개로(도청 아님),
            % "그 채널에서 Target이 성공했을지 실패했을지"는 여기서
            % 처음으로 추정(estimate)된다 — 이 추정값이 이 파일에서
            % Shadow DQN의 reward로 쓰인다.
            estimatedSINR_dB = apjd.estimateTargetSINR(ServiceChannels, Satellite, targetUT);
            estimatedPacketType = apjd.generatePseudoHARQ(estimatedSINR_dB);

            if isempty(estimatedPacketType)
                estimatedOutcome = NaN;   % Target 패킷을 못 찾은 예외 상황
            else
                estimatedOutcome = double(estimatedPacketType == PacketType.ACK);
            end


            %% 7. APJD Shadow Agent
            shadowAgent = apjd.Agent;

            shadowState = apjd.StateManager.getState();

            shadowOccupancy = targetOccupancy;

            shadowAgent.setCurrentState(shadowState);
            shadowAgent.setCurrentOccupancy(shadowOccupancy);


            %% 7-1. RF State / Oracle component 비교 — 주석 처리


            %% 7-2. Shadow 이전 Transition 완성
            shadowAgent.completeTransition();


            %% 7-3. Shadow DQN 학습
            [lossShadow, trainingInfoShadow] = ...
                shadowAgent.train();

            % DebugHelper.printShadowTraining(...) — 주석 처리


            %% 7-4. Target Actual Action Oracle 제공 (Action은 변경 없음)
            shadowAgent.observeAction( ...
                shadowState, ...
                shadowOccupancy, ...
                targetAction);

            apjd.ObservedChannel = targetAction;


            %% 7-5. Target / Shadow Q-vector 계산
            dlTargetState = ...
                targetAgent.convertStateToDLArray(targetState);

            dlTargetOccupancy = ...
                targetAgent.convertOccupancyToDLArray(targetOccupancy);

            qTarget = extractdata( ...
                predict( ...
                    targetAgent.QNetwork, ...
                    dlTargetState, ...
                    dlTargetOccupancy));

            qTarget = double(qTarget(:));


            dlShadowState = ...
                shadowAgent.convertStateToDLArray(shadowState);

            dlShadowOccupancy = ...
                shadowAgent.convertOccupancyToDLArray(shadowOccupancy);

            qShadow = extractdata( ...
                predict( ...
                    shadowAgent.QNetwork, ...
                    dlShadowState, ...
                    dlShadowOccupancy));

            qShadow = double(qShadow(:));


            [~, greedyTarget] = max(qTarget);
            [~, greedyShadow] = max(qShadow);

            qCosSim = dot(qTarget, qShadow) / ...
                (norm(qTarget) * norm(qShadow) + eps);

            argmaxMatch = ...
                double(greedyTarget == greedyShadow);

            qL2Dist = ...
                norm(qTarget - qShadow);

            weightDiffNorm = ...
                TimeSlotDE.computeWeightDiffNorm( ...
                    targetAgent.QNetwork, ...
                    shadowAgent.QNetwork);

            weightNormTarget = ...
                TimeSlotDE.computeNetworkNorm( ...
                    targetAgent.QNetwork);

            weightNormShadow = ...
                TimeSlotDE.computeNetworkNorm( ...
                    shadowAgent.QNetwork);

            % ---- 유일하게 콘솔에 남기는 출력 ----
            DebugHelper.printTargetVsShadowDQN( ...
                slotIndex, ...
                targetAction, ...
                qTarget, ...
                qShadow, ...
                greedyTarget, ...
                greedyShadow, ...
                qCosSim, ...
                qL2Dist, ...
                weightDiffNorm, ...
                weightNormTarget, ...
                weightNormShadow);

            % 위 DebugHelper.printTargetVsShadowDQN 안에 "Shadow Reward
            % Source: ORACLE"이라는 문구가 하드코딩되어 있는데, 이건
            % TimeSlotD/TimeSlotDE 공용으로 쓰이는 고정 텍스트라
            % TimeSlotDE에서는 실제 사실과 다르다(TimeSlotDE는 여기서
            % 실제로 SINR 추정치를 reward로 씀). actualACK는 아직 이
            % 시점엔 계산 전이라(9번 섹션에서 계산됨), 여기서는 추정치만
            % 먼저 찍는다.
            fprintf("  [TimeSlotDE 실제 Reward Source] : SINR ESTIMATE (estimatedOutcome=%s, 실제결과는 아래 9~10번 이후 확정)\n", ...
                mat2str(estimatedOutcome));


            %% 7-6. Divergence Log
            if isempty(lossTarget)
                lossTargetLog = NaN;
            else
                lossTargetLog = lossTarget;
            end

            if isempty(lossShadow)
                lossShadowLog = NaN;
            else
                lossShadowLog = lossShadow;
            end

            entry.slot = slotIndex;
            entry.lossA = lossTargetLog;
            entry.lossB = lossShadowLog;
            entry.qCosSim = qCosSim;
            entry.argmaxMatch = argmaxMatch;
            entry.weightDiffNorm = weightDiffNorm;
            entry.weightNormA = weightNormTarget;
            entry.weightNormB = weightNormShadow;
            entry.qA = qTarget(:)';
            entry.qB = qShadow(:)';
            entry.qL2Dist = qL2Dist;
            entry.observedChannel = targetAction;
            entry.actualACK = NaN;          % 12번에서 채움 (실제 결과, 비교용으로만 기록)
            entry.estimatedOutcome = estimatedOutcome;  % 이 파일에서 실제로 reward에 쓰인 값

            entry.isAttackPhase = isAttackPhase;
            entry.jammingChannels = jammingChannels;

            divergenceLog(end + 1) = entry; %#ok<AGROW>


            %% 8. UT HARQ 수행 (실제 결과 — Target 자신의 학습과 비교/검증용으로만 기록)
            harqResults = cell(1, numel(UTs));
            sinrResults_dB = zeros(1, numel(UTs));
            targetPacketType = [];
            targetSINR_dB = [];

            for utIndex = 1:numel(UTs)

                [packetType, SINR_dB] = ...
                    UTs(utIndex).performHARQ( ...
                        ServiceChannels, ...
                        ControlChannels, ...
                        Satellite, ...
                        apjd);

                harqResults{utIndex} = packetType;
                sinrResults_dB(utIndex) = SINR_dB;

                if utIndex == apjd.TargetUTId
                    targetPacketType = packetType;
                    targetSINR_dB = SINR_dB;
                end
            end


            %% 9. Beam Feedback 수신 / Target Reward (Target 자신은 항상 실제 결과로 학습)
            actualACK = ...
                false(1, numel(Satellite.Beams));

            for beamIndex = 1:numel(Satellite.Beams)

                beam = Satellite.Beams(beamIndex);

                actualACK(beamIndex) = ...
                    beam.receiveFeedback( ...
                        ControlChannels, ...
                        Satellite);

                beam.Agent.setReward( ...
                    actualACK(beamIndex));
            end


            %% 10. [변경] Shadow Reward = APJD SINR 추정치 (Oracle 아님)
            %
            % TimeSlotD.m에서는 여기서 actualACK(targetBeamIndex)를 그대로
            % 썼지만, 이 파일(TimeSlotDE)에서는 섹션 6.5에서 미리 구해둔
            % estimatedOutcome을 사용한다. estimatedOutcome이 NaN이면
            % (Target 패킷을 못 찾은 예외) 안전하게 false(NACK로 취급)로
            % 대체한다.
            targetOutcome = ...
                actualACK(targetBeamIndex);   % Target 자신 학습용으로만 유지 (참고/비교값)

            if isnan(estimatedOutcome)
                shadowRewardOutcome = false;
            else
                shadowRewardOutcome = logical(estimatedOutcome);
            end

            shadowAgent.setReward( ...
                shadowRewardOutcome);

            if shadowRewardOutcome == targetOutcome
                matchLabel = "MATCH";
            else
                matchLabel = "MISMATCH";
            end
            fprintf("  [TimeSlotDE Reward 확정] : Shadow=%s (추정) vs Target=%s (실제) -> %s\n", ...
                mat2str(shadowRewardOutcome), mat2str(targetOutcome), matchLabel);

            % DebugHelper.printRewardResult(...) — 주석 처리

            DebugHelper.recordTargetUTOutcome( ...
                slotIndex, targetPacketType, targetSINR_dB, obj.ReconnaissanceDuration);


            %% 11. APJD StateManager Update (O=RF관측, A/H는 여전히 Oracle)
            if isempty(apjdRFObservation)

                warning( ...
                    "TimeSlotDE:EmptyAPJDRFObservation", ...
                    "Slot %d에서 APJD RF observation이 비어 있습니다.", ...
                    slotIndex);

            else

                apjd.StateManager.update( ...
                    apjdRFObservation, ...
                    targetAction, ...
                    targetPacketType);
            end


            %% 12. ACK / 추정치 비교 Log
            if ~isempty(divergenceLog) && ...
               divergenceLog(end).slot == slotIndex

                divergenceLog(end).actualACK = ...
                    double(targetOutcome);
            end


            %% 13. NEXT-SLOT Shadow Prediction
            nextShadowState = ...
                apjd.StateManager.getState();

            predictionOccupancy = ...
                targetOccupancy;

            [predictedAction, predictedQValues] = ...
                shadowAgent.predictAction( ...
                    nextShadowState, ...
                    predictionOccupancy);

            apjd.PredictedChannel = ...
                predictedAction;

            apjd.PredictedQValues = ...
                predictedQValues;

            % (APJD NEXT-SLOT PREDICTION 출력 — 주석 처리)
        end


        function clearChannels(~, ServiceChannels, ControlChannels)

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

            learnA = networkA.Learnables;
            learnB = networkB.Learnables;

            if height(learnA) ~= height(learnB)
                error( ...
                    "TimeSlotDE:NetworkStructureMismatch", ...
                    "Target과 Shadow Network 구조가 다릅니다.");
            end

            sumSquares = 0;

            for learnableIndex = 1:height(learnA)

                valueA = ...
                    double( ...
                        extractdata( ...
                            learnA.Value{learnableIndex}));

                valueB = ...
                    double( ...
                        extractdata( ...
                            learnB.Value{learnableIndex}));

                if ~isequal(size(valueA), size(valueB))
                    error( ...
                        "TimeSlotDE:NetworkParameterSizeMismatch", ...
                        "Target/Shadow parameter size가 다릅니다.");
                end

                difference = ...
                    valueA(:) - valueB(:);

                sumSquares = ...
                    sumSquares + sum(difference .^ 2);
            end

            normDiff = ...
                sqrt(sumSquares);
        end


        function normValue = computeNetworkNorm(network)

            learnables = ...
                network.Learnables;

            sumSquares = 0;

            for learnableIndex = 1:height(learnables)

                value = ...
                    double( ...
                        extractdata( ...
                            learnables.Value{learnableIndex}));

                sumSquares = ...
                    sumSquares + ...
                    sum(value(:) .^ 2);
            end

            normValue = ...
                sqrt(sumSquares);
        end


        function text = phaseToString(isAttackPhase)

            if isAttackPhase
                text = "ATTACK";
            else
                text = "RECONNAISSANCE";
            end
        end

    end

end