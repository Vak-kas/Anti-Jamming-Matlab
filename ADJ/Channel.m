classdef Channel < handle
    properties
        Id %채널 번호
        Type %ChannelType

        Packets %Packet Array
    end

    methods
        % ========== 생성자 ========== %
        function obj = Channel(id, type)
            obj.Id = id;
            obj.Type = type;
            obj.Packets = Packet.empty;
        end

        % ========== 채널 초기화 ========== %
        function clearPacket(obj)
            obj.Packets = Packet.empty;
        end

        % ========== 채널 패킷 가져오기 ========== %
        function packets = getPackets(obj)
            packets = obj.Packets;
        end
            


        % ========== 패킷 추가 ========== %
        function addPacket(obj, packet)
            obj.Packets(end+1) = packet;
        end



    end
    

end