classdef Node < handle

    properties
        id

        role %Tx, Rx, Jammer
        position %[x, y, z]
        txPower % mW

        currentChannel
        FHP

        txBuffer;
        rxBuffer;

    end

    methods
        % Node (id, role, position, txPower, FHP) : 생성자, id는 노드 식별자, role은 노드 역할, position은 위치, txPower는 송신 전력, FHP는 채널 선택 함수 핸들
        % selectChannel(slot, channels) : 채널 선택, slot은 시간 슬롯 번호, channels는 사용 가능한 채널 목록
        % createDataPacket(dstId, payload) : 데이터 패킷 생성, dstId는 목적지 노드 ID, payload는 데이터 내용
        % popTxPacket() : 송신 버퍼에서 패킷 꺼내기, 송신 버퍼에서 가장 오래된 패킷을 반환하고 버퍼에서 제거
        % sendPacket() : 패킷 송신, 송신 버퍼에서 패킷을 꺼내 현재 채널로 송신
        % receivePacket(channels, betaThreshold, mu, noisePower) : 패킷 수신 후 ACK/NACK 변환

        %========== 노드 초기화 ==========
        function obj = Node(id, role, position, txPower, FHP)
            obj.id = id;

            obj.role = role;
            obj.position = position;
            obj.txPower = txPower;
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
        function pkt = sendPacket(obj)
            channel = obj.currentChannel;
            pkt = obj.popTxPacket();
            if isempty(pkt)
                return;
            end

            sig = Signal(SignalType.COMM, pkt, obj.txPower, obj.id, channel.id, obj.position);
            channel.addSignal(sig);
        end


        %========== 패킷 수신(ACK/NACK return) ==========
        function pkt = receivedPacket(obj, channels, betaThreshold, mu, noisePower)
            for i = 1 : length(channels)
                channel = channels{i};
                signals = channel.getSignals();

                for j = 1:length(signals)
                    sig = signals{j};
                    
                    if sig.type ~= SignalType.COMM
                        % TODO
                        % signal type이 일반이 아닌 경우
                        continue;
                    end

                    if sig.packet.dstId ~= obj.id
                        % TODO
                        % 본인 패킷이 아니니까 무시 -> 잡음 처리
                        continue;
                    end

                    sinr = channel.computeSINR(mu, noisePower);

                    pkt = sig.packet;

                    if sinr > betaThreshold
                        obj.rxBuffer{end+1} = pkt;

                        if pkt.type==PacketType.DATA
                            ackPkt = Packet(PacketType.ACK, obj.id, pkt.srcId, "ACK");
                            obj.txBuffer{end+1} = ackPkt; 
                            % ACK는 DATA가 온 동일 채널로 보낸다.
                            obj.currentChannel = channel;
                        end
                    else
                        nackPkt = Packet(PacketType.NACK, obj.id, pkt.srcId, "NACK");
                        obj.txBuffer{end+1} = nackPkt;
                        % NACK도 동일 채널로 보낸다고 단순화 가능
                        obj.currentChannel = channel;
                    end

                    return;
                end

            end
        end
    end

end