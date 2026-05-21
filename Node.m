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

            obj.currentChannel = {};
            obj.txBuffer = {};
            obj.rxBuffer = {};
        end


        %========== 채널 선택 ==========
        function ch = selectChannel(obj, slot, channels)
            N = length(channels);
            channelId = obj.FHP(slot, N);
            obj.currentChannel = channels{channelId};
            ch = obj.currentChannel;
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
        function pkt = sendPacket(obj, channel, power)
            pkt = obj.popTxPacket();
            if isempty(pkt)
                return;
            end

            sig = Signal(SignalType.COMM, pkt, power, obj.id, channel.id);
            channel.addSignal(sig);
        end


        %========== 패킷 수신(ACK/NACK return) ==========
        %채널 수신한 후에 응답
        function pkt = receivePacket(obj)
            pkt = [];
            signals = obj.currentChannel.getSignals();

            if isempty(signals)
                return;
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%임시 시그널 처리 --> 2개 이상이면 간섭 발생했다라는 가정%%%%%%
            sig = signals{1};
            pkt = sig.packet;


            % 신호가 2개 이상인 경우
            if length(signals) > 1
                nackPkt = Packet(PacketType.NACK, obj.id, pkt.srcId, "NACK");
                obj.txBuffer{end+1} = nackPkt;


            % 신호가 1개인 경우(충돌 없음) 
            else
                if pkt.dstId == obj.id
                    obj.rxBuffer{end+1} = pkt;
    
                    if pkt.type == PacketType.DATA
                        ackPkt = Packet(PacketType.ACK, obj.id, pkt.srcId, "ACK");
                        obj.txBuffer{end+1} = ackPkt;
                    end
                end
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        end

    end

end