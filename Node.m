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

            obj.currentChannel = [];
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
            pkt = [];

            for i = 1 : length(channels)
                channel = channels{i};
                signals = channel.getSignals();

                if isempty(signals)
                    continue;
                end

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

                    pkt = sig.packet;
                    if pkt.type ~= PacketType.DATA
                        % TODO
                        % ACK/NACK인지 (Tx 전용 처리)
                        continue;
                    end

                    sinr = obj.computeSINR(mu, noisePower);

                    

                    if sinr > betaThreshold
                        obj.rxBuffer{end+1} = pkt;

                        if pkt.type==PacketType.DATA
                            ackPkt = Packet(PacketType.ACK, obj.id, pkt.srcId, "ACK");
                            obj.txBuffer{end+1} = ackPkt; 
                            % DATA가 온 동일 채널로
                            obj.currentChannel = channel;
                        end
                    else
                        nackPkt = Packet(PacketType.NACK, obj.id, pkt.srcId, "NACK");
                        obj.txBuffer{end+1} = nackPkt;
                        % DATA가 온 동일 채널로
                        obj.currentChannel = channel;
                    end

                    return;
                end

            end
        end

        % ========== ACK/NACK 수신 ==========
        function success = receiveAck(obj)
            success = false;

            if isempty(obj.currentChannel)
                return;
            end

            signals = obj.currentChannel.getSignals();

            if isempty(signals)
                return;
            end

            for i = 1:length(signals)
                sig = signals{i};

                if sig.type ~= SignalType.COMM
                    continue;
                end

                if isempty(sig.packet)
                    continue;
                end

                pkt = sig.packet;
                if pkt.dstId ~= obj.id
                    continue;
                end
        
                if pkt.type == PacketType.ACK
                    obj.rxBuffer{end+1} = pkt;
                    success = true;
                    return;
        
                elseif pkt.type == PacketType.NACK
                    obj.rxBuffer{end+1} = pkt;
                    success = false;
                    return;
                end  
            end

        end
    

        % ========== SINR 계산 ==========
        function sinr = computeSINR(obj, mu, noisePower)
            sinr = 1;
        end

    end

end