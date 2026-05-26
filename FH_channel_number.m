clc;
clear;

global masterSeed;
rng('shuffle');
masterSeed = randi(10000);

MHz = 1e6;
GHz = 1e9;

%% 초기 환경 변수
N_list = 1:30;

BW_ch = 50 * MHz;
f_start = 26.5 * GHz;

T = 10000;

power = 10;
jammerPower = 10;

%% 시뮬레이션

error_random_random = runSimulation( ...
    N_list, T, power, jammerPower, ...
    @sharedRandomFHP, @randomFHP, ...
    BW_ch, f_start);

error_fixed_random = runSimulation( ...
    N_list, T, power, jammerPower, ...
    @fixedFHP, @randomFHP, ...
    BW_ch, f_start);

error_random_fixed = runSimulation( ...
    N_list, T, power, jammerPower, ...
    @sharedRandomFHP, @fixedFHP, ...
    BW_ch, f_start);

%% 그래프

figure;

semilogy(N_list, error_random_random, '-bo', 'LineWidth', 1.5);
hold on;

semilogy(N_list, error_fixed_random, '-rs', 'LineWidth', 1.5);

semilogy(N_list, error_random_fixed, '-g^', 'LineWidth', 1.5);

grid on;

xlabel('Number of Channels (N)');
ylabel('Error Rate');
title('Error Rate vs Number of Channels');

legend( ...
    'sharedRandomFHP / randomFHP', ...
    'fixedFHP / randomFHP', ...
    'sharedRandomFHP / fixedFHP', ...
    'Location', 'southwest');

%% =========================
%% Functions
%% =========================

function errorRate = runSimulation( ...
    N_list, T, power, jammerPower, ...
    txFHP, jammerFHP, ...
    BW_ch, f_start)

    errorRate = zeros(1, length(N_list));

    for idx = 1:length(N_list)

        N = N_list(idx);

        %% 채널 생성
        channels = cell(1, N);

        for i = 1:N
            centerFreq = f_start + (i-1) * BW_ch;
            channels{i} = Channel(i, centerFreq, BW_ch);
        end

        %% 노드 생성
        tx = Node(1, txFHP);
        rx = Node(2, txFHP);

        jammer = Jammer(999, jammerFHP);

        ackCount = 0;
        nackCount = 0;

        %% 슬롯 반복
        for slot = 1:T

            payload = sprintf("DATA_SLOT_%d", slot);
            tx.createDataPacket(rx.id, payload);

            %% 채널 선택
            txChannel = tx.selectChannel(slot, channels);
            rxChannel = rx.selectChannel(slot, channels);
            jammer.selectChannel(slot, channels);

            %% 데이터 송신
            tx.sendPacket(power);

            %% 재밍
            jammer.jam(jammerPower);

            %% RX 수신
            if txChannel.id == rxChannel.id
                rx.receivePacket();

                %% ACK/NACK phase
                txChannel.reset();
                rx.sendPacket(power);
            end

            feedbackPkt = tx.receivePacket();
            rxChannel.reset();

            if ~isempty(feedbackPkt)
                if feedbackPkt.type == PacketType.ACK
                    ackCount = ackCount + 1;
                else
                    nackCount = nackCount + 1;
                end
            end

            clearChannel(channels, N);

        end

        errorRate(idx) = nackCount / T;

    end

end

function ch = fixedFHP(~, ~)
    ch = 1;
end

function ch = sharedRandomFHP(slot, N)
    global masterSeed;
    rng(masterSeed + slot);
    ch = randi(N);
end

function ch = randomFHP(~, N)
    ch = randi(N);
end

function clearChannel(channels, N)
    for i = 1:N
        channels{i}.reset();
    end
end