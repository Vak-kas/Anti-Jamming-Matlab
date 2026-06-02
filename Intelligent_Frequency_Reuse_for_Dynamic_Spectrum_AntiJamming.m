clc;
clear;
MHz = 1e6;
GHz = 1e9;

%% 초기 환경 변수(Parameters)
N = 20; %Number of Users
K = 10; % Number of Channel
T = 1; % Time Slot
area = [2500, 2500, 0]; %전체 범위
pairDistance = 50; %Tx, Rx 쌍 거리, 처리 안 할 거면 []
power = 10;
jammerPower = 10000;

BW_ch = 50 * MHz; %channel bandwidth = 50 MHz
f_start = 26.5 * GHz; %26.5GHz
f_end = 29.5 * GHz; %29.5GHz


%% initialize
channels = createChannels(K, BW_ch, f_start); %채널 생성
[txNodes, rxNodes] = createNodes(N, area, power, @randomFHP, pairDistance);% tx, rx노드 생성
jammer = Jammer(1001, @combJammerFHP, [1250, 1250, 0], jammerPower);
clearChannel(channels);


%% Simulation Start
for slot = 1:T
    fprintf("==========Slot %d==========\n" , slot);
    clearChannel(channels);

    %% TDEC (TODO)

    %% Tx가 채널 선택
    for n = 1:N
        txNodes{n}.selectChannel(K, channels);
        fprintf("Tx %d -> Channel %d\n", txNodes{n}.id, txNodes{n}.currentChannel.id);
    end

    %% Tx가 보낼 Data 생성
    for n = 1:N
        payload = sprintf("DATA_SLOT_%d", slot);
        txNodes{n}.createDataPacket(n, payload);
    end

    %% Tx가 Data 송신
    for n = 1:N
        txNodes{n}.sendPacket();
    end

    %% Jammer Signal 추가


    %% 전체 채널의 Signal 정보 확인
    for channel = 1:K
        channels{channel}.printSignals();
    end

    %% Rx가 데이터 수신 및 ACK/NACK 전송
    for n = 1:N
        rxNodes{n}.receivedPacket(channels, 0, 0, 0); %TODO : mu, NoisePower, Th 설정
        % fprintf("Rx %d received packet from Tx %d\n", rxNodes{n}.id, txNodes{n}.id);
    end


    %% Tx가 Ack/Nack 수신
    for n = 1:N
    
        if ~isempty(rxNodes{n}.txBuffer)
            pkt = rxNodes{n}.txBuffer{1};
            fprintf("RX %d -> %s\n", rxNodes{n}.id, string(pkt.type));
        end
    end

    %% 마무리

end




%% Strategy
function ch = fixedFHP(slot, N)
    ch  = 1;
end

function ch = randomFHP(slot, N)
    ch = randi(N);
end

function ch = sweptJammerFHP(slot, K)
    ch = mod(slot-1, K) + 1;
end

function ch = combJammerFHP(slot, K)
    ch = [2, 5, 8];
end


%% function
% 채널 생성
function channels = createChannels(N, BW_ch, f_start)
    channels = cell(1, N);
    for i = 1:N
        centerFreq = f_start + (i-1) * BW_ch;
        channels{i} = Channel(i, centerFreq, BW_ch);
    end
end

% 채널 초기화
function clearChannel(channels)
    for i = 1:length(channels)
        channels{i}.reset();
    end
end

% Node 생성
function [txNodes, rxNodes] = createNodes(N, area, power, FHP, pairDistance)
    txNodes = cell(N, 1);
    rxNodes = cell(N, 1);

    for i = 1:N
        txPosition = [rand()*area(1), rand()*area(2), rand()*area(3)];

        if ~isempty(pairDistance)
            rxPosition = txPosition + [randn()*pairDistance, randn()*pairDistance, 0];
            rxPosition = max(min(rxPosition, area), [0 0 0]);
        else
            rxPosition = [rand()*area(1), rand()*area(2), rand()*area(3)];
        end

        txNodes{i} = Node(i, NodeType.Tx, txPosition, power, FHP);
        rxNodes{i} = Node(i, NodeType.Rx, rxPosition, power, []);
    end
end