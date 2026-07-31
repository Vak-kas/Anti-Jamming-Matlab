classdef UT < Node
    properties
        IsTarget = false
        SelectedChannel

        ObservationManager
    end

    methods
        % ========== 생성자 ========== %
        function obj = UT(id, position, txPower_dBm, isTarget, numChannels, phi)
            obj@Node(id, NodeType.UT, position, txPower_dBm);
            obj.IsTarget = isTarget;
            obj.SelectedChannel = 1;

            obj.NoiseFigure_dB = 7;

            obj.ObservationManager = ObservationManager(obj, numChannels, phi);
        end

        % ========== HARQ값 수신 ========== %
        function actualACK = receiveHARQFeedback(obj, ControlChannels)
            packet = obj.findMyPacket(ControlChannels);
            actualACK = (packet.Type == PacketType.ACK);
        end
    end
end