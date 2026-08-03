classdef TimeSlot
    properties
        UseAgent
        ReconnaissanceDuration
        Debug
    end

    methods
        function obj = TimeSlot()
            env;
            obj.UseAgent  = useAgent;
            obj.ReconnaissanceDuration = reconnaissanceDuration;
            obj.Debug = isDebug;
        end

        
        function result = run(obj, slotIndex, UTs, Satellites, apjNode, ServiceChannels, ControlChannels)
            %% ========== Time Slot Debug ==========
            if obj.Debug
                fprintf("\n");
                fprintf("==================================================\n");
                fprintf("                  TIME SLOT %d\n", slotIndex);
                fprintf("==================================================\n");
            end


            %% 0. 채널 센싱 및 이전 Transition 완성
            for utIndex = 1:numel(UTs)
                observation = UTs(utIndex).ObservationManager.observe(ServiceChannels, UTs); %O_t
                UTs(utIndex).Agent.setCurrentState(observation);
                UTs(utIndex).Agent.completeTransition();
            end
            DebugHelper.printObservation(UTs(1), ServiceChannels, UTs);

            %% 1. DQN 학습


            
            %% 2. 채널 초기화
            obj.clearChannels(ServiceChannels, ControlChannels);


            %% 3. UT의 채널 선택
            for utIndex = 1:numel(UTs)
                if obj.UseAgent
                    if utIndex == 1
                        selectedChannel = UTs(utIndex).Agent.selectAction(obj.Debug); %a_t
                    else
                        selectedChannel = UTs(utIndex).Agent.selectAction();
                    end
                else
                    selectedChannel = randi(numel(ServiceChannels));
                end

                UTs(utIndex).SelectedChannel = selectedChannel;
            end


            %% 4. UT의 Data를 Service 채널에 데이터 전송
            dataPackets = cell(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                selectedChannel = UTs(utIndex).SelectedChannel;
                dataPackets{utIndex} = Packet(PacketType.DATA, NodeType.UT, utIndex, NodeType.Satellite, utIndex, ChannelType.Service, selectedChannel);
            end


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


            %% 7. UT & APJ의 결과 확인 및 reward 저장
            % UT의 성공 여부 확인
            actualACK = zeros(1, numel(UTs));
            for utIndex = 1:numel(UTs)
                actualACK(utIndex) = UTs(utIndex).receiveHARQFeedback(ControlChannels);
            end
            actualTargetACK = actualACK(1);

            if obj.UseAgent
                for utIndex = 1:numel(UTs)
                    UTs(utIndex).Agent.setReward(actualACK(utIndex));

                    if obj.Debug && utIndex ==1
                        DebugHelper.printReward(UTs(utIndex).Id, UTs(utIndex).Agent.PendingReward, actualACK(utIndex));
                    end
                end
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