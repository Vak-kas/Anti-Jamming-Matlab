classdef HybridDQNAgent < handle
    properties
        id
        K %Number of Channel
        phi % Count of History
        

        historyBuffer % Observation(센싱 결과) 묶음
        replayBuffer  % <O_t, a_t, r_u, r_j, O_t+1> 저장
        experiencePoolCapacity %ReplayBuffer 최대 저장 용량


        net_u %Q_u (Frequecy Reuse 신경망)
        net_j %Q_j (Anti-Jamming 신경망)

        
        gamma           % 할인율 (Discount factor, 논문 스펙 = 0.8) 미래를 얼마나 중요하게 볼 것인가
        eta             % 복합 Q-value 가중치 (Anti-jamming 가중치) Q = ηQ_j + (1−η)Q_u
        epsilon         % 탐색 확률 (Exploration rate)


        batchSize       % 배치사이즈
        learnRate       %학습률
    end

    properties(Access=private)
        iteration_u
        iteration_j

        avgGrad_u
        avgSqGrad_u

        avgGrad_j
        avgSqGrad_j
    end

    methods
        % ========== Agent 생성자 ==========
        function obj = HybridDQNAgent(id, K, phi, experiencePoolCapacity, gamma, eta, epsilon, batchSize, learnRate)
            obj.id = id;
            obj.K = K;
            obj.phi = phi;

            obj.experiencePoolCapacity = experiencePoolCapacity;
            obj.gamma = gamma;
            obj.eta = eta;
            obj.epsilon = epsilon;
            obj.batchSize = batchSize;
            obj.learnRate = learnRate;


            obj.historyBuffer = zeros(phi, K);
            obj.replayBuffer = {};
            
            % obj.net_u = obj.createQNetwork();
            % obj.net_j = obj.createQNetwork();
            % obj.net_j.Learnables = obj.net_u.Learnables;

            obj.net_u = obj.createQNetwork();
            obj.net_j = obj.createQNetwork();

            obj.net_j.Learnables = obj.net_u.Learnables;

            

            % 반복 횟수
            obj.iteration_u = 0;
            obj.iteration_j = 0;

            % 최근 gradient 평균
            obj.avgGrad_u = [];
            obj.avgGrad_j = [];

            % 최근 gradient^2 평균
            obj.avgSqGrad_u = [];
            obj.avgSqGrad_j = [];
        end



        % ========== Q Network 생성 ==========
        function net = createQNetwork(obj)
            layers = [
                % Input Layer : phi * K * 1 채널
                imageInputLayer([obj.phi obj.K 1], Normalization="none", Name="spectrum_waterfall_input")

                % Convolution Layer : Kernal g: 10*4 *16, Stride : 2
                convolution2dLayer([10 4], 16, Stride=2, Padding="same", Name="Convolution")
                reluLayer(Name="relu_conv")


                % fully connected 1(128)
                fullyConnectedLayer(128, Name="fc1")
                reluLayer(Name="relu_fc1")

                %fully connected 2(|A|) : set of channels F.
                fullyConnectedLayer(obj.K, Name="fc2") 

            ];

            lgraph = layerGraph(layers);
            net = dlnetwork(lgraph);


        end


        % ========== 센싱 결과 업데이트 (history Buffer update) ==========
        function updateObservation(obj, o_t) %o_t : 1 * K 벡터
            
            if size(o_t, 1) ~= 1
                o_t = o_t(:).';
            end

            if length(o_t) ~= obj.K
                error("Observation size mismatch. Expected 1 x %d", obj.K);
            end

            % 오래된 행 제거, 새 센싱 결과를 마지막 행에 추가
            obj.historyBuffer(2:end, :) = obj.historyBuffer(1:end-1, :);
           obj.historyBuffer(1, :)  = o_t;
        end


        % ========== 현재 Spectrum Waterfall O_t 반환 ==========
        function O_t = getObservation(obj)
            O_t = obj.historyBuffer;
        end


        % ========== 현재 O_t로 Q_u, Q_j, Composite Q 계산 ==========
        function [q_u, q_j, compositeQ] = predictQ(obj)
            O_t = obj.getObservation();
        
            X = reshape(single(O_t), [obj.phi obj.K 1 1]);
            X = dlarray(X, "SSCB");
        
            q_u = extractdata(predict(obj.net_u, X));
            q_j = extractdata(predict(obj.net_j, X));
        
            q_u = q_u(:).';
            q_j = q_j(:).';
        
            compositeQ = obj.eta * q_j + (1 - obj.eta) * q_u;
        end

        % ========== 채널 선택 ==========
        function action = selectAction(obj)

            if rand < obj.epsilon
                action = randi(obj.K);
                return;
            end
            [~, ~, compositeQ] = obj.predictQ();
            % [~, action] = max(compositeQ);
        
            maxQ = max(compositeQ);
            candidates = find(compositeQ == maxQ);
            action = candidates(randi(length(candidates)));
        
        end

        % ========== Experience 저장 ==========
        function storeExperience(obj, O_t, action, r_u, r_j, O_next)
            exp = Experience(O_t, action, r_u, r_j, O_next);
        

            currentSize = length(obj.replayBuffer);

            if currentSize < obj.experiencePoolCapacity
                obj.replayBuffer{end+1} = exp;
            else
                obj.replayBuffer(1:end-1) = obj.replayBuffer(2:end);
                obj.replayBuffer{end} = exp;
            end
        
        end


        %========== Train ==========
        function train(obj)
            % batchSize만큼 쌓기
            if length(obj.replayBuffer) < obj.batchSize
                return;
            end

            % Replay Buffer에서 무작위로 BatchSize만큼 인덱스 샘플링
            numExperiences = length(obj.replayBuffer);
            sampledIndices = randperm(numExperiences, obj.batchSize);

            % [phi, K, 1, batchSize] 크기의 4차원 텐서 준비
            O_t_batch    = zeros(obj.phi, obj.K, 1, obj.batchSize, 'single');
            a_t_batch    = zeros(obj.batchSize, 1);
            r_u_batch    = zeros(obj.batchSize, 1, 'single');
            r_j_batch    = zeros(obj.batchSize, 1, 'single');
            O_next_batch = zeros(obj.phi, obj.K, 1, obj.batchSize, 'single');


            for i = 1:obj.batchSize
                expObj = obj.replayBuffer{sampledIndices(i)};
                O_t_batch(:, :, 1, i)    = expObj.O_t;
                a_t_batch(i)             = expObj.action;
                r_u_batch(i)             = expObj.r_u;
                r_j_batch(i)             = expObj.r_j;
                O_next_batch(:, :, 1, i) = expObj.O_next;
            end

            % dlnetwork 전송을 위한 dlarray 데이터 포맷 래핑
            dl_O_t    = dlarray(O_t_batch, 'SSCB');
            dl_O_next = dlarray(O_next_batch, 'SSCB');

            
            % 주파수 재사용(net_u) 학습
            obj.iteration_u = obj.iteration_u +1;
            [loss_u, gradients_u] = dlfeval(@obj.computeLoss, obj.net_u, dl_O_t, a_t_batch, r_u_batch, dl_O_next);
            [obj.net_u, obj.avgGrad_u, obj.avgSqGrad_u] = adamupdate(obj.net_u, gradients_u,obj.avgGrad_u, obj.avgSqGrad_u, obj.iteration_u, obj.learnRate);


            % 항재밍망(net_j) 학습
            obj.iteration_j = obj.iteration_j + 1;
            [loss_j, gradients_j] = dlfeval(@obj.computeLoss, obj.net_j, dl_O_t, a_t_batch, r_j_batch, dl_O_next);
            [obj.net_j, obj.avgGrad_j, obj.avgSqGrad_j] = adamupdate(obj.net_j, gradients_j, obj.avgGrad_j, obj.avgSqGrad_j, obj.iteration_j, obj.learnRate);

        end


    
        %========== 벨만 방정식 기반 Loss 및 Gradient 계산 ==========
        function [loss, gradients] = computeLoss(obj, net, dl_O_t, a_t_batch, r_batch, dl_O_next)
        
            % 현재 Q-value: [K x batchSize]
            q_current = forward(net, dl_O_t);
            q_current = reshape(q_current, obj.K, []);
        
            % 다음 Q-value: [K x batchSize]
            q_next = predict(net, dl_O_next);
            q_next = extractdata(q_next);
            q_next = reshape(q_next, obj.K, []);
        
            % max_a Q(O_next, a)
            max_q_next = max(q_next, [], 1);  % 1 x batchSize
        
            % 논문 Eq.(4): TargetQ = r + gamma * max Q(O_next, a)
            r_batch = single(r_batch(:).');   % 1 x batchSize
            target_q = r_batch + obj.gamma * single(max_q_next);
            target_q = dlarray(target_q);     % 1 x batchSize
        
            % 실제 선택했던 action의 Q만 추출
            batchN = size(q_current, 2);
            a_t_batch = double(a_t_batch(:).');  % 1 x batchSize
        
            actionIdx = sub2ind([obj.K, batchN], a_t_batch, 1:batchN);
            q_predicted = q_current(actionIdx);  % 1 x batchSize
        
            % MSE Loss
            loss = mean((q_predicted - target_q).^2, "all");
        
            gradients = dlgradient(loss, net.Learnables);
        end

    end

end