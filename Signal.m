classdef Signal
    properties
        type
        packet
        txPower

        txNodeId
        txChannelId
        txPosition
    end

    methods
        %========== Signal 생성자 ==========
        function obj = Signal(type, packet, txPower, txNodeId, txChannelId, txPosition)
            obj.type = type;
            obj.packet = packet;
            obj.txPower = txPower;
            obj.txNodeId = txNodeId;
            obj.txChannelId = txChannelId;
            obj.txPosition = txPosition;
        end
    end

end