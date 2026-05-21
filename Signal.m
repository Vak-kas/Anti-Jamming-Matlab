classdef Signal
    properties
        packet
        txPower

        txNodeId
        txChannelId
    end

    methods
        %========== Signal 생성자 ==========
        function obj = Signal(packet, txPower, txNodeId, txChannelId)
            obj.packet = packet;
            obj.txPower = txPower;
            obj.txNodeId = txNodeId;
            obj.txChannelId = txChannelId;
        end
    end

end