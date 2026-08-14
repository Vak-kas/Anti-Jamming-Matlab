classdef UT < Node
    properties
        IsTarget = false

        TxPower_dBm
        NoiseTemperature
        NoiseFigure_dB

        AssociatedBeamId
        SINRThreshold_dB

    end

    methods
        % ========== 생성자 ========== %
        function obj = UT(id, position)
            env;

            obj@Node(id, NodeType.UT, position);

            obj.IsTarget = targetUTId==id;
    
            obj.RxGain_dBi = utRxGain_dBi;
            
            obj.TxPower_dBm = utTxPower_dBm;
            obj.NoiseTemperature = noiseTemperature;
            obj.NoiseFigure_dB = noiseFigure_dB;

            

            obj.AssociatedBeamId = id;
            obj.SINRThreshold_dB = sinrThreshold_dB;
            

        end

        % ========== 채널에서 자신한테 오는 패킷 찾기 ==========
        function myPacket = findMyPacket(obj, channels)

            myPacket = Packet.empty;

            for channelIndex = 1:numel(channels)
                packets = channels(channelIndex).getPackets();

                for packetIndex = 1:numel(packets)
                    packet = packets(packetIndex);

                    if packet.DestinationType == obj.Type && packet.DestinationId == obj.Id
                        myPacket = packet;
                        return;
                    end

                end
            end
        end

      
    end
end