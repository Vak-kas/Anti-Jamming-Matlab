clc;
clear;
global masterSeed;
rng('shuffle')
masterSeed = randi(10000);
MHz = 1e6;
GHz = 1e9;

%% 초기 환경 변수
N = 60; %채널 개수
BW_ch = 50 * MHz; %channel bandwidth = 50 MHz
f_start = 26.5 * GHz; %26.5GHz
f_end = 29.5 * GHz; %29.5GHz

T = 10; %timeSlot

power = 10;



%% 실험 환경 구성
% 채널 생성
channels = cell(1, N);
for i = 1:N
    centerFreq = f_start + (i-1) * BW_ch;
    channels{i} = Channel(i, centerFreq, BW_ch);
end


%Transmitter & Receiver 생성
tx = Node(1, @sharedRandomFHP);
rx = Node(2, @sharedRandomFHP);


%% 시뮬레이션
for slot = 1:T
    fprintf("\n========== SLOT %d ==========\n", slot);
    
    %% TX 데이터 준비
    % Tx DATA 생성
    payload = sprintf("DATA_SLOT_%d", slot);
    tx.createDataPacket(rx.id, payload);


    %% 채널 선택
    txChannel = tx.selectChannel(slot, channels);
    rxChannel = rx.selectChannel(slot, channels);
    fprintf("TX Channel: %d | RX Channel: %d\n", txChannel.id, rxChannel.id);



    %% 재머


    %% 채널을 통해서 데이터 송신
    tx.sendPacket(txChannel, power);


    %% RX 데이터 수신
    if txChannel.id == rxChannel.id
        rx.receivePacket();


        %ACK/NACK Phase
        txChannel.reset();
        feedback = rx.sendPacket(rxChannel, power);

        if ~isempty(feedback)
            fprintf("RX -> TX Feedback: %s\n", string(feedback.type));
        else
            fprintf("RX -> TX Feedback: NONE\n");
        end
        
       
    else
        fprintf("-> [실패] 송수신 채널 불일치 (동기 이탈)\n");
    end


end










%% function
function ch = fixedFHP(slot, N)
    ch  = 1;
end

function ch = sharedRandomFHP(slot, N)
    global masterSeed;
    rng(masterSeed + slot) %각 노드의 채널 선택 같게 해줌
    ch = randi(N);
end

