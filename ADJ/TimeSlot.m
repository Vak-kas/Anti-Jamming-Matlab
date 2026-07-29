classdef TimeSlot
    properties
        UseAgent
        ReconnaissanceDuration
    end

    methods
        function obj = TimeSlot()
            env;
            obj.UseAgent  = useAgent;
            obj.ReconnaissanceDuration = reconnaissanceDuration;
        end

        
        function result = run(obj, slotIndex, UTs, Satellites, apjNode, ServiceChannels, ControlChannels)
            %% 1. 채널 초기화
            obj.clearChannels(ServiceChannels, ControlChannels);


            %% 2. UT의 랜덤 채널 선택
            for utIndex = 1:numel(UTs)
                if obj.UseAgent
                    % TODO - DQN 적용 예정
                    selectedChannel = UTs(utIndex).Agent.selectAction();
                else
                    selectedChannel = randi(numel(ServiceChannels));
                end

                UTs(utIndex).SelectedChannel = selectedChannel;
            end


            %% 3. Data 패킷 생성
            dataPackets = cell(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                selectedChannel = UTs(utIndex).SelectedChannel;
                dataPackets{utIndex} = Packet(PacketType.DATA, NodeType.UT, utIndex, NodeType.Satellite, utIndex, ChannelType.Service, selectedChannel);
            end


            %% 4. Service Channel에 Data 패킷 추가
            for utIndex = 1:numel(UTs)
                selectedChannel = dataPackets{utIndex}.ChannelId;
                ServiceChannels(selectedChannel).addPacket(dataPackets{utIndex});
            end

            
            %% 5. APJ 동작
            % Target UT의 사용중인 채널 탐색
            observedChannel = apjNode.findObservedChannel(ServiceChannels);


            if slotIndex <= obj.ReconnaissanceDuration
            % 아직 정찰 단계
            

            else
            % 공격 수행 단계


            end
            
            

            %% 6. Satellite의 HARQ 수행
            for satelliteIndex = 1:numel(Satellites)
                Satellites(satelliteIndex).performHARQ(ServiceChannels, ControlChannels, UTs);
            end

            % DebugHelper.printChannels(ServiceChannels, ControlChannels);


            %% 7. UT & APJ의 결과 확인 DQN 학습
            % UT의 성공 여부 확인
            actualACK = zeros(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                actualACK(utIndex) = UTs(utIndex).receiveHARQFeedback(ControlChannels);
            end
            actualTargetACK = actualACK(1);

            if obj.UseAgent
                % TODO - DQN 적용 예정
            else
            end

            % APJ가 성공 여부 확인
            estimatedACK = apjNode.estimateHARQ(ServiceChannels, UTs);

            


            %% 결과 반환
            if actualTargetACK && estimatedACK
                result = 0;   % TP (ACK -> ACK)
            elseif actualTargetACK && ~estimatedACK
                result = 1;   % FN (ACK -> NACK)
            elseif ~actualTargetACK && estimatedACK
                result = 2;   % FP (NACK -> ACK)
            else
                result = 3;   % TN (NACK -> NACK)
            end
            % result = 0;
        end




        %% 채널 초기화
        function clearChannels(obj, ServiceChannels, ControlChannels)
            for channelIndex = 1:numel(ServiceChannels)
                ServiceChannels(channelIndex).clearPacket();
            end

            for channelIndex = 1:numel(ControlChannels)
                ControlChannels(channelIndex).clearPacket();
            end

        end
    end
end