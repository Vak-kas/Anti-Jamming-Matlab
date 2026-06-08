clc;
clear;
MHz = 1e6;
GHz = 1e9;

%% 초기 환경 변수(Parameters)
N = 20; %Number of Users
J = 2; %Number of Jammers
K = 10; % Number of Channel
T = 1; % Time Slot
area = [2500, 2500, 0]; %전체 범위
pairDistance = 50; %Tx, Rx 쌍 거리, 처리 안 할 거면 []

BW_ch = 50 * MHz; %channel bandwidth = 50 MHz
f_start = 26.5 * GHz; %26.5GHz
f_end = 29.5 * GHz; %29.5GHz
interferenceRange = 700;


%% Time Parameters

Tc_ms = 10;       % communication time slot
Tj_ms = 7;        % jamming duration



%% 핵심 파라미터
power = 50;
jammerPower = 1000;

pathLossExponent = 2;

noisePower_dBm = -80;
thermalNoise = 10^(noisePower_dBm / 10);  % mW

betaThreshold_dB = 10;
betaThreshold = 10^(betaThreshold_dB / 10);


%% DQN Parameters
Phi_ms = 100;     % spectrum sensing history time
D = 5000;      % Experience pool capacity 
gamma = 0.8;   % Discount factor
eta = 0.8;     % Swept jamming 최적 가중치, 0.2면 comb jamming
epsilon = 0;

batchSize = 128;
learnRate = 0.001;

%% initialize
phi = Phi_ms / Tc_ms;   % history 개수 = 100ms / 10ms = 10


channels = createChannels(K, BW_ch, f_start); %채널 생성
channelModel = ChannelModel(pathLossExponent);
[txNodes, rxNodes] = createNodes(N, area, power, @randomFHP, pairDistance, Tc_ms);% tx, rx노드 생성

combChannels = randperm(K, 3);
% jammer = Jammer(1001, @(slot, K) sweptJammerFHP, [1250, 1250, 0], jammerPower);
jammer = Jammer(1001, @sweptJammerFHP, [500, 500, 0], jammerPower,"swept", Tc_ms, Tj_ms);
% jammer = Jammer(1001, @combJammerFHP, [2000, 2000, 0], jammerPower,"comb", Tc_ms, Tj_ms);
% jammer2 = Jammer(1002, @(slot, K) combJammerFHP(slot, K, combChannels), [2000, 2000, 0], jammerPower, Tc_ms, Tj_ms);
clearChannel(channels);

NCT = zeros(1, T);


%% 위치 출력

figure(101);
hold on;
grid on;
box on;

% User 출력
for n = 1:N
    pos = txNodes{n}.position;
    scatter(pos(1), pos(2), 250, 'filled');
    text(pos(1), pos(2), sprintf('%d', n), 'Color','w', 'FontWeight','bold', 'HorizontalAlignment','center');

end

% Jammer 출력
scatter(jammer.position(1), jammer.position(2), 450, 'p', 'filled',  'MarkerFaceColor', [0.9 0.9 0.9], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
text(jammer.position(1)+40, jammer.position(2),'Jammer 1','FontWeight', 'bold');

% scatter(jammer2.position(1), jammer2.position(2), 450, 'p', 'filled', 'MarkerFaceColor', [0.9 0.9 0.9], 'MarkerEdgeColor', 'k','LineWidth', 1.5);
% text(jammer2.position(1)+40, jammer2.position(2), 'Jammer 2', 'FontWeight', 'bold');


% Mutual interference line
for i = 1:N
    pos1 = txNodes{i}.position;
    for j = i+1:N
        pos2 = txNodes{j}.position;
        d = norm(pos1(1:2) - pos2(1:2));
        if d <= interferenceRange
            plot([pos1(1), pos2(1)], [pos1(2), pos2(2)], '--', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2);

        end
    end
end

xlabel('x (m)');
ylabel('y (m)');
title('Location Distribution of Users and Jammers');
xlim([0 area(1)]);
ylim([0 area(2)]);
axis square;
legend({'User', 'Jammer', 'Mutual interference'},'Location', 'eastoutside');


%% Agent 생성
agents = cell(N, 1);
for n = 1:N
    agents{n} = HybridDQNAgent(n, K, phi, D, gamma, eta, epsilon, batchSize, learnRate);
end


%% Simulation Start
for slot = 1:T
    fprintf("==========Slot %d==========\n" , slot);
    clearChannel(channels);
    channelModel.update(txNodes, rxNodes, jammer);
    success = zeros(N, 1);


    %% T_DEC : 현재 O_t 기반 채널 선택
    O_t_list = cell(N, 1);
    actionList = zeros(N, 1);

    %% Tx가 채널 선택
    for n = 1:N
        txNodes{n}.selectChannel(slot, channels);
        % fprintf("Tx %d -> Channel %d\n", txNodes{n}.id, txNodes{n}.currentChannel.id);
    end
    % for n = 1:N
    %     O_t_list{n} = agents{n}.getObservation();
    %     action = agents{n}.selectAction();
    %     actionList(n) = action;
    %     txNodes{n}.setChannelById(action, channels);
    % end

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
    jammer.selectChannel(slot, channels);
    jammer.jam(slot);

    fprintf("Jammer %d -> ", jammer.id);
    for j = 1:length(jammer.currentChannels)
        fprintf("Channel %d ", jammer.currentChannels{j}.id);
    end
    fprintf("\n");


    %% 전체 채널의 Signal 정보 확인
    for channel = 1:K
        % channels{channel}.printSignals();
    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% %%%%%%%%%%%%% 센싱 %%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % o_next_list = cell(N, 1);
    % for n = 1:N
    %     o_next_list{n} = senseSpectrum(txNodes{n},channels, channelModel,thermalNoise);
    % end



    %% Rx가 데이터 수신 및 ACK/NACK 생성
    for n = 1:N
        rxNodes{n}.receivedPacket(channels, betaThreshold, thermalNoise, channelModel);
        % fprintf("Rx %d received packet from Tx %d\n", rxNodes{n}.id, txNodes{n}.id);
    end

    % DATA phase 종료: DATA 신호 제거, JAMMING은 유지
    clearCommSignals(channels);

    %% Rx가 ACK/NACK 송신
    for n = 1:N
        rxNodes{n}.sendPacket();
        % fprintf("Rx %d send packet to Tx %d\n", rxNodes{n}.id, txNodes{n}.id);
    end


    %% Tx가 Ack/Nack 수신
    fprintf("==========\n");
    for n = 1:N
        success(n) = txNodes{n}.receiveAck(betaThreshold, thermalNoise, channelModel);
        if(success(n) == 1)
            fprintf("Tx %d received ACK\n", txNodes{n}.id);
        else
            fprintf("Tx %d received NACK or no ACK\n", txNodes{n}.id);
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Agent 학습용 Experience 저장 및 Train %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % for n = 1:N
    %     agents{n}.updateObservation(o_next_list{n});
    %     O_next = agents{n}.getObservation();
    %     [r_u, r_j] = getReward(success(n));
    %     agents{n}.storeExperience(O_t_list{n}, actionList(n), r_u, r_j, O_next);
    %     agents{n}.train();
    % end




    %% 마무리
    % NCT(slot) = mean(success);
    % fprintf("\n========== Slot %d Summary ==========\n", slot);
    % fprintf("NCT = %.3f\n", NCT(slot));

    % 재밍된 채널 정보 출력
    fprintf("\n[Jammed Channels]\n");

    for j = 1:length(jammer.currentChannels)
        jamCh = jammer.currentChannels{j};
        fprintf("Jammed Channel %d\n", jamCh.id);

        for n = 1:N
            if txNodes{n}.currentChannel.id == jamCh.id
                if success(n) == 1
                    resultText = "ACK";
                else
                    resultText = "NACK or No ACK";
                end

                fprintf("  Tx %d -> Rx %d | Result: %s\n", ...
                    txNodes{n}.id, rxNodes{n}.id, resultText);
            end
        end
    end

    % 실패한 노드 전체 정보 출력
    fprintf("\n[Failed Users]\n");

    failedCount = 0;

    for n = 1:N
        if success(n) == 0
            failedCount = failedCount + 1;

            fprintf("  Tx %d -> Rx %d | Channel %d\n", ...
                txNodes{n}.id, ...
                rxNodes{n}.id, ...
                txNodes{n}.currentChannel.id);
        end
    end

    if failedCount == 0
        fprintf("  None\n");
    end

    fprintf("=====================================\n");

end

figure;

% plot(1:T, NCT, 'LineWidth',2);
% xlabel('Time Slot');
% ylabel('NCT');
% grid on;




%% Strategy
function ch = fixedFHP(slot, N)
    ch  = 1;
end

function ch = randomFHP(slot, N)
    ch = randi(N);
end


function ch = sweptJammerFHP(slot, K, Tc_ms, Tj_ms)

    slotStartAbs_ms = (slot - 1) * Tc_ms;
    slotEndAbs_ms   = slot * Tc_ms;

    ch = [];
    abs_t = slotStartAbs_ms;

    while abs_t < slotEndAbs_ms
        jamIndex = floor(abs_t / Tj_ms);
        channelId = mod(jamIndex, K) + 1;

        ch(end+1) = channelId;

        nextSwitchAbs_ms = (jamIndex + 1) * Tj_ms;
        abs_t = min(slotEndAbs_ms, nextSwitchAbs_ms);
    end

    ch = unique(ch, 'stable');
end


function ch = combJammerFHP(slot, K, combChannels)
    ch = combChannels;
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

% 정상 신호 제거
function clearCommSignals(channels)
    for i = 1:length(channels)
        channels{i}.removeCommSignals();
    end
end

% Node 생성
function [txNodes, rxNodes] = createNodes(N, area, power, FHP, pairDistance, Tc_ms)
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

        txNodes{i} = Node(i, NodeType.Tx, txPosition, power, FHP, Tc_ms);
        rxNodes{i} = Node(i, NodeType.Rx, rxPosition, power, [], Tc_ms);
    end
end


function [r_u, r_j] = getReward(success)

    if success
        r_u = 5;
        r_j = 1;
    else
        r_u = -1;
        r_j = -10;
    end

end

function o_t = senseSpectrum(rxNode, channels, channelModel, thermalNoise)

    K = length(channels);
    o_t = zeros(1, K);

    for k = 1:K
        channel = channels{k};
        signals = channel.getSignals();

        totalPower = thermalNoise;

        for i = 1:length(signals)
            sig = signals{i};

            gain = channelModel.getGain( ...
                sig.txRole, ...
                sig.txNodeId, ...
                rxNode.role, ...
                rxNode.id);

            totalPower = totalPower + sig.txPower * gain;
        end

        o_t(k) = 10 * log10(totalPower);
    end
end