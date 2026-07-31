clc;
clear;
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
timeSlot = TimeSlot();

TP = 0;
FN = 0;
FP = 0;
TN = 0;

for i = 1:numTimeSlots
    result = timeSlot.run(i, UTs, Satellites, APJ, ServiceChannels, ControlChannels);

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
            error("알 수 없는 result 값입니다: %d", result);
    end
end


% APJ HARQ 예측 결과 출력

DebugHelper.printHARQPredictionResult(TP, FN, FP, TN);