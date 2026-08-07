classdef UT < Node
    properties
        IsTarget = false
        SelectedChannel

        ChannelPattern       % 예: [1 3 5 7]
        PatternIndex         % 현재 패턴 위치

        ObservationManager
        Agent
    end

    methods
        % ========== 생성자 ========== %
        function obj = UT(id, position, txPower_dBm, isTarget, numChannels, phi)
            obj@Node(id, NodeType.UT, position, txPower_dBm);
            obj.IsTarget = isTarget;
            obj.SelectedChannel = 1;

            obj.NoiseFigure_dB = 7;
            
            patternLength = 5;
            obj.ChannelPattern = randperm(numChannels, patternLength);
            obj.PatternIndex = 1;

            obj.ObservationManager = ObservationManager(obj, numChannels, phi);
            obj.Agent = UTAgent(obj);
        end

        % ========== HARQ값 수신 ========== %
        function actualACK = receiveHARQFeedback(obj, ControlChannels)
            packet = obj.findMyPacket(ControlChannels);
            actualACK = (packet.Type == PacketType.ACK);
        end


        % ========== 규칙 기반 채널 선택 ========== %
        function selectedChannel = selectRuleBasedChannel(obj)
            if isempty(obj.ChannelPattern)
                error("UT:ChannelPatternNotSet", "UT %d의 ChannelPattern이 설정되지 않았습니다.", obj.Id);
            end
            selectedChannel = obj.ChannelPattern(obj.PatternIndex);
        
            % 다음 위치로 이동
            obj.PatternIndex = obj.PatternIndex + 1;
        
            % 끝까지 갔으면 다시 처음으로
            if obj.PatternIndex > numel(obj.ChannelPattern)
                obj.PatternIndex = 1;
            end
        
        end
    end
end