classdef (Abstract) Agent < handle
    properties

        %% 초기 선언
        % Owner
        Owner

        NumActions

        TrainingStep % Agent가 지금까지 몇 번 학습 수행했는지


        % State (DQN Input)
        CurrentState % O_t+1(phi × K)

        % Pending Transition
        PendingState  %O_t
        PendingAction %a_t
        PendingReward %r_t


        %% APJ / UT에 따른 각각 선언
        BatchSize

        % Learning parameters
        LearningRate %학습 가중치
        DiscountFactor %미래 보상 정책

        % Epsilon-greedy
        Epsilon
        EpsilonMin
        EpsilonDecay

        % DQN
        QNetwork
        TargetNetwork

        TargetUpdateFrequency %Target QNet 업데이트 주기

        RewardFunction


        % Replay Memory
        ReplayBuffer

    end

    methods
        % ========== 생성자 ========== %
        function obj = Agent(owner)
            obj.Owner = owner;

            % State
            obj.CurrentState = [];
        
            % Pending Transition
            obj.PendingState = [];
            obj.PendingAction = [];
            obj.PendingReward = [];
        
            % Training
            obj.TrainingStep = 0;

        end


        % ========== 상태 등록 ========== %
        function setCurrentState(obj, state)
            obj.CurrentState = state;
        end


        % ========== 보상 등록 ========== %
        function setReward(obj, outcome)

            if isempty(obj.RewardFunction)
                error("Agent:RewardFunctionNotSet", "RewardFunction이 등록되지 않았습니다.");
            end
            obj.PendingReward = obj.RewardFunction(outcome);
        end


        % ========== Transition 완성 및 Replay Buffer 저장 ========== %
        function completeTransition(obj)
            
            % 첫 번째 TimeSlot 예외처리
            if isempty(obj.PendingState) || isempty(obj.PendingAction) || isempty(obj.PendingReward) || isempty(obj.CurrentState)
                return;
            end

            % Replay Buffer 에러잡기
            if isempty(obj.ReplayBuffer)
                error("Agent:ReplayBufferNotSet", "ReplayBuffer가 설정되지 않았습니다.");
            end

            % Transition 저장 (O_t, a_t, r_t, O_{t+1}) 저장
            obj.ReplayBuffer.add(obj.PendingState, obj.PendingAction, obj.PendingReward, obj.CurrentState);

            % 저장 완료된 Pending Transition 초기화
            obj.PendingState = [];
            obj.PendingAction = [];
            obj.PendingReward = [];

        end

    end
end