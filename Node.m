classdef Node < handle

    properties
        id

        role          % Tx, Rx, Jammer
        position      % [x, y, z]
        txPower       % mW

        currentChannel
        FHP

        txBuffer
        rxBuffer
    end

    methods
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

        %========== 채널 ID로 직접 설정 ==========
        function ch = setChannelById(obj, channelId, channels)
            K = length(channels);
            if channelId < 1 || channelId > K
                error("Invalid channelId: %d", channelId);
            end
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
            pkt = obj.popTxPacket();

            if isempty(pkt)
                return;
            end

            if isempty(obj.currentChannel)
                error("currentChannel is empty. Select channel first.");
            end

            sig = Signal( ...
                SignalType.COMM, ...
                pkt, ...
                obj.txPower, ...
                obj.id, ...
                obj.role, ...
                obj.currentChannel.id, ...
                obj.position ...
            );

            obj.currentChannel.addSignal(sig);
        end

        %========== 패킷 수신(DATA 수신 후 ACK/NACK 생성) ==========
        function pkt = receivedPacket(obj, channels, betaThreshold, thermalNoise, channelModel)
            pkt = [];

            for i = 1:length(channels)
                channel = channels{i};
                signals = channel.getSignals();

                if isempty(signals)
                    continue;
                end

                for j = 1:length(signals)
                    sig = signals{j};

                    if sig.type ~= SignalType.COMM
                        continue;
                    end

                    if isempty(sig.packet)
                        continue;
                    end

                    if sig.packet.dstId ~= obj.id
                        continue;
                    end

                    pkt = sig.packet;

                    if pkt.type ~= PacketType.DATA
                        continue;
                    end

                    sinr = obj.computeSINR(channel, sig, thermalNoise, channelModel);

                    if sinr > betaThreshold
                        obj.rxBuffer{end+1} = pkt;

                        ackPkt = Packet(PacketType.ACK, obj.id, pkt.srcId, "ACK");
                        obj.txBuffer{end+1} = ackPkt;

                        obj.currentChannel = channel;
                    else
                        nackPkt = Packet(PacketType.NACK, obj.id, pkt.srcId, "NACK");
                        obj.txBuffer{end+1} = nackPkt;

                        obj.currentChannel = channel;
                    end

                    return;
                end
            end
        end

        %========== ACK/NACK 수신 ==========
        function success = receiveAck(obj, betaThreshold, thermalNoise, channelModel)
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

                if pkt.type ~= PacketType.ACK && pkt.type ~= PacketType.NACK
                    continue;
                end

                if pkt.type == PacketType.NACK
                    obj.rxBuffer{end+1} = pkt;
                    success = false;
                    return;
                end

                ackSinr = obj.computeSINR(obj.currentChannel, sig, thermalNoise, channelModel);

                if ackSinr > betaThreshold
                    obj.rxBuffer{end+1} = pkt;
                    success = true;
                else
                    success = false;
                end

                fprintf("Tx %d | ACK SINR = %.3e\n", obj.id, ackSinr);
                return;
            end
        end

        %========== SINR 계산 ==========
        function sinr = computeSINR(obj, channel, desiredSignal, thermalNoise, channelModel)
            desiredPower = obj.computeReceivedPower(desiredSignal, channelModel);

            jammingPower = 0;
            interferencePower = 0;

            signals = channel.getSignals();

            for i = 1:length(signals)
                sig = signals{i};

                if obj.isSameSignal(sig, desiredSignal)
                    continue;
                end

                rxPower = obj.computeReceivedPower(sig, channelModel);

                if sig.type == SignalType.JAMMING
                    jammingPower = jammingPower + rxPower;
                elseif sig.type == SignalType.COMM
                    interferencePower = interferencePower + rxPower;
                end
            end

            sinr = desiredPower / (jammingPower + interferencePower + thermalNoise);

            fprintf("Node %d | CH %d | desired=%.3e | jam=%.3e | interf=%.3e | noise=%.3e | SINR=%.3e\n", ...
                obj.id, channel.id, desiredPower, jammingPower, interferencePower, thermalNoise, sinr);
        end

        %========== 수신 전력 계산 ==========
        function rxPower = computeReceivedPower(obj, sig, channelModel)
            gain = channelModel.getGain( ...
                sig.txRole, ...
                sig.txNodeId, ...
                obj.role, ...
                obj.id ...
            );

            rxPower = sig.txPower * gain;
        end

        %========== 동일 Signal 여부 확인 ==========
        function same = isSameSignal(obj, sig1, sig2)
            same = false;

            if sig1.type ~= sig2.type
                return;
            end

            if sig1.txNodeId ~= sig2.txNodeId
                return;
            end

            if sig1.txChannelId ~= sig2.txChannelId
                return;
            end

            if sig1.txRole ~= sig2.txRole
                return;
            end

            if isempty(sig1.packet) && isempty(sig2.packet)
                same = true;
                return;
            end

            if isempty(sig1.packet) || isempty(sig2.packet)
                return;
            end

            same = sig1.packet.srcId == sig2.packet.srcId && ...
                   sig1.packet.dstId == sig2.packet.dstId && ...
                   sig1.packet.type == sig2.packet.type;
        end



    end
end