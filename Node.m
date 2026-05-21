classdef Node < handle

    properties
        id
        currentChannel
        FHP

        txBuffer;
        rxBuffer;

    end

    methods

       %========== 노드 초기화 ==========
        function obj = Node(id, FHP)
            obj.id = id;
            obj.FHP = FHP;

            obj.currentChannel = -1;
            obj.txBuffer = {};
            obj.rxBuffer = {};
        end


        %========== 채널 선택 ==========
        function ch = selectChannel(obj, slot, N)
            ch = obj.FHP(slot, N);
            obj.currentChannel = ch;
        end

        %========== 데이터 패킷 생성 ==========
        function createDataPacket(obj, dstId, payload)
            pkt = Packet(PacketType.DATA, obj.id, dstId, payload);
            obj.txBuffer{end+1} = pkt;
        end

        %========== 송신 버퍼에서 패킷 꺼내기 ==========
        function pkt = popTxPacket(obj)
            if isempty(obj.txBuffer)
                pkt = [];
                return;
            end

            pkt = obj.txBuffer{1};
            obj.txBuffer(1) = [];
        end

        %========== 패킷 송신 ==========
        function sendPacket(obj, channel, power)
            pkt = obj.popTxPacket();
            if isempty(pkt)
                return;
            end

            sig = Signal(pkt, power);
            channel.addSignal(sig);
        end


        %========== 패킷 수신(ACK/NACK return) ==========
        %채널 수신한 후에 응답
        function receivePack(obj, pkt, txChannel)
            if isempty(pkt)
                return;
            end

            %패킷 수신 정상적
            if obj.currentChannel == txChannel && obj.id == pkt.dstId
                obj.rxBuffer{end+1} = pkt; %수신한 패킷 저장

                if pkt.type == PacketType.DATA
                    ackPkt = Packet(PacketType.ACK, obj.id, pkt.srcId, "ACK");
                    obj.txBuffer{end+1} = ackPkt;
                end
                
            %패킷 수신 X
            else
                if pkt.type == PacketType.DATA
                    nackPkt = Packet(PacketType.NACK, obj.id, pkt.srcId, "NACK");
                    obj.txBuffer{end+1} = nackPkt;
                end
            end
        end


    end

end