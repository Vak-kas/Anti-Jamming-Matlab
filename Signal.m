classdef Signal
    properties
        type
        packet
        txPower

        txNodeId
        txChannelId
    end

    methods
        %========== Signal 생성자 ==========
        function obj = Signal(type, packet, txPower, txNodeId, txChannelId)
            obj.type = type;
            obj.packet = packet;
            obj.txPower = txPower;
            obj.txNodeId = txNodeId;
            obj.txChannelId = txChannelId;
        end
    end

end