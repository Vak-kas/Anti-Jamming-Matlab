classdef Signal
    properties
        type
        packet
        txPower

        txNodeId
        txRole

        txChannelId
        txPosition
    end

    methods
        function obj = Signal(type, packet, txPower, txNodeId, txRole, txChannelId, txPosition)

            obj.type = type;
            obj.packet = packet;
            obj.txPower = txPower;

            obj.txNodeId = txNodeId;
            obj.txRole = txRole;

            obj.txChannelId = txChannelId;
            obj.txPosition = txPosition;
        end
    end
end