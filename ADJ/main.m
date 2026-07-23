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

    UTs(n) = UT(n, utPosition, utTxPower_dBm, isTarget);
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

    Satellites(n) = Satellite(n, satellitePosition, satelliteTxPower_dBm, associatedUTId, sinrThreshold_dB);
end


% APJ 생성
targetPosition = UTs(targetUTId).getPosition();

theta = 2 * pi * rand(); %랜덤 방향 설정

x = targetPosition(1) + targetJammerDistance * cos(theta);
y = targetPosition(2) + targetJammerDistance * sin(theta);
z = 0;

apjPosition = [x, y, z];
APJ = APJ(1001, apjPosition, apjTxPower_dBm, targetUTId);


% 좌표 표시
ax = FigureHelper.plotUTDeployment(UTs, groundWidth, groundHeight);
FigureHelper.plotAPJ(ax, APJ);



% DebugHelper.printAssociationDistances(UTs, Satellites);



%% ==================== 채널 생성 ====================
ServiceChannels = Channel.empty(0, K);
ControlChannels = Channel.empty(0, K);

for k = 1:K
    ServiceChannels(k) = Channel(k, ChannelType.Service);
    ControlChannels(k) = Channel(k, ChannelType.Control);
end

% DebugHelper.printChannels(ServiceChannels, ControlChannels);


%% ==================== Time Slot 마다 수행 ====================
timeSlot = TimeSlot();
for i = 1:reconnaissanceDuration
    result = timeSlot.run(i, UTs, Satellites, APJ, ServiceChannels, ControlChannels);
end
