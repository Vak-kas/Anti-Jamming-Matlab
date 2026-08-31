%% ==================== final1.m ====================
%  Reconnaissance Duration Sweep (RQ2: 정찰이 정말 필요한가?)
%  x축: Reconnaissance Duration {0,500,1000,1500,2000}
%  Fixed Attack Evaluation Window = 1000 slots (numTimeSlots = recon + 1000)
%  y축: ① Jamming Hit Rate (Top-2)  ② Prediction Accuracy (Top-1)  ③ Target Success Rate

clc; clear; clear variables; clear DebugHelper; close all;

reconDurationList = [0, 500, 1000, 1500, 2000];
attackWindow = 1000;
numTrials = 3;

hitRateResults  = nan(numel(reconDurationList), numTrials);
predAccResults  = nan(numel(reconDurationList), numTrials);
successResults  = nan(numel(reconDurationList), numTrials);

for reconIdx = 1:numel(reconDurationList)
    reconDuration = reconDurationList(reconIdx);

    for trial = 1:numTrials
        rng(trial);
        env;
        numTimeSlots = reconDuration + attackWindow;   % 공정 비교를 위해 Attack 구간 길이 고정

        ServiceChannels = Channel.empty(0, numChannels);
        ControlChannels = Channel.empty(0, numChannels);
        for channelIndex = 1:numChannels
            centerFreq_Hz = serviceBandStart_Hz + (channelIndex - 0.5) * channelSpacing_Hz;
            serviceChannelStart_Hz = centerFreq_Hz - channelBandwidth_Hz / 2;
            serviceChannelEnd_Hz = centerFreq_Hz + channelBandwidth_Hz / 2;
            ServiceChannels(channelIndex) = Channel(channelIndex, ChannelType.Service, serviceChannelStart_Hz, serviceChannelEnd_Hz);
            ControlChannels(channelIndex) = Channel(channelIndex, ChannelType.Control, 1, 2);
        end

        satellitePosition = [0 0 satelliteAltitude];
        SatelliteNode = Satellite(9999, satellitePosition, numBeams);

        Beams = BeamFactory.createBeams(numBeams, maxBeamFootprintDiameter, beamRadius, beamSpacing, beamMaxGain_dBi, beam3dBWidth_deg, beamEIRPDensity_dBW_per_MHz, channelBandwidth_Hz);
        for beamIndex = 1:numBeams
            SatelliteNode.addBeam(Beams(beamIndex));
        end

        UTs = UTFactory.createUTs(Beams, numUTs);

        targetBeamIndex = find([Beams.AssociatedUTId] == targetUTId, 1);
        if isempty(targetBeamIndex)
            error("final1:TargetBeamNotFound", "targetUTId %d 에 연결된 Beam을 찾을 수 없습니다.", targetUTId);
        end

        apjd = APJDFactory.createAPJD(UTs, Beams, targetUTId, targetJammerDistance);

        timeSlotDE = TimeSlotDE(2);
        timeSlotDE.ReconnaissanceDuration = reconDuration;

        fprintf("\n============================================================\n");
        fprintf(" [Recon Sweep] ReconDuration=%d, AttackWindow=%d, Trial %d/%d\n", reconDuration, attackWindow, trial, numTrials);
        fprintf("============================================================\n");

        divergenceLog = struct('slot', {}, 'lossA', {}, 'lossB', {}, 'qCosSim', {}, 'argmaxMatch', {}, ...
            'weightDiffNorm', {}, 'weightNormA', {}, 'weightNormB', {}, 'qA', {}, 'qB', {}, 'qL2Dist', {}, ...
            'observedChannel', {}, 'actualACK', {}, 'estimatedOutcome', {}, 'isAttackPhase', {}, 'jammingChannels', {});
        channelLog = struct('slot', {}, 'channel', {}, 'epsilon', {}, 'method', {}, 'qValues', {});

        for slotIndex = 1:numTimeSlots
            [divergenceLog, channelLog] = timeSlotDE.run(slotIndex, UTs, SatelliteNode, apjd, ServiceChannels, ControlChannels, targetBeamIndex, divergenceLog, channelLog);
        end

        if isempty(divergenceLog)
            warning("final1:EmptyLog", "ReconDuration=%d, Trial=%d: 로그 없음.", reconDuration, trial);
            continue;
        end

        isAttackPhaseLog = [divergenceLog.isAttackPhase];
        observedChannels = [divergenceLog.observedChannel];
        qB_matrix = vertcat(divergenceLog.qB);
        attackIdx = find(isAttackPhaseLog);

        % ① JHR (Top-2, 실제 재밍 자원 기준)
        hitCount = 0; totalCount = 0;
        for idx = attackIdx
            jc = divergenceLog(idx).jammingChannels;
            if isempty(jc), continue; end
            totalCount = totalCount + 1;
            if any(observedChannels(idx) == jc)
                hitCount = hitCount + 1;
            end
        end
        if totalCount > 0
            hitRateResults(reconIdx, trial) = hitCount / totalCount * 100;
        end

        % ② Prediction Accuracy (Top-1, Attack 구간)
        top1Hit = 0;
        for idx = attackIdx
            [~, shadowRanking] = sort(qB_matrix(idx, :), 'descend');
            if observedChannels(idx) == shadowRanking(1)
                top1Hit = top1Hit + 1;
            end
        end
        if numel(attackIdx) > 0
            predAccResults(reconIdx, trial) = top1Hit / numel(attackIdx) * 100;
        end

        % ③ Target Success Rate (Attack 구간)
        evalUTData = DebugHelper.TargetUTStorage('get', []);
        if ~isempty(evalUTData.slots)
            evalUTAttackIdx = logical(evalUTData.isAttackPhase);
            if any(evalUTAttackIdx)
                successResults(reconIdx, trial) = mean(evalUTData.isACK(evalUTAttackIdx)) * 100;
            end
        end

        fprintf("  -> JHR(Top-2)=%.2f%%, PredAcc(Top-1)=%.2f%%, SuccessRate=%.2f%%\n", ...
            hitRateResults(reconIdx, trial), predAccResults(reconIdx, trial), successResults(reconIdx, trial));
    end
end

%% ==================== 결과 집계 ====================
meanHit = mean(hitRateResults, 2, 'omitnan');  stdHit = std(hitRateResults, 0, 2, 'omitnan');
meanAcc = mean(predAccResults, 2, 'omitnan');  stdAcc = std(predAccResults, 0, 2, 'omitnan');
meanSuc = mean(successResults, 2, 'omitnan');  stdSuc = std(successResults, 0, 2, 'omitnan');

fprintf("\n============================================================\n");
fprintf(" Reconnaissance Duration Sweep — 최종 결과 (Fixed Attack Window=%d)\n", attackWindow);
fprintf("============================================================\n");
for i = 1:numel(reconDurationList)
    fprintf("Recon=%4d : JHR %.2f%%(±%.2f) | PredAcc %.2f%%(±%.2f) | Success %.2f%%(±%.2f)\n", ...
        reconDurationList(i), meanHit(i), stdHit(i), meanAcc(i), stdAcc(i), meanSuc(i), stdSuc(i));
end
fprintf("============================================================\n");

%% ==================== 그래프 ====================
figure;
errorbar(reconDurationList, meanHit, stdHit, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, 'CapSize', 8);
xlabel("Reconnaissance Duration (slots)"); ylabel("Attack Phase Jamming Hit Rate (%)");
title(sprintf("APJ: Jamming Hit Rate vs Recon Duration (Fixed Attack Window=%d)", attackWindow));
xticks(reconDurationList); ylim([0 100]); grid on;

figure;
errorbar(reconDurationList, meanAcc, stdAcc, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, 'CapSize', 8, 'Color', [0.85 0.33 0.10]);
xlabel("Reconnaissance Duration (slots)"); ylabel("Top-1 Prediction Accuracy (%)");
title("APJ: Channel Prediction Accuracy vs Recon Duration");
xticks(reconDurationList); ylim([0 100]); grid on;

figure;
errorbar(reconDurationList, meanSuc, stdSuc, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, 'CapSize', 8, 'Color', [0.47 0.67 0.19]);
xlabel("Reconnaissance Duration (slots)"); ylabel("Target UT Success Rate (%, Attack Phase)");
title("Target UT Success Rate vs Recon Duration");
xticks(reconDurationList); ylim([0 100]); grid on;