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

    end

    methods
        % ========== Agent 생성자 ==========
        function obj = HybridDQNAgent(id, K, phi, experiencePoolCapacity, gamma, eta, epsilon)
            obj.id = id;
            obj.K = K;
            obj.phi = phi;

            obj.experiencePoolCapacity = experiencePoolCapacity;
            obj.gamma = gamma;
            obj.eta = eta;
            obj.epsilon = epsilon;


            obj.historyBuffer = zeros(phi, K);
            obj.replayBuffer = {};

            obj.net_u = obj.createQNetwork(); %Q-Network 생성 예정
            obj.net_j = obj.createQNetwork();%Q-Network 생성 예정
        end



        % ========== Q Network 생성 ==========
        function net = createQNetwork(obj)
            layers = [
                % Input Layer : phi * K * 1 채널
                imageInputLayer([obj.phi obj.K, 1], Normalization="none", Name="spectrum_waterfall_input")

                % Convolution Layer : Kernal g: 10*4 *16, Stride : 2
                convolution2dLayer([10 4], 16, Stride=2, Padding="same", Name="Convolution")
                reluLayer(Name="relu_conv")


                % fully connected 1(128)
                fullyConnectedLayer(128, Name="fc1")
                reluLayer(Name="relu_fc1")

                %fully connected 2(|A|) : set of channels F.
                fullyConnectedLayer(obj.K, Name="fc2") 

            ]

            lgraph = layerGraph(layers);
            net = dlnetwork(lgraph);


        end
    end

end