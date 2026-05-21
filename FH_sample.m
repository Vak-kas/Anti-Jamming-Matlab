clc;
clear;
MHz = 1e6;
GHz = 1e9;

%% 초기 환경 변수
N = 60; %채널 개수
BW_ch = 50 * MHz; %channel bandwidth = 50 MHz
f_start = 26.5 * GHz; %26.5GHz
f_end = 29.5 * GHz; %29.5GHz

T = 10; %timeSlot



%% 실험 환경 구성

% 채널 생성
channels = f_start + (0:N-1) * BW_ch;

%Transmitter & Receiver 생성
tx = Node(1, @sharedRandomFHP);
rx = Node(2, @sharedRandomFHP);


%% 시뮬레이션
for slot = 1:T
    fprintf("\n========== SLOT %d ==========\n", slot);
    
    % Tx DATA 생성
    payload = sprintf("DATA_SLOT_%d", slot);
    tx.createDataPacket(rx.id, payload);

    % Tx 버퍼에서 패킷 꺼내기
    pkt = tx.popTxPacket();


    % 채널 선택
    txChannel = tx.selectChannel(slot, N);
    rxChannel = rx.selectChannel(slot, N);
    fprintf("TX Channel: %d | RX Channel: %d\n", txChannel, rxChannel );


    % 채널을 통해서 데이터 송신

    % RX 수신
    if txChannel == rxChannel
        rx.receivePack(pkt, txChannel);
        
        % RX가 ACK/NACK 생성했는지 확인
        feedbackPkt = rx.popTxPacket();
        if ~isempty(feedbackPkt)
            fprintf("RX -> TX Feedback : %s\n", string(feedbackPkt.type));
            % TX가 ACK/NACK 수신
            tx.receivePack(feedbackPkt, txChannel);
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
    rng(slot) %각 노드의 채널 선택 같게 해줌
    ch = randi(N);
end

