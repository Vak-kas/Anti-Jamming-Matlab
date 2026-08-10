%% ==================== Simulation Parameters ====================
reconnaissanceDuration = 10000;
numTimeSlots = 10000;
useAgent = true;
isDebug = true;

%% ==================== System Parameters ====================
serviceBandStart_Hz = 1980e6;
serviceBandEnd_Hz = 2010e6;

numSatellites = 10; % Number of satellites
numUTs = numSatellites; % Number of UTs
K = 10; % Number of service channels
numAPJ = 1;% Number of APJs


targetUTId = 1;% Target UT ID

%% ==================== Position Parameters ====================
% ground region size
groundWidth = 50e3; %50km
groundHeight = 50e3; %50km

% Satellite Altitude
satelliteAltitude = 600e3; %600km


%Target UT - APJ Distance
targetJammerDistance = 10e3; %10km


%% ==================== Transmission Parameters ====================
%UT 전송 파워
utTxPower_dBm = 23;

% 위성 전송 파워
satelliteTxPower_dBm = 40; %임시 값

% APJ 전송 파워
apjTxPower_dBm = 37;

% SINR Threshold
sinrThreshold_dB = 3;
APJsinrThreshold_db = 14;

satelliteRxGain_dBi = 30;      % Set-1
satelliteGOverT_dB = 1.1;       % Set-1


%% ==================== COMMON DRL Parameters ====================
phi = 10;


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
satelliteTxPower_W = 10^((satelliteTxPower_dBm - 30) / 10); % Convert satellite transmit power from dBm to Watts
apjTxPower_W = 10^((apjTxPower_dBm - 30) / 10); % Convert APJ transmit power from dBm to Watts


totalBandwidth_Hz = serviceBandEnd_Hz - serviceBandStart_Hz;
NumServiceChannels = K;
channelSpacing_Hz = totalBandwidth_Hz / NumServiceChannels;
channelBandwidth_Hz = 360e3;