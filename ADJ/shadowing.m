clc;
clear;
clear variables;
close all;



%% ==================== Environment Settings ====================
env;



%% ==================== Node 생성 ====================
% UT 생성
UTs = UT.empty(0, numUTs);
for n = 1:numUTs
    x = rand() * groundWidth;
    y = rand() * groundHeight;
    z = 0;

    utPosition = [x, y, z];

    isTarget = (n== targetUTId);

    UTs(n) = UT(n, utPosition, utTxPower_dBm, isTarget, K, phi);
end

% Satellite 생성
Satellites = Satellite.empty(0, numSatellites);
for n = 1:numSatellites
    pos = UTs(n).getPosition();

    x = pos(1);
    y = pos(2);
    z = satelliteAltitude;

    satellitePosition = [x, y, z];
    associatedUTId = UTs(n).Id;

    Satellites(n) = Satellite(n, satellitePosition, satelliteTxPower_dBm, associatedUTId, sinrThreshold_dB, satelliteRxGain_dBi, satelliteGOverT_dB);
end
% DebugHelper.printSatelliteInfo(Satellites(1));


% APJ 생성
targetPosition = UTs(targetUTId).getPosition();

theta = 2 * pi * rand(); %랜덤 방향 설정

x = targetPosition(1) + targetJammerDistance * cos(theta);
y = targetPosition(2) + targetJammerDistance * sin(theta);
z = 0;

apjPosition = [x, y, z];
APJ = APJ(1001, apjPosition, apjTxPower_dBm, targetUTId, APJsinrThreshold_db, K, phi);


% 좌표 표시
ax = FigureHelper.plotUTDeployment(UTs, groundWidth, groundHeight);
FigureHelper.plotAPJ(ax, APJ);



% DebugHelper.printAssociationDistances(UTs, Satellites);



%% ==================== 채널 생성 ====================
ServiceChannels = Channel.empty(0, K);
ControlChannels = Channel.empty(0, K);

for k = 1:K
    centerFreq_Hz = serviceBandStart_Hz + (k-0.5) * channelSpacing_Hz;

    serviceChannelStart_Hz = centerFreq_Hz - channelBandwidth_Hz/2;
    serviceChannelEnd_Hz   = centerFreq_Hz + channelBandwidth_Hz/2;
    
    ServiceChannels(k) = Channel(k, ChannelType.Service, serviceChannelStart_Hz, serviceChannelEnd_Hz);
    ControlChannels(k) = Channel(k, ChannelType.Control, 1, 2);
end

% DebugHelper.printChannels(ServiceChannels, ControlChannels);


%% ==================== Time Slot 마다 수행 ====================

actualChannels = nan(1, numTimeSlots);
utGreedyChannels = nan(1, numTimeSlots);
apjPredictedChannels = nan(1, numTimeSlots);
actualPredictionCorrect = nan(1, numTimeSlots);
greedyAgreementCorrect = nan(1, numTimeSlots);
timeSlot = TimeSlot();
targetACKHistory = zeros(1, numTimeSlots);

TP = 0;
FN = 0;
FP = 0;
TN = 0;

for slotIndex = 1:numTimeSlots

    [result, actualTargetACK, shadowResult] = timeSlot.run(slotIndex, UTs, Satellites, APJ, ServiceChannels, ControlChannels);

    % APJ HARQ 예측 결과 누적
    switch result
        case 0
            TP = TP + 1;

        case 1
            FN = FN + 1;

        case 2
            FP = FP + 1;

        case 3
            TN = TN + 1;

        otherwise
            error( ...
                "Main:UnknownResult", ...
                "알 수 없는 result 값입니다: %d", ...
                result);
    end

    % Shadowing 결과 저장

    if ~isempty(shadowResult.ActualChannel)

        actualChannels(slotIndex) = shadowResult.ActualChannel;

        utGreedyChannels(slotIndex) = shadowResult.UTGreedyChannel;

        apjPredictedChannels(slotIndex) = shadowResult.APJPredictedChannel;

        actualPredictionCorrect(slotIndex) = double(shadowResult.ActualPredictionCorrect);

        greedyAgreementCorrect(slotIndex) = double(shadowResult.GreedyAgreementCorrect);

    end

    % Target UT의 실제 ACK/NACK 결과 저장
    targetACKHistory(slotIndex) = actualTargetACK;
end


%% APJ HARQ 예측 결과 출력
DebugHelper.printHARQPredictionResult(TP, FN, FP, TN);


%% 마지막 Transition 완성
if timeSlot.UseAgent
    for utIndex = 1:numel(UTs)

        finalObservation = ...
            UTs(utIndex).ObservationManager.observe( ...
                ServiceChannels, UTs);

        UTs(utIndex).Agent.setCurrentState(finalObservation);
        UTs(utIndex).Agent.completeTransition();

        % 마지막 Transition을 포함하여 한 번 더 학습
        UTs(utIndex).Agent.train();
    end
end

finalAPJObservation = APJ.ObservationManager.observe(ServiceChannels, UTs);
APJ.Agent.setCurrentState(finalAPJObservation);
APJ.Agent.completeTransition();

% 마지막 Transition을 포함하여 한 번 더 학습
APJ.Agent.train();


%% ==================== APJ Shadowing Analysis ====================

validSlots = ~isnan(actualPredictionCorrect);

actualCorrect = actualPredictionCorrect(validSlots);

greedyCorrect = greedyAgreementCorrect(validSlots);

%% 1. Cumulative Accuracy

cumulativeActualAccuracy = cumsum(actualCorrect) ./ (1:numel(actualCorrect));

cumulativeGreedyAccuracy = cumsum(greedyCorrect) ./ (1:numel(greedyCorrect));

%% 2. Moving Accuracy

windowSize = 100;

movingActualAccuracy = movmean(actualCorrect, [windowSize-1 0]);

movingGreedyAccuracy = movmean(greedyCorrect, [windowSize-1 0]);

%% 3. 최종 Accuracy

finalActualAccuracy = mean(actualCorrect);

finalGreedyAccuracy = mean(greedyCorrect);

fprintf("\n");

fprintf("------------------------------------------------------------\n");

fprintf("APJ Shadowing Performance\n");

fprintf("------------------------------------------------------------\n");

fprintf("  Actual Action Prediction Accuracy : %.2f %%\n", finalActualAccuracy * 100);

fprintf("  Greedy Policy Agreement           : %.2f %%\n", finalGreedyAccuracy * 100);

fprintf("------------------------------------------------------------\n");