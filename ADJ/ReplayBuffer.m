classdef ReplayBuffer < handle
    properties
        Capacity

        States
        Actions
        Rewards
        NextStates

        Count % 현재 몇 개 저장되어 있는가(저장된 데이터 개수)
        Position % 다음에 저장할 배열 인덱스(쓰기 포인터)
    end

    methods
        % ========== 생성자 ========== %
        function obj = ReplayBuffer(capacity, stateSize)
            obj.Capacity = capacity;
            obj.Count = 0;
            obj.Position = 1;

            obj.States = zeros(stateSize(1), stateSize(2), stateSize(3), capacity, "single");
            obj.Actions = zeros(capacity,1);
            obj.Rewards = zeros(capacity,1);
            obj.NextStates = zeros(stateSize(1), stateSize(2), stateSize(3), capacity, "single");
        end

        % ========== Transition 저장 ==========
        function add(obj, state, action, reward, nextState)
            numRows = size(obj.States, 1);
            numCols = size(obj.States, 2);
            numFeatures = size(obj.States, 3);
            expectedStateSize = [numRows numCols numFeatures];

            % 사이즈 에러 체크
            if ~isequal(size(state), expectedStateSize)
                error("ReplayBuffer:InvalidStateSize", "state 크기는 [%d %d %d]여야 합니다.", expectedStateSize(1), expectedStateSize(2), expectedStateSize(3));
            end
            if ~isequal(size(nextState), expectedStateSize)
                error("ReplayBuffer:InvalidNextStateSize", "nextState 크기는 [%d %d %d]여야 합니다.", expectedStateSize(1), expectedStateSize(2), expectedStateSize(3));
            end

            obj.States(:, :, :, obj.Position) = single(state);
            obj.Actions(obj.Position) = action;
            obj.Rewards(obj.Position) = reward;
            obj.NextStates(:, :, :, obj.Position) = single(nextState);

            obj.Count = min(obj.Count+1, obj.Capacity);
            obj.Position = mod(obj.Position, obj.Capacity) + 1;
        end


        % ========== Mini-Batch 무작위 추출 ==========
        function batch = sample(obj, batchSize)

            % 저장된 Transition이 BatchSize보다 적으면 학습 불가능
            if obj.Count < batchSize
                batch = [];
                return;
            end

            indices = randperm(obj.Count, batchSize); %전체 중 batchSize개수 만큼 뽑기

            % S_t
            sampledStates = obj.States(:, :, :, indices);

            % a_t
            sampledActions = obj.Actions(indices);

            % r_t
            sampledRewards = obj.Rewards(indices);

            % S_{t+1}
            sampledNextStates = obj.NextStates(:, :, :, indices);

            

            batch = struct('States', sampledStates, 'Actions', sampledActions,'Rewards', sampledRewards, 'NextStates', sampledNextStates);

            
            % ============= 최종 리턴 사이즈 =================
            % batch.States      : phi × K × 3 × BatchSize
            % batch.Actions     : BatchSize × 1
            % batch.Rewards     : BatchSize × 1
            % batch.NextStates  : phi × K × 3 × BatchSize

            % batch.Indices     : 1 × BatchSize
            % ============================================%


        end
    end

end