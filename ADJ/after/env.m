%% ==================== Simulation Parameters ====================
simulationSeed = 1;
reconnaissanceDuration = 1;
numTimeSlots =  10;
useAgent = true;
%% ==================== Channel Parameters ====================
numChannels = 10; % Number of service channels

% serviceBandStart_Hz = 1980e6;
% serviceBandEnd_Hz = 2010e6;
serviceBandStart_Hz = 2170e6;
serviceBandEnd_Hz   = 2200e6;

totalBandwidth_Hz = serviceBandEnd_Hz - serviceBandStart_Hz;
NumServiceChannels = numChannels;
channelSpacing_Hz = totalBandwidth_Hz / NumServiceChannels;
channelBandwidth_Hz = 360e3;


%% ==================== System Parameters ====================
numSatellites = 1; % Number of satellites
numUTs = 19; % Number of UTs
numAPJ = 1;% Number of APJs
targetUTId = 1;% Target UT ID

%% ==================== Satellite Parameters ====================
satelliteAltitude = 600e3; % 위성 고도 600km

satelliteRxGain_dBi = 30;      % Set-1
satelliteGOverT_dB = 1.1;       % Set-1

% Earth / Satellite
earthRadius = 6378e3;
minSatelliteElevation_deg = 10; %각도 (10도)
minSatelliteElevation_rad = deg2rad(minSatelliteElevation_deg); % Minimum elevation angle [rad]
maxGroundCentralAngle_rad = acos(earthRadius / (earthRadius + satelliteAltitude) * cos(minSatelliteElevation_rad)) - minSatelliteElevation_rad;
satelliteCoverageRadius = earthRadius * maxGroundCentralAngle_rad; % 약 1760 km

%% ==================== Beam Parameters ====================
numBeams = numUTs;

beamDiameter = 50e3;
beamRadius = beamDiameter / 2;
beamSpacing = 40e3;


maxBeamFootprintDiameter = 1000e3;  % 3GPP TR 38.821 Table 4.2-2
maxBeamCenterRadius = (maxBeamFootprintDiameter / 2) - beamRadius;  % ≈ 475km

% 3GPP LEO-600 S-band
beamMaxGain_dBi = 30;
beam3dBWidth_deg = 4.4127;

% Satellite EIRP Density
beamEIRPDensity_dBW_per_MHz = 34;


%% ==================== UT Parameters ====================
%UT 전송 파워
utTxPower_dBm = 23;

noiseTemperature = 290;
noiseFigure_dB = 7;
utRxGain_dBi = 0;

sinrThreshold_dB = 13.5; % SINR Threshold



%% ==================== APJ Parameters ====================
targetJammerDistance = 10e3; %10km %Target UT - APJ Distance
apjTxPower_dBm = 37; % APJ 전송 파워

apjRxGain_dBi = 0;
apjNoiseFigure_dB = 7;
apjSINRThreshold_dB = 14;

%% ==================== COMMON DRL Parameters ====================
phi = 10;
observationMode = ObservationMode.O;
%% ==================== UT DRL Parameters ====================
utBatchSize = 32;

utLearnRate = 0.001;
utDiscountFactor = 0.8;

utReplayBufferCapacity = 10000;


% Epsilon-greedy
utEpsilon = 1.000;
utEpsilonMin = 0.05;
utEpsilonDecay = 0.997;

utTargetUpdateFrequency = 100;


utSuccessReward = 5;
utFailureReward = -1;
utRewardFunction = @(isACK) double(isACK) * utSuccessReward + double(~isACK) * utFailureReward;



%% ==================== APJ DRL Parameters ====================
apjBatchSize = 32;

apjLearnRate = 0.001;
apjDiscountFactor = 0.8;

apjReplayBufferCapacity = 10000;

% Epsilon-greedy
apjEpsilon = 1.000;
apjEpsilonMin = 0.05;
apjEpsilonDecay = 0.997;

apjTargetUpdateFrequency = 100;


apjSuccessReward = 5;
apjFailureReward = -1;
apjRewardFunction = @(targetACK) double(targetACK) * apjSuccessReward + double(~targetACK) * apjFailureReward;



%% ==================== 변수 설정 ====================
utTxPower_W = 10^((utTxPower_dBm - 30) / 10); % Convert transmit power from dBm to Watts
% satelliteTxPower_W = 10^((satelliteTxPower_dBm - 30) / 10); % Convert satellite transmit power from dBm to Watts
apjTxPower_W = 10^((apjTxPower_dBm - 30) / 10); % Convert APJ transmit power from dBm to Watts

% ===== Satellite coverage geometry =====
% rng(simulationSeed);