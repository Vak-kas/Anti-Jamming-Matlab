%% ==================== final2.m ====================
%  APJ-Target 거리별 성능 저하 Sweep
%  x축: APJ-Target 거리 (km)
%  y축: Attack 구간 Jamming Hit Rate (Top-2, APJ)
%
%  reconnaissanceDuration은 env.m 기본값으로 고정, targetJammerDistance만
%  바꿔서 "물리적 근접성이 공격 성공의 전제조건"임을 검증.

clc; clear; clear variables; clear DebugHelper; close all;

%% ==================== Sweep 설정 ====================
distanceList_km = [1, 5, 10, 20, 50];   % env.m의 targetJammerDistance 단위/스케일에 맞게 조정 필요
numTrials = 3;   % 시드 반복 횟수 (마감 급하면 1로, 여유되면 5로)

hitRateResults = nan(numel(distanceList_km), numTrials);
ackRateResults = nan(numel(distanceList_km), numTrials);   % 보조 지표 (거리 늘어날 때 ACK Rate 회복 확인용)

%% ==================== Sweep 루프 ====================
for distIdx = 1:numel(distanceList_km)
    distance_m = distanceList_km(distIdx) * 1e3;   % km -> m 변환 (env.m 단위 확인 필요)

    for trial = 1:numTrials

        %% ---- 환경 재초기화 (매 trial마다 완전히 새로) ----
        env;   % numChannels, numTimeSlots, targetUTId, reconnaissanceDuration 등 기본값 로드

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
            error("final2:TargetBeamNotFound", "targetUTId %d 에 연결된 Beam을 찾을 수 없습니다.", targetUTId);
        end

        %% ---- APJ 생성 (거리 sweep 값 적용) ----
        apjd = APJDFactory.createAPJD(UTs, Beams, targetUTId, distance_m);

        %% ---- TimeSlotDE 생성 (Recon Duration은 env 기본값 그대로) ----
        timeSlotDE = TimeSlotDE(2);   % Top-2 재밍 고정

        fprintf("\n============================================================\n");
        fprintf(" [Distance Sweep] Distance = %.1f km, Trial %d/%d\n", distanceList_km(distIdx), trial, numTrials);
        fprintf("============================================================\n");

        %% ---- 로그 초기화 ----
        divergenceLog = struct('slot', {}, 'lossA', {}, 'lossB', {}, 'qCosSim', {}, 'argmaxMatch', {}, ...
            'weightDiffNorm', {}, 'weightNormA', {}, 'weightNormB', {}, 'qA', {}, 'qB', {}, 'qL2Dist', {}, ...
            'observedChannel', {}, 'actualACK', {}, 'estimatedOutcome', {}, 'isAttackPhase', {}, 'jammingChannels', {});
        channelLog = struct('slot', {}, 'channel', {}, 'epsilon', {}, 'method', {}, 'qValues', {});

        %% ---- Time Slot 루프 ----
        for slotIndex = 1:numTimeSlots
            [divergenceLog, channelLog] = timeSlotDE.run(slotIndex, UTs, SatelliteNode, apjd, ServiceChannels, ControlChannels, targetBeamIndex, divergenceLog, channelLog);
        end

        %% ---- Attack 구간 Top-2 Jamming Hit Rate + ACK Rate 계산 ----
        if isempty(divergenceLog)
            warning("final2:EmptyLog", "Distance=%.1fkm, Trial=%d: divergenceLog가 비어 있습니다.", distanceList_km(distIdx), trial);
            continue;
        end

        isAttackPhaseLog = [divergenceLog.isAttackPhase];
        observedChannels = [divergenceLog.observedChannel];
        attackIdx = find(isAttackPhaseLog);

        attackHitCount = 0;
        attackTotalCount = 0;
        for idx = attackIdx
            jc = divergenceLog(idx).jammingChannels;
            if isempty(jc)
                continue;
            end
            attackTotalCount = attackTotalCount + 1;
            if any(observedChannels(idx) == jc)
                attackHitCount = attackHitCount + 1;
            end
        end

        if attackTotalCount > 0
            hitRateResults(distIdx, trial) = attackHitCount / attackTotalCount * 100;
        else
            hitRateResults(distIdx, trial) = NaN;
            warning("final2:NoAttackSlots", "Distance=%.1fkm, Trial=%d: Attack 구간 재밍 시도가 없습니다.", distanceList_km(distIdx), trial);
        end

        % 보조 지표: Attack 구간 Target UT ACK Rate (거리 멀어질수록 회복되는지 확인용)
        evalUTData = DebugHelper.TargetUTStorage('get', []);
        if ~isempty(evalUTData.slots)
            evalUTAttackIdx = logical(evalUTData.isAttackPhase);
            if any(evalUTAttackIdx)
                ackRateResults(distIdx, trial) = mean(evalUTData.isACK(evalUTAttackIdx)) * 100;
            end
        end

        fprintf("  -> Attack Jamming Hit Rate (Top-2) : %.2f%% (%d / %d)\n", ...
            hitRateResults(distIdx, trial), attackHitCount, attackTotalCount);
        fprintf("  -> Attack ACK Rate                 : %.2f%%\n", ackRateResults(distIdx, trial));
    end
end

%% ==================== 결과 집계 ====================
meanHitRate = mean(hitRateResults, 2, 'omitnan');
stdHitRate  = std(hitRateResults, 0, 2, 'omitnan');
meanAckRate = mean(ackRateResults, 2, 'omitnan');
stdAckRate  = std(ackRateResults, 0, 2, 'omitnan');

fprintf("\n============================================================\n");
fprintf(" APJ-Target Distance Sweep — 최종 결과\n");
fprintf("============================================================\n");
for distIdx = 1:numel(distanceList_km)
    fprintf("Distance = %5.1f km : Hit Rate 평균 %.2f%% (std %.2f%%) | ACK Rate 평균 %.2f%% (std %.2f%%), n=%d\n", ...
        distanceList_km(distIdx), meanHitRate(distIdx), stdHitRate(distIdx), ...
        meanAckRate(distIdx), stdAckRate(distIdx), numTrials);
end
fprintf("============================================================\n");

%% ==================== 그래프 ====================
figure;

subplot(1,2,1);
errorbar(distanceList_km, meanHitRate, stdHitRate, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, 'CapSize', 8);
xlabel("APJ-Target Distance (km)");
ylabel("Attack Phase Jamming Hit Rate (%)");
title("APJ: Jamming Hit Rate vs Distance");
ylim([0 100]);
grid on;

subplot(1,2,2);
errorbar(distanceList_km, meanAckRate, stdAckRate, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, 'CapSize', 8, 'Color', [0.85 0.33 0.10]);
xlabel("APJ-Target Distance (km)");
ylabel("Target UT ACK Rate (%, Attack Phase)");
title("Target UT Recovery vs Distance");
ylim([0 100]);
grid on;