clc;
clear;
clear variables;
clear DebugHelper;
close all;
%% ==================== Environment Settings ====================
env;
%% ==================== 채널 생성 ====================
ServiceChannels = Channel.empty(0, numChannels);
ControlChannels = Channel.empty(0, numChannels);
for k = 1:numChannels
    centerFreq_Hz = serviceBandStart_Hz + (k-0.5) * channelSpacing_Hz;
    serviceChannelStart_Hz = centerFreq_Hz - channelBandwidth_Hz/2;
    serviceChannelEnd_Hz   = centerFreq_Hz + channelBandwidth_Hz/2;
    ServiceChannels(k) = Channel(k, ChannelType.Service, serviceChannelStart_Hz, serviceChannelEnd_Hz);
    ControlChannels(k) = Channel(k, ChannelType.Control, 1, 2);
end
%% ==================== Satellite 생성 ====================
satellitePosition = [0 0 satelliteAltitude];
SatelliteNode = Satellite(9999, satellitePosition, numBeams);
%%  ==================== Beam 생성 ====================
Beams = BeamFactory.createBeams(numBeams, maxBeamFootprintDiameter, beamRadius, beamSpacing, beamMaxGain_dBi, beam3dBWidth_deg, beamEIRPDensity_dBW_per_MHz, channelBandwidth_Hz);
for beamIndex = 1:numBeams
    SatelliteNode.addBeam(Beams(beamIndex));
end
%%  ==================== UT 생성 ====================
UTs = UTFactory.createUTs(Beams, numUTs);
%% ===================== APJ 생성 (재밍은 안 걸지만 UT.performHARQ 인터페이스 유지를 위해 생성) =====================
APJNode = APJFactory.createAPJ(UTs, Beams, targetUTId, targetJammerDistance);

%% ===================== A/B 비교용 Target Beam / Agent 생성 =====================
targetBeamIndex = find([Beams.AssociatedUTId] == targetUTId, 1);
if isempty(targetBeamIndex)
    error("mainD:TargetBeamNotFound", "targetUTId %d 에 연결된 Beam을 찾을 수 없습니다.", targetUTId);
end
targetBeam = Beams(targetBeamIndex);

AgentA = BeamAgent(targetBeam);
AgentB = BeamAgent(targetBeam);

%% ==================== Time Slot 루프 ====================
timeSlotD = TimeSlotD();
divergenceLog = struct('slot', {}, 'lossA', {}, 'lossB', {}, 'qCosSim', {}, 'argmaxMatch', {}, 'weightDiffNorm', {}, 'weightNormA', {}, 'weightNormB', {}, 'qA', {}, 'qB', {}, 'qL2Dist', {});
channelLog = struct('slot', {}, 'channel', {}, 'epsilon', {}, 'method', {}, 'qValues', {});

for slotIndex = 1:numTimeSlots
    [divergenceLog, channelLog] = timeSlotD.run(slotIndex, UTs, SatelliteNode, APJNode, ServiceChannels, ControlChannels, AgentA, AgentB, targetBeamIndex, divergenceLog, channelLog);
end

%% ==================== 결과 요약 / 그래프 (A vs B 발산 확인) ====================
slots = [divergenceLog.slot];
lossA = [divergenceLog.lossA];
lossB = [divergenceLog.lossB];
qCosSim = [divergenceLog.qCosSim];
argmaxMatch = [divergenceLog.argmaxMatch];
weightDiffNorm = [divergenceLog.weightDiffNorm];

figure;

subplot(2,2,1);
plot(slots, lossA, slots, lossB);
legend("Agent A Loss", "Agent B Loss");
title("A/B Loss 비교"); xlabel("Time Slot"); ylabel("Loss");

subplot(2,2,2);
plot(slots, qCosSim);
title("Q-vector Cosine Similarity (A vs B)"); xlabel("Time Slot"); ylabel("Cosine Similarity");
ylim([0 1.05]);

subplot(2,2,3);
windowSize = 100;
plot(slots, movmean(argmaxMatch, windowSize));
title(sprintf("Argmax Agreement (이동평균 %d)", windowSize)); xlabel("Time Slot"); ylabel("Agreement Rate");
ylim([0 1.05]);

subplot(2,2,4);
plot(slots, weightDiffNorm);
title("Weight Diff L2 Norm (A vs B)"); xlabel("Time Slot"); ylabel("Norm");

validIdx = max(1, numel(slots) - 99):numel(slots);
fprintf("\n=== A/B DQN 재현성 테스트 요약 ===\n");
fprintf("최근 100슬롯 평균 Argmax Agreement: %.2f%%\n", mean(argmaxMatch(validIdx)) * 100);
fprintf("최근 100슬롯 평균 Q Cosine Similarity: %.4f\n", mean(qCosSim(validIdx)));
fprintf("최종 Weight Diff Norm: %.4f\n", weightDiffNorm(end));

%% ==================== Target Beam 채널 선택 Collapse 진단 ====================
chSlots = [channelLog.slot];
chSelected = [channelLog.channel];
chEpsilon = [channelLog.epsilon];

numCh = numel(ServiceChannels);
windowSize2 = 100;

% 이동창 안에서 "최빈 채널이 차지하는 비율" (collapse 정도를 나타내는 지표)
modeShare = zeros(size(chSlots));
for i = 1:numel(chSlots)
    startIdx = max(1, i - windowSize2 + 1);
    windowChannels = chSelected(startIdx:i);
    counts = histcounts(windowChannels, 0.5:1:(numCh + 0.5));
    modeShare(i) = max(counts) / numel(windowChannels);
end

figure;

subplot(3,1,1);
scatter(chSlots, chSelected, 5, 'filled');
title("Target Beam 선택 채널 (슬롯별)"); xlabel("Time Slot"); ylabel("Channel");
ylim([0 numCh + 1]);

subplot(3,1,2);
plot(chSlots, chEpsilon);
title("Epsilon 값 변화"); xlabel("Time Slot"); ylabel("Epsilon");

subplot(3,1,3);
plot(chSlots, modeShare);
title(sprintf("이동창(%d) 내 최빈 채널 점유율 (Collapse 지표)", windowSize2));
xlabel("Time Slot"); ylabel("Mode Share"); ylim([0 1.05]);

fprintf("\n=== Target Beam 채널 Collapse 진단 요약 ===\n");
[finalCounts, ~] = histcounts(chSelected, 0.5:1:(numCh + 0.5));
[maxCount, maxCh] = max(finalCounts);
fprintf("전체 %d슬롯 중 채널 %d이 %d회 선택됨 (%.1f%%)\n", numel(chSlots), maxCh, maxCount, maxCount / numel(chSlots) * 100);
fprintf("마지막 Epsilon 값: %.4f\n", chEpsilon(end));
firstCollapseIdx = find(modeShare >= 0.9, 1);
if ~isempty(firstCollapseIdx)
    fprintf("최빈 채널 점유율이 90%%를 처음 넘은 슬롯: %d\n", chSlots(firstCollapseIdx));
else
    fprintf("최빈 채널 점유율이 90%%를 넘은 적 없음\n");
end

%% ==================== A/B Q-value 절대값 비교 ====================
qA_matrix = vertcat(divergenceLog.qA); % numEntries x numChannels
qB_matrix = vertcat(divergenceLog.qB);
qAbsDiff = abs(qA_matrix - qB_matrix);

figure;

subplot(2,1,1);
plot(slots, mean(qAbsDiff, 2));
title("A/B Q-value 평균 절대 차이 (전체 채널 평균)"); xlabel("Time Slot"); ylabel("mean(|Q_A - Q_B|)");

subplot(2,1,2);
[~, finalGreedyChannel] = max(qA_matrix(end, :));
plot(slots, qA_matrix(:, finalGreedyChannel), slots, qB_matrix(:, finalGreedyChannel));
legend(sprintf("Agent A (CH%d)", finalGreedyChannel), sprintf("Agent B (CH%d)", finalGreedyChannel));
title(sprintf("최종 Greedy 채널(CH%d) Q-value: A vs B", finalGreedyChannel));
xlabel("Time Slot"); ylabel("Q-value");

fprintf("\n=== 최종 슬롯 채널별 |Q_A - Q_B| ===\n");
for ch = 1:numCh
    fprintf("  CH%2d: A=%.4f  B=%.4f  diff=%.4f\n", ch, qA_matrix(end, ch), qB_matrix(end, ch), qAbsDiff(end, ch));
end
fprintf("전체 채널 평균 절대 차이 (마지막 슬롯): %.4f\n", mean(qAbsDiff(end, :)));

%% ==================== A/B 발산 크기 종합 ====================
weightNormA = [divergenceLog.weightNormA];
weightNormB = [divergenceLog.weightNormB];
relativeWeightDiff = weightDiffNorm ./ ((weightNormA + weightNormB) / 2 + eps);  % 네트워크 자체 크기 대비 상대 차이

qL2Dist = [divergenceLog.qL2Dist];
lossDiff = abs(lossA - lossB);

figure;

subplot(2,2,1);
plot(slots, qL2Dist);
title("Q-vector L2 거리 ||Q_A - Q_B||"); xlabel("Time Slot"); ylabel("L2 Distance");

subplot(2,2,2);
plot(slots, lossDiff);
title("|Loss_A - Loss_B|"); xlabel("Time Slot"); ylabel("Loss 차이");

subplot(2,2,3);
plot(slots, weightDiffNorm, slots, weightNormA, slots, weightNormB);
legend("||W_A - W_B||", "||W_A||", "||W_B||", "Location", "best");
title("Weight Norm 비교"); xlabel("Time Slot"); ylabel("Norm");

subplot(2,2,4);
plot(slots, relativeWeightDiff * 100);
title("상대적 Weight 차이 (%)"); xlabel("Time Slot"); ylabel("||W_A-W_B|| / 평균(||W_A||,||W_B||) x100");

%% ==================== 채널별 Q-value 절대 차이 히트맵 ====================
figure;
imagesc(slots, 1:numCh, qAbsDiff');
set(gca, 'YDir', 'normal');
colorbar;
xlabel("Time Slot"); ylabel("Channel");
title("채널별 |Q_A - Q_B| 히트맵");

fprintf("\n=== 발산 크기 요약 ===\n");
fprintf("최종 Q-vector L2 거리: %.4f\n", qL2Dist(end));
fprintf("최종 Weight Norm: ||W_A||=%.4f, ||W_B||=%.4f, ||W_A-W_B||=%.4f\n", weightNormA(end), weightNormB(end), weightDiffNorm(end));
fprintf("최종 상대적 Weight 차이: %.2f%%\n", relativeWeightDiff(end) * 100);
fprintf("최근 100슬롯 평균 |Loss_A - Loss_B|: %.4f\n", mean(lossDiff(validIdx), "omitnan"));