classdef Jammer < Node
    properties
        currentChannels
    end

    methods
        %========== 생성자 ==========
        function obj = Jammer(id, FHP, position, txPower)
            if nargin < 3 || isempty(position)
                position = [0, 0, 0];
            end
            if nargin < 4 || isempty(txPower)
                txPower = 1;
            end

            obj@Node(id, NodeType.Jammer, position, txPower, FHP);
            obj.currentChannels = {};
        end

        %========== Jammer 채널 선택 방식(다수 선택 가능) ==========
        function ch = selectChannel(obj, slot, channels)
            K = length(channels);
            channelIds = obj.FHP(slot, K);

            if isempty(channelIds)
                obj.currentChannels = {};
                ch = obj.currentChannels;
                return;
            end

            if iscell(channelIds)
                channelIds = cell2mat(channelIds);
            end

            channelIds = channelIds(:).';
            channelIds = unique(channelIds, 'stable');
            channelIds = channelIds(channelIds >= 1 & channelIds <= K);

            obj.currentChannels = cell(1, length(channelIds));

            for i = 1:length(channelIds)
                channelId = channelIds(i);
                obj.currentChannels{i} = channels{channelId};
            end

            ch = obj.currentChannels;
        end


        %========== 재밍 공격 ==========
        function jam(obj, power)
            if nargin < 2 || isempty(power)
                power = obj.txPower;
            end

            for i = 1:length(obj.currentChannels)
                channel = obj.currentChannels{i};
                sig = Signal(SignalType.JAMMING, [], power, obj.id, channel.id, obj.position);
                channel.addSignal(sig);
            end
        end
    end
end