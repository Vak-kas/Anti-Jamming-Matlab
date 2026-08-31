%% ==================== final3.m ====================
%  Attack Method Comparison (RQ1: APJ가 기존 jammer보다 강한가?)
%  Random vs Sweep(Comb) vs APJ (Shadow DQN), 동일 Top-2 budget, env 기본 Recon(=1500) 사용
%  ※ 이 코드베이스에서 Sweep과 Comb은 동일 구현체(TimeSlotS, "Sweep(Comb) Jammer")임
%  ※ Existing Literature Benchmark는 구현체 없어 이번 비교에서 제외 (필요시 추가)

clc; clear; clear variables; clear DebugHelper; close all;

techniqueNames = ["Random", "Sweep/Comb", "APJ (Shadow DQN)"];
numTrials = 3;

hitRateResults = nan(numel(techniqueNames), numTrials);
successResults = nan(numel(techniqueNames), numTrials);
sinrResults    = nan(numel(techniqueNames), numTrials);

for trial = 1:numTrials
    fprintf("\n############################################################\n");
    fprintf(" Trial %d / %d\n", trial, numTrials);
    fprintf("############################################################\n");

    [hitRateResults(1,trial), successResults(1,trial), sinrResults(1,trial)] = runRandom(trial);
    [hitRateResults(2,trial), successResults(2,trial), sinrResults(2,trial)] = runSweep(trial);
    [hitRateResults(3,trial), successResults(3,trial), sinrResults(3,trial)] = runShadowDQN(trial);
end

meanHit = mean(hitRateResults, 2, 'omitnan'); stdHit = std(hitRateResults, 0, 2, 'omitnan');
meanSuc = mean(successResults, 2, 'omitnan'); stdSuc = std(successResults, 0, 2, 'omitnan');
meanSinr = mean(sinrResults, 2, 'omitnan');   stdSinr = std(sinrResults, 0, 2, 'omitnan');

fprintf("\n============================================================\n");
fprintf(" Attack Method Comparison — 최종 결과\n");
fprintf("============================================================\n");
for i = 1:numel(techniqueNames)
    fprintf("%-18s : JHR %.2f%%(±%.2f) | Success %.2f%%(±%.2f) | SINR %.3fdB(±%.3f)\n", ...
        techniqueNames(i), meanHit(i), stdHit(i), meanSuc(i), stdSuc(i), meanSinr(i), stdSinr(i));
end
fprintf("============================================================\n");

figure;
bar(categorical(techniqueNames, techniqueNames), meanHit);
hold on; errorbar(1:numel(techniqueNames), meanHit, stdHit, 'k', 'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 10); hold off;
ylabel("Attack Phase Jamming Hit Rate (%)");
title("Fig 1-a: Attack Method vs Jamming Hit Rate (Top-2 Budget)");
ylim([0 100]); grid on;

figure;
bar(categorical(techniqueNames, techniqueNames), meanSuc);
hold on; errorbar(1:numel(techniqueNames), meanSuc, stdSuc, 'k', 'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 10); hold off;
ylabel("Target UT Success Rate (%, Attack Phase)");
title("Fig 1-b: Attack Method vs Target Success Rate");
ylim([0 100]); grid on;

figure;
bar(categorical(techniqueNames, techniqueNames), meanSinr);
hold on; errorbar(1:numel(techniqueNames), meanSinr, stdSinr, 'k', 'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 10); hold off;
ylabel("Average SINR (dB, Attack Phase)");
title("Fig 1-c: Attack Method vs Average SINR");
grid on;


%% ==================== Local Functions ====================

function [hitRate, successRate, sinrDb] = runRandom(trial)
    rng(trial);
    env;
    [ServiceChannels, ControlChannels] = buildChannels();
    [SatelliteNode, Beams, UTs, targetBeamIndex] = buildNetwork();

    apj = APJFactory.createAPJ(UTs, Beams, targetUTId, targetJammerDistance);

    topKJam = 2;
    timeSlotR = TimeSlotR(topKJam);
    rLog = struct('slot', {}, 'observedChannel', {}, 'jammingChannels', {}, 'isAttackPhase', {});

    for slotIndex = 1:numTimeSlots
        rLog = timeSlotR.run(slotIndex, UTs, SatelliteNode, apj, ServiceChannels, ControlChannels, targetBeamIndex, rLog);
    end

    hitRate = computeAttackHitRate(rLog);
    [successRate, sinrDb] = computeAttackUTMetrics();
    fprintf("  [Random]     JHR=%.2f%% | Success=%.2f%% | SINR=%.3fdB\n", hitRate, successRate, sinrDb);
end

function [hitRate, successRate, sinrDb] = runSweep(trial)
    rng(trial);
    env;
    [ServiceChannels, ControlChannels] = buildChannels();
    [SatelliteNode, Beams, UTs, targetBeamIndex] = buildNetwork();

    apj = APJFactory.createAPJ(UTs, Beams, targetUTId, targetJammerDistance);

    dwellSlots = 1;
    timeSlotS = TimeSlotS(numChannels, dwellSlots);
    sweepLog = struct('slot', {}, 'observedChannel', {}, 'jammingChannels', {}, 'isAttackPhase', {});

    for slotIndex = 1:numTimeSlots
        sweepLog = timeSlotS.run(slotIndex, UTs, SatelliteNode, apj, ServiceChannels, ControlChannels, targetBeamIndex, sweepLog);
    end

    hitRate = computeAttackHitRate(sweepLog);
    [successRate, sinrDb] = computeAttackUTMetrics();
    fprintf("  [Sweep/Comb] JHR=%.2f%% | Success=%.2f%% | SINR=%.3fdB\n", hitRate, successRate, sinrDb);
end

function [hitRate, successRate, sinrDb] = runShadowDQN(trial)
    rng(trial);
    env;
    [ServiceChannels, ControlChannels] = buildChannels();
    [SatelliteNode, Beams, UTs, targetBeamIndex] = buildNetwork();

    apjd = APJDFactory.createAPJD(UTs, Beams, targetUTId, targetJammerDistance);

    timeSlotDE = TimeSlotDE(2);
    divergenceLog = struct('slot', {}, 'lossA', {}, 'lossB', {}, 'qCosSim', {}, 'argmaxMatch', {}, ...
        'weightDiffNorm', {}, 'weightNormA', {}, 'weightNormB', {}, 'qA', {}, 'qB', {}, 'qL2Dist', {}, ...
        'observedChannel', {}, 'actualACK', {}, 'estimatedOutcome', {}, 'isAttackPhase', {}, 'jammingChannels', {});
    channelLog = struct('slot', {}, 'channel', {}, 'epsilon', {}, 'method', {}, 'qValues', {});

    for slotIndex = 1:numTimeSlots
        [divergenceLog, channelLog] = timeSlotDE.run(slotIndex, UTs, SatelliteNode, apjd, ServiceChannels, ControlChannels, targetBeamIndex, divergenceLog, channelLog);
    end

    hitRate = computeAttackHitRate(divergenceLog);
    [successRate, sinrDb] = computeAttackUTMetrics();
    fprintf("  [APJ/ShadowDQN] JHR=%.2f%% | Success=%.2f%% | SINR=%.3fdB\n", hitRate, successRate, sinrDb);
end

function hitRate = computeAttackHitRate(logStruct)
    if isempty(logStruct)
        hitRate = NaN; return;
    end
    isAttackPhaseLog = [logStruct.isAttackPhase];
    observedChannels = [logStruct.observedChannel];
    attackIdx = find(isAttackPhaseLog);

    hitCount = 0; totalCount = 0;
    for idx = attackIdx
        jc = logStruct(idx).jammingChannels;
        if isempty(jc), continue; end
        totalCount = totalCount + 1;
        if any(observedChannels(idx) == jc)
            hitCount = hitCount + 1;
        end
    end
    if totalCount > 0
        hitRate = hitCount / totalCount * 100;
    else
        hitRate = NaN;
    end
end

function [successRate, sinrDb] = computeAttackUTMetrics()
    evalUTData = DebugHelper.TargetUTStorage('get', []);
    successRate = NaN; sinrDb = NaN;
    if ~isempty(evalUTData.slots)
        evalUTAttackIdx = logical(evalUTData.isAttackPhase);
        if any(evalUTAttackIdx)
            successRate = mean(evalUTData.isACK(evalUTAttackIdx)) * 100;
            sinrDb = mean(evalUTData.SINR_dB(evalUTAttackIdx), 'omitnan');
        end
    end
end

function [ServiceChannels, ControlChannels] = buildChannels()
    env;
    ServiceChannels = Channel.empty(0, numChannels);
    ControlChannels = Channel.empty(0, numChannels);
    for channelIndex = 1:numChannels
        centerFreq_Hz = serviceBandStart_Hz + (channelIndex - 0.5) * channelSpacing_Hz;
        serviceChannelStart_Hz = centerFreq_Hz - channelBandwidth_Hz / 2;
        serviceChannelEnd_Hz = centerFreq_Hz + channelBandwidth_Hz / 2;
        ServiceChannels(channelIndex) = Channel(channelIndex, ChannelType.Service, serviceChannelStart_Hz, serviceChannelEnd_Hz);
        ControlChannels(channelIndex) = Channel(channelIndex, ChannelType.Control, 1, 2);
    end
end

function [SatelliteNode, Beams, UTs, targetBeamIndex] = buildNetwork()
    env;
    satellitePosition = [0 0 satelliteAltitude];
    SatelliteNode = Satellite(9999, satellitePosition, numBeams);

    Beams = BeamFactory.createBeams(numBeams, maxBeamFootprintDiameter, beamRadius, beamSpacing, beamMaxGain_dBi, beam3dBWidth_deg, beamEIRPDensity_dBW_per_MHz, channelBandwidth_Hz);
    for beamIndex = 1:numBeams
        SatelliteNode.addBeam(Beams(beamIndex));
    end

    UTs = UTFactory.createUTs(Beams, numUTs);

    targetBeamIndex = find([Beams.AssociatedUTId] == targetUTId, 1);
    if isempty(targetBeamIndex)
        error("final3:TargetBeamNotFound", "targetUTId 에 연결된 Beam을 찾을 수 없습니다.");
    end
end