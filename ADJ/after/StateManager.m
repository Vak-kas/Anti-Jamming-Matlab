classdef StateManager < handle
    properties
        NumUpdates = 0

        NumChannels  % k
        HistoryLength % HistoryLength % Waterfall 길이(phi)
        Mode % Mode % O / OA / OAH


        CurrentObservation %o_t (1*k)

        ObservationHistory %(phi * k)
        ActionHistory %(phi * k)
        HarqHistory % (phi * k)

    end


    methods
        % ========== 생성자 ==========
        function obj = StateManager(numChannels, historyLength, mode)
            obj.NumChannels = numChannels;
            obj.HistoryLength = historyLength;
            obj.Mode = mode;

            obj.CurrentObservation = zeros(1, obj.NumChannels);
            obj.ObservationHistory = zeros(obj.HistoryLength, obj.NumChannels);
            obj.ActionHistory = zeros(obj.HistoryLength, obj.NumChannels);
            obj.HarqHistory = zeros(obj.HistoryLength, obj.NumChannels);
        end

        % ========== 한 Slot의 O / A / H 업데이트 ==========
        function update(obj, observation, selectedChannel, packetType)
            obj.updateObservation(observation);
            obj.updateAction(selectedChannel);
            obj.updateHARQ(selectedChannel, packetType);

            obj.NumUpdates = obj.NumUpdates + 1;

        end


        % ========== Observation History 업데이트 ==========
        function updateObservation(obj, observation)
            observation = reshape(observation, 1, []);

            if numel(observation) ~= obj.NumChannels
                error("StateManager:InvalidObservationSize", "Observation size must be 1 x %d.", obj.NumChannels);
            end

            obj.ObservationHistory = [
                observation
                obj.ObservationHistory(1:end-1, :)
            ];

        end

        % ========== Action History 업데이트 ==========
        function updateAction(obj, selectedChannel)
            if selectedChannel < 1 || selectedChannel > obj.NumChannels
                error("StateManager:InvalidChannel", "Selected channel must be between 1 and %d.", obj.NumChannels);
            end

            actionVector = zeros(1, obj.NumChannels);
            actionVector(selectedChannel) = 1;

            obj.ActionHistory = [
                actionVector
                obj.ActionHistory(1:end-1, :)
            ];

        end

        % ========== HARQ History 업데이트 ==========
        function updateHARQ(obj, selectedChannel, packetType)
            harqVector = zeros(1, obj.NumChannels);

            if packetType == PacketType.ACK
                harqVector(selectedChannel) = 1;
            elseif packetType == PacketType.NACK
                harqVector(selectedChannel) = -1;
            else
                error("StateManager:InvalidHARQ", "Packet type must be ACK or NACK.");
            end

            obj.HarqHistory = [
                harqVector
                obj.HarqHistory(1:end-1, :)
            ];

        end

        % ========== Agent 입력 반환 ==========
        function state = getState(obj)
            switch obj.Mode
                case ObservationMode.O
                    state = obj.ObservationHistory;
                case ObservationMode.OA
                    state = cat(3, obj.ObservationHistory, obj.ActionHistory);
                case ObservationMode.OAH
                    state = cat(3, obj.ObservationHistory, obj.ActionHistory, obj.HarqHistory);
                otherwise
                        error("ObservationManager:InvalidMode", "Unknown observation mode: %s", obj.Mode);
            end
        end



        %% ========== History 준비 여부 ==========
        function ready = isReady(obj)
            ready = obj.NumUpdates >= obj.HistoryLength;
        end

        %% ========== State 초기화 ==========
        function reset(obj)
            obj.NumUpdates = 0;
            obj.ObservationHistory(:) = 0;
            obj.ActionHistory(:) = 0;
            obj.HarqHistory(:) = 0;
        end


    end

end