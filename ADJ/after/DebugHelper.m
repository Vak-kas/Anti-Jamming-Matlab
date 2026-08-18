classdef DebugHelper
    methods (Static)

        % ============================================================
        % Satellite 정보 출력
        % ============================================================
        function printSatelliteInfo(SatelliteNode)

            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('Satellite Information\n');
            fprintf('============================================================\n');

            fprintf('  Satellite ID       : %d\n', SatelliteNode.Id);

            fprintf('  Position           : (%.2f, %.2f, %.2f) km\n', ...
                SatelliteNode.Position(1)/1e3, ...
                SatelliteNode.Position(2)/1e3, ...
                SatelliteNode.Position(3)/1e3);

            fprintf('  Number of Beams    : %d\n', ...
                numel(SatelliteNode.Beams));

            fprintf('============================================================\n');


            fprintf('\n');
            fprintf('------------------------------------------------------------\n');
            fprintf('Associated Beam Information\n');
            fprintf('------------------------------------------------------------\n');

            for beamIndex = 1:numel(SatelliteNode.Beams)

                beam = SatelliteNode.Beams(beamIndex);

                fprintf('\n');
                fprintf('  [Beam %d]\n', beam.Id);

                fprintf('    Center Position       : (%.2f, %.2f, %.2f) km\n', ...
                    beam.CenterPosition(1)/1e3, ...
                    beam.CenterPosition(2)/1e3, ...
                    beam.CenterPosition(3)/1e3);

                fprintf('    Radius                : %.2f km\n', ...
                    beam.Radius/1e3);

                fprintf('    Diameter              : %.2f km\n', ...
                    2 * beam.Radius/1e3);

                fprintf('    Max Tx Gain           : %.2f dBi\n', ...
                    beam.MaxTxGain_dBi);

                fprintf('    3 dB Beamwidth        : %.4f deg\n', ...
                    beam.Beamwidth3dB_deg);

                fprintf('    Tx Power              : %.2f dBm\n', ...
                    beam.TxPower_dBm);

                fprintf('    Associated UT ID      : %d\n', ...
                    beam.AssociatedUTId);

                fprintf('    Selected Channel      : %d\n', ...
                    beam.SelectedChannel);

            end

            fprintf('\n');
            fprintf('============================================================\n');

        end


        % ============================================================
        % UT 정보 출력
        % ============================================================
        function printUTInfo(UTs, Beams, SatelliteNode)

            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('UT Information\n');
            fprintf('============================================================\n');

            satellitePosition = SatelliteNode.Position(:);

            satelliteGroundPosition = satellitePosition;
            satelliteGroundPosition(3) = 0;


            for utIndex = 1:numel(UTs)

                ut = UTs(utIndex);
                beam = Beams(ut.AssociatedBeamId);

                utPosition = ut.Position(:);

                % Beam 중심 ↔ UT
                beamCenterDistance = ...
                    beam.groundDistanceTo(utPosition);

                % Satellite ↔ UT 실제 3D 거리
                satelliteDistance = ...
                    norm(satellitePosition - utPosition);

                % Satellite 직하점 ↔ UT 지상거리
                satelliteGroundDistance = ...
                    norm( ...
                        satelliteGroundPosition(1:2) ...
                        - utPosition(1:2) ...
                    );


                fprintf('\n');
                fprintf('  [UT %d]\n', ut.Id);

                fprintf('    Position                    : (%.2f, %.2f, %.2f) km\n', ...
                    ut.Position(1)/1e3, ...
                    ut.Position(2)/1e3, ...
                    ut.Position(3)/1e3);

                fprintf('    Target UT                   : %s\n', ...
                    DebugHelper.boolToString(ut.IsTarget));

                fprintf('    Associated Beam ID          : %d\n', ...
                    ut.AssociatedBeamId);

                fprintf('    Associated Beam Center      : (%.2f, %.2f, %.2f) km\n', ...
                    beam.CenterPosition(1)/1e3, ...
                    beam.CenterPosition(2)/1e3, ...
                    beam.CenterPosition(3)/1e3);

                fprintf('    Beam Center Distance        : %.2f km\n', ...
                    beamCenterDistance/1e3);

                fprintf('    Beam Radius                 : %.2f km\n', ...
                    beam.Radius/1e3);

                fprintf('    Satellite Distance          : %.2f km\n', ...
                    satelliteDistance/1e3);

                fprintf('    Satellite Ground Distance   : %.2f km\n', ...
                    satelliteGroundDistance/1e3);

                fprintf('    Tx Power                    : %.2f dBm\n', ...
                    ut.TxPower_dBm);

                fprintf('    Rx Gain                     : %.2f dBi\n', ...
                    ut.RxGain_dBi);

                fprintf('    Noise Temperature           : %.2f K\n', ...
                    ut.NoiseTemperature);

                fprintf('    Noise Figure                : %.2f dB\n', ...
                    ut.NoiseFigure_dB);

                fprintf('    SINR Threshold              : %.2f dB\n', ...
                    ut.SINRThreshold_dB);

            end

            fprintf('\n');
            fprintf('============================================================\n');

        end


        % ============================================================
        % APJ 정보 출력
        % ============================================================
        function printAPJInfo(APJNode, UTs, SatelliteNode)

            targetUT = UTs(APJNode.TargetUTId);

            apjPosition = APJNode.Position(:);
            targetPosition = targetUT.Position(:);
            satellitePosition = SatelliteNode.Position(:);

            % APJ ↔ Target UT 지상거리
            targetUTDistance = norm( ...
                apjPosition(1:2) - targetPosition(1:2) ...
            );

            % APJ ↔ Satellite 3D 거리
            satelliteDistance = norm( ...
                apjPosition - satellitePosition ...
            );

            % Satellite 직하점 ↔ APJ
            satelliteGroundDistance = norm( ...
                apjPosition(1:2) - satellitePosition(1:2) ...
            );


            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('APJ Information\n');
            fprintf('============================================================\n');

            fprintf('  APJ ID                     : %d\n', ...
                APJNode.Id);

            fprintf('  Position                   : (%.2f, %.2f, %.2f) km\n', ...
                APJNode.Position(1)/1e3, ...
                APJNode.Position(2)/1e3, ...
                APJNode.Position(3)/1e3);

            fprintf('  Target UT ID               : %d\n', ...
                APJNode.TargetUTId);

            fprintf('  Target UT Distance         : %.2f km\n', ...
                targetUTDistance/1e3);

            fprintf('  Satellite Distance         : %.2f km\n', ...
                satelliteDistance/1e3);

            fprintf('  Satellite Ground Distance  : %.2f km\n', ...
                satelliteGroundDistance/1e3);

            fprintf('  Tx Power                   : %.2f dBm\n', ...
                APJNode.TxPower_dBm);

            fprintf('  Rx Gain                    : %.2f dBi\n', ...
                APJNode.RxGain_dBi);

            fprintf('  Noise Temperature          : %.2f K\n', ...
                APJNode.NoiseTemperature);

            fprintf('  Noise Figure               : %.2f dB\n', ...
                APJNode.NoiseFigure_dB);

            fprintf('  SINR Threshold             : %.2f dB\n', ...
                APJNode.SINRThreshold_dB);

            fprintf('============================================================\n');

        end


        % ============================================================
        % Beam - UT Association 검사
        % ============================================================
        function printBeamUTAssociation(Beams, UTs)

            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('Beam - UT Association\n');
            fprintf('============================================================\n');

            for beamIndex = 1:numel(Beams)

                beam = Beams(beamIndex);
                ut = UTs(beam.AssociatedUTId);

                distance = beam.groundDistanceTo(ut.Position);

                fprintf( ...
                    '  Beam %2d <-> UT %2d | Distance: %6.2f km | ', ...
                    beam.Id, ...
                    ut.Id, ...
                    distance/1e3 ...
                );

                if distance <= beam.Radius
                    fprintf('Inside\n');
                else
                    fprintf('OUTSIDE\n');
                end

            end

            fprintf('============================================================\n');

        end


        % ============================================================
        % Boolean → String
        % ============================================================
        function result = boolToString(value)

            if value
                result = 'Yes';
            else
                result = 'No';
            end

        end

        % ============================================================
        % Time Slot 출력
        % ============================================================
        function printTimeSlot(slotIndex)

            fprintf("\n");
            fprintf("------------------------------------------------------------\n");
            fprintf("Time Slot %d\n", slotIndex);
            fprintf("------------------------------------------------------------\n");

        end

        % ============================================================
        % Service / Control Channel 정보 출력
        % ============================================================
        function printChannels(ServiceChannels, ControlChannels)
        
            fprintf("\n");
            fprintf("[Channel Information]\n");
        
        
            %% ========================================================
            % Service Channels
            % =========================================================
            fprintf("  Service Channels\n");
        
            for channelIndex = 1:numel(ServiceChannels)
        
                packets = ServiceChannels(channelIndex).getPackets();
        
                % ------------------------------------------------------
                % Empty Channel
                % ------------------------------------------------------
                if isempty(packets)
        
                    fprintf("    Channel %2d : Empty\n", channelIndex);
        
                % ------------------------------------------------------
                % Packet 존재
                % ------------------------------------------------------
                else
        
                    fprintf("    Channel %2d\n", channelIndex);
        
                    for packetIndex = 1:numel(packets)
        
                        packet = packets(packetIndex);
        
                        switch packet.Type
        
                            % ==========================================
                            % DATA
                            % ==========================================
                            case PacketType.DATA
        
                                fprintf( ...
                                    "      DATA | Beam %d -> UT %d\n", ...
                                    packet.BeamId, ...
                                    packet.DestinationId ...
                                );
        
        
                            % ==========================================
                            % JAMMING
                            % ==========================================
                            case PacketType.JAMMING
        
                                fprintf( ...
                                    "      JAMMING | APJ %d -> Beam %d\n", ...
                                    packet.SourceId, ...
                                    packet.BeamId ...
                                );
        
        
                            % ==========================================
                            % 기타 Packet
                            % ==========================================
                            otherwise
        
                                fprintf( ...
                                    "      UNKNOWN PACKET\n" ...
                                );
        
                        end
        
                    end
        
                end
        
            end
        
        
        
            %% ========================================================
            % Control Channels
            % =========================================================
            fprintf("\n");
            fprintf("  Control Channels\n");
        
            for channelIndex = 1:numel(ControlChannels)
        
                packets = ControlChannels(channelIndex).getPackets();
        
                % ------------------------------------------------------
                % Empty Channel
                % ------------------------------------------------------
                if isempty(packets)
        
                    fprintf("    Channel %2d : Empty\n", channelIndex);
        
                % ------------------------------------------------------
                % Packet 존재
                % ------------------------------------------------------
                else
        
                    fprintf("    Channel %2d\n", channelIndex);
        
                    for packetIndex = 1:numel(packets)
        
                        packet = packets(packetIndex);
        
                        switch packet.Type
        
                            % ==========================================
                            % ACK
                            % ==========================================
                            case PacketType.ACK
        
                                fprintf( ...
                                    "      ACK  | UT %d -> Beam %d\n", ...
                                    packet.SourceId, ...
                                    packet.BeamId ...
                                );
        
        
                            % ==========================================
                            % NACK
                            % ==========================================
                            case PacketType.NACK
        
                                fprintf( ...
                                    "      NACK | UT %d -> Beam %d\n", ...
                                    packet.SourceId, ...
                                    packet.BeamId ...
                                );
        
        
                            % ==========================================
                            % 기타 Packet
                            % ==========================================
                            otherwise
        
                                fprintf( ...
                                    "      UNKNOWN PACKET\n" ...
                                );
        
                        end
        
                    end
        
                end
        
            end
        
        
            fprintf("\n");
        
        end

        % ============================================================
        % SINR 계산 디버그 출력
        % ============================================================
        function printSINRCalculation( ...
                utId, ...
                beamId, ...
                channelId, ...
                distance_m, ...
                desiredTxPower_dBm, ...
                desiredTxGain_dBi, ...
                desiredPower_W, ...
                interferencePackets, ...
                interferenceGain_dBi, ...
                interferencePowerEach_W, ...
                interferencePowerTotal_W, ...
                noisePower_W, ...
                SINR_dB, ...
                threshold_dB)
        
            fprintf("\n");
            fprintf("============================================================\n");
            fprintf("SINR Calculation - UT %d\n", utId);
            fprintf("============================================================\n");
        
            fprintf("  Desired Beam            : %d\n", beamId);
            fprintf("  Channel                 : %d\n", channelId);
            fprintf("  Satellite Distance      : %.2f km\n", distance_m / 1e3);
        
            fprintf("\n");
            fprintf("  [Desired Signal]\n");
            fprintf("    Tx Power              : %.2f dBm\n", desiredTxPower_dBm);
            fprintf("    Tx Gain               : %.2f dBi\n", desiredTxGain_dBi);
            fprintf("    Received Power        : %.6e W\n", desiredPower_W);
            fprintf("    Received Power        : %.2f dBm\n", ...
                10 * log10(desiredPower_W) + 30);
        
            fprintf("\n");
            fprintf("  [Interference]\n");
        
            if isempty(interferencePackets)
        
                fprintf("    None\n");
        
            else
        
                for i = 1:numel(interferencePackets)
        
                    fprintf( ...
                        "    Beam %2d | Tx Gain: %8.2f dBi | Rx Power: %.6e W (%.2f dBm)\n", ...
                        interferencePackets(i).BeamId, ...
                        interferenceGain_dBi(i), ...
                        interferencePowerEach_W(i), ...
                        10 * log10(interferencePowerEach_W(i)) + 30 ...
                    );
        
                end
            end
        
            fprintf("\n");
            fprintf("  [Power Summary]\n");
            fprintf("    Total Interference    : %.6e W (%.2f dBm)\n", ...
                interferencePowerTotal_W, ...
                10 * log10(max(interferencePowerTotal_W, realmin)) + 30);
        
            fprintf("    Noise Power           : %.6e W (%.2f dBm)\n", ...
                noisePower_W, ...
                10 * log10(noisePower_W) + 30);
        
            fprintf("\n");
            fprintf("  [Result]\n");
            fprintf("    SINR                   : %.2f dB\n", SINR_dB);
            fprintf("    Threshold              : %.2f dB\n", threshold_dB);
        
            if SINR_dB >= threshold_dB
                fprintf("    HARQ Result            : ACK\n");
            else
                fprintf("    HARQ Result            : NACK\n");
            end
        
            fprintf("============================================================\n");
        
        end


        % ============================================================
        % Interference-Free SNR Calibration Summary
        % ============================================================
        function printSNRCalibrationSummary(allSNR_dB)
        
            fprintf("\n");
            fprintf("============================================================\n");
            fprintf("Interference-Free SNR Calibration Summary\n");
            fprintf("============================================================\n");
        
            fprintf("  Number of Samples       : %d\n", numel(allSNR_dB));
            fprintf("  Minimum SNR             : %.2f dB\n", min(allSNR_dB));
            fprintf("  Maximum SNR             : %.2f dB\n", max(allSNR_dB));
            fprintf("  Mean SNR                : %.2f dB\n", mean(allSNR_dB));
            fprintf("  Median SNR              : %.2f dB\n", median(allSNR_dB));
        
            sortedSNR = sort(allSNR_dB);
        
            p1Index = max(1, ceil(0.01 * numel(sortedSNR)));
            p5Index = max(1, ceil(0.05 * numel(sortedSNR)));
        
            fprintf("  1%% Percentile           : %.2f dB\n", sortedSNR(p1Index));
            fprintf("  5%% Percentile           : %.2f dB\n", sortedSNR(p5Index));
        
            fprintf("============================================================\n");
        
        end


        % ============================================================
        % Simulation 결과 Summary
        % ============================================================
        function printSimulationSummary( ...
                numTimeSlots, ...
                numUTs, ...
                totalACKCount, ...
                totalTransmissionCount, ...
                slotSuccessRatios, ...
                targetACKResults, ...
                targetSINRResults_dB)
        
        
            %% ==================== 전체 결과 ====================
        
            totalNACKCount = ...
                totalTransmissionCount - totalACKCount;
        
            overallSuccessRatio = ...
                totalACKCount / totalTransmissionCount;
        
            overallFailureRatio = ...
                totalNACKCount / totalTransmissionCount;
        
        
            %% ==================== Target UT 결과 ====================
        
            targetACKCount = ...
                sum(targetACKResults);
        
            targetNACKCount = ...
                numTimeSlots - targetACKCount;
        
            targetSuccessRatio = ...
                targetACKCount / numTimeSlots;
        
        
            %% ==================== SINR 통계 ====================
        
            averageTargetSINR_dB = ...
                mean(targetSINRResults_dB);
        
            minimumTargetSINR_dB = ...
                min(targetSINRResults_dB);
        
            maximumTargetSINR_dB = ...
                max(targetSINRResults_dB);
        
        
            %% ==================== 출력 ====================
        
            fprintf("\n");
            fprintf("============================================================\n");
            fprintf("Simulation Summary\n");
            fprintf("============================================================\n");
        
            fprintf("  Number of Time Slots       : %d\n", numTimeSlots);
            fprintf("  Number of UTs              : %d\n", numUTs);
            fprintf("  Total Transmissions        : %d\n", totalTransmissionCount);
        
            fprintf("\n");
            fprintf("  [Overall HARQ]\n");
            fprintf("    ACK Count                : %d\n", totalACKCount);
            fprintf("    NACK Count               : %d\n", totalNACKCount);
            fprintf("    ACK Ratio                : %.2f %%\n", ...
                overallSuccessRatio * 100);
            fprintf("    NACK Ratio               : %.2f %%\n", ...
                overallFailureRatio * 100);
        
            fprintf("\n");
            fprintf("  [Slot Statistics]\n");
            fprintf("    Mean Success Ratio       : %.2f %%\n", ...
                mean(slotSuccessRatios) * 100);
            fprintf("    Minimum Success Ratio    : %.2f %%\n", ...
                min(slotSuccessRatios) * 100);
            fprintf("    Maximum Success Ratio    : %.2f %%\n", ...
                max(slotSuccessRatios) * 100);
        
            fprintf("\n");
            fprintf("  [Target UT]\n");
            fprintf("    ACK Count                : %d\n", targetACKCount);
            fprintf("    NACK Count               : %d\n", targetNACKCount);
            fprintf("    ACK Ratio                : %.2f %%\n", ...
                targetSuccessRatio * 100);
            fprintf("    Average SINR             : %.2f dB\n", ...
                averageTargetSINR_dB);
            fprintf("    Minimum SINR             : %.2f dB\n", ...
                minimumTargetSINR_dB);
            fprintf("    Maximum SINR             : %.2f dB\n", ...
                maximumTargetSINR_dB);
        
            fprintf("============================================================\n");
        
        end

        %% ========== Observation Sensing 결과 출력 ==========
        function printObservationSensing(owner, observationManager, ServiceChannels, Satellite)
        
            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('RF Sensing - %s %d\n', char(string(owner.Type)), owner.Id);
            fprintf('============================================================\n');
        
            fprintf('  Number of Channels       : %d\n', observationManager.NumChannels);
        
            if owner.Type == NodeType.UT
                fprintf('  Associated Beam          : %d\n', owner.AssociatedBeamId);
            end
        
            fprintf('\n');
            fprintf('  [Per-Channel Sensing]\n');
        
        
            %% 채널별 상세 sensing 정보
            for channelIndex = 1:observationManager.NumChannels
        
                channel = ServiceChannels(channelIndex);
                packets = channel.getPackets();
        
                centerFrequency_Hz = channel.CenterFrequency_Hz;
        
                fprintf('\n');
                fprintf('    Channel %2d | %.3f MHz\n', ...
                    channelIndex, ...
                    centerFrequency_Hz / 1e6);
        
        
                numDataPackets = 0;
                numInterferingBeams = 0;
        
        
                %% 해당 채널의 DATA Beam 확인
                for packetIndex = 1:numel(packets)
        
                    packet = packets(packetIndex);
        
                    if packet.Type ~= PacketType.DATA
                        continue;
                    end
        
                    numDataPackets = numDataPackets + 1;
        
                    beam = Satellite.Beams(packet.BeamId);
        
        
                    %% Serving Beam 여부
                    isServingBeam = false;
        
                    if owner.Type == NodeType.UT
                        isServingBeam = ...
                            (beam.Id == owner.AssociatedBeamId);
                    end
        
        
                    %% Serving Beam이면 sensing에서 제외
                    if isServingBeam
        
                        fprintf( ...
                            '      Beam %2d -> UT %2d | Serving Beam | Excluded\n', ...
                            beam.Id, ...
                            packet.DestinationId ...
                        );
        
                        continue;
                    end
        
        
                    %% 실제 수신 전력 계산
                    receivedPower_W = ...
                        observationManager.calculateReceivedPower_W( ...
                            beam, ...
                            Satellite, ...
                            centerFrequency_Hz ...
                        );
        
                    receivedPower_dBm = ...
                        10 * log10(receivedPower_W) + 30;
        
                    numInterferingBeams = ...
                        numInterferingBeams + 1;
        
        
                    fprintf( ...
                        '      Beam %2d -> UT %2d | Rx Power: %8.2f dBm\n', ...
                        beam.Id, ...
                        packet.DestinationId, ...
                        receivedPower_dBm ...
                    );
        
                end
        
        
                %% Noise
                noisePower_W = ...
                    observationManager.calculateNoisePower_W( ...
                        channel.Bandwidth_Hz ...
                    );
        
                noisePower_dBm = ...
                    10 * log10(noisePower_W) + 30;
        
        
                %% Observation
                sensedPower_dBm = ...
                    observationManager.CurrentObservation(channelIndex);
        
        
                if numDataPackets == 0
        
                    fprintf('      DATA Beams           : None\n');
        
                elseif numInterferingBeams == 0
        
                    fprintf('      Interfering Beams    : None\n');
        
                end
        
        
                fprintf('      Noise Power          : %8.2f dBm\n', ...
                    noisePower_dBm);
        
                fprintf('      Sensed Power         : %8.2f dBm\n', ...
                    sensedPower_dBm);
        
            end
        
        
            %% Current Observation
            fprintf('\n');
            fprintf('  [Current Observation]\n');
        
            fprintf('    Channel :');
        
            for channelIndex = 1:observationManager.NumChannels
                fprintf(' %8d', channelIndex);
            end
        
            fprintf('\n');
        
            fprintf('    Power   :');
        
            for channelIndex = 1:observationManager.NumChannels
                fprintf(' %8.2f', ...
                    observationManager.CurrentObservation(channelIndex));
            end
        
            fprintf(' dBm\n');
        
            fprintf('============================================================\n');
        
        end
       

        %% ========== Control Channel 상세 출력 ==========
        function printChannelDetail(ControlChannels)
        
            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('Control Channel Detail\n');
            fprintf('============================================================\n');
        
            for channelIndex = 1:numel(ControlChannels)
        
                packets = ControlChannels(channelIndex).getPackets();
        
                fprintf('\n');
                fprintf('  Channel %2d\n', channelIndex);
        
                if isempty(packets)
                    fprintf('    Empty\n');
                    continue;
                end
        
                for packetIndex = 1:numel(packets)
        
                    packet = packets(packetIndex);
        
                    % ACK / NACK 문자열
                    if packet.Type == PacketType.ACK
                        packetTypeStr = 'ACK';
                    elseif packet.Type == PacketType.NACK
                        packetTypeStr = 'NACK';
                    else
                        packetTypeStr = char(string(packet.Type));
                    end
        
                    % 기본 정보
                    fprintf('    %-4s | UT %2d -> Beam %2d\n', ...
                        packetTypeStr, ...
                        packet.SourceId, ...
                        packet.BeamId);
        
                    % Payload
                    if isempty(packet.Payload)
        
                        fprintf('           Payload : Empty\n');
        
                    else
        
                        fprintf('           Payload :');
        
                        for channelIndexPayload = 1:numel(packet.Payload)
                            fprintf(' %8.2f', packet.Payload(channelIndexPayload));
                        end
        
                        fprintf(' dBm\n');
        
                    end
        
                end
        
            end
        
            fprintf('\n');
            fprintf('============================================================\n');
        
        end


        %% ========== Beam StateManager 상태 출력 ==========
        function printBeamState(beam)
        
            stateManager = beam.StateManager;
        
            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('Beam State - Beam %d\n', beam.Id);
            fprintf('============================================================\n');
        
            fprintf('  Associated UT            : %d\n', beam.AssociatedUTId);
            fprintf('  Selected Channel         : %d\n', beam.SelectedChannel);
            fprintf('  Number of Channels       : %d\n', stateManager.NumChannels);
            fprintf('  History Length           : %d\n', stateManager.HistoryLength);
            fprintf('  Number of Updates        : %d\n', stateManager.NumUpdates);
            fprintf('  Mode                     : %s\n', char(string(stateManager.Mode)));
        
            if stateManager.isReady()
                fprintf('  State Status             : READY\n');
            else
                fprintf('  State Status             : NOT READY (%d / %d)\n', ...
                    stateManager.NumUpdates, ...
                    stateManager.HistoryLength);
            end
        
        
            %% ============================================================
            %  Latest O / A / H
            % =============================================================
            fprintf('\n');
            fprintf('  [Latest O / A / H]\n');
        
            % Header
            fprintf('              ');
            for channelIndex = 1:stateManager.NumChannels
                fprintf(' %8s', sprintf('CH%d', channelIndex));
            end
            fprintf('\n');
        
        
            % Observation
            fprintf('    O       :');
            for channelIndex = 1:stateManager.NumChannels
                fprintf(' %8.2f', ...
                    stateManager.ObservationHistory(1, channelIndex));
            end
            fprintf('\n');
        
        
            % Action
            fprintf('    A       :');
            for channelIndex = 1:stateManager.NumChannels
                fprintf(' %8.0f', ...
                    stateManager.ActionHistory(1, channelIndex));
            end
            fprintf('\n');
        
        
            % HARQ
            fprintf('    H       :');
            for channelIndex = 1:stateManager.NumChannels
                fprintf(' %8.0f', ...
                    stateManager.HarqHistory(1, channelIndex));
            end
            fprintf('\n');
        
        
            %% ============================================================
            %  Observation History
            % =============================================================
            fprintf('\n');
            fprintf('  [Observation History]\n');
        
            DebugHelper.printStateHistoryMatrix( ...
                stateManager.ObservationHistory, ...
                stateManager.NumUpdates, ...
                stateManager.HistoryLength, ...
                stateManager.NumChannels, ...
                '%.2f' ...
            );
        
        
            %% ============================================================
            %  Action History
            % =============================================================
            fprintf('\n');
            fprintf('  [Action History]\n');
        
            DebugHelper.printStateHistoryMatrix( ...
                stateManager.ActionHistory, ...
                stateManager.NumUpdates, ...
                stateManager.HistoryLength, ...
                stateManager.NumChannels, ...
                '%.0f' ...
            );
        
        
            %% ============================================================
            %  HARQ History
            % =============================================================
            fprintf('\n');
            fprintf('  [HARQ History]\n');
        
            DebugHelper.printStateHistoryMatrix( ...
                stateManager.HarqHistory, ...
                stateManager.NumUpdates, ...
                stateManager.HistoryLength, ...
                stateManager.NumChannels, ...
                '%.0f' ...
            );
        
        
            %% ============================================================
            %  DQN State
            % =============================================================
            fprintf('\n');
            fprintf('  [DQN State]\n');
        
            state = stateManager.getState();
            stateSize = size(state);
        
            if numel(stateSize) == 2
                fprintf('    State Size             : %d x %d\n', ...
                    stateSize(1), ...
                    stateSize(2));
            else
                fprintf('    State Size             : %d x %d x %d\n', ...
                    stateSize(1), ...
                    stateSize(2), ...
                    stateSize(3));
            end
        
            fprintf('============================================================\n');
        
        end
        
        
        %% ========== State History Matrix 출력 ==========
        function printStateHistoryMatrix( ...
                history, ...
                numUpdates, ...
                historyLength, ...
                numChannels, ...
                numberFormat)
        
            % 왼쪽 시간축 폭
            timeWidth = 8;
        
            % 각 Channel 열 폭
            columnWidth = 10;
        
        
            %% Header
            fprintf('%*s', timeWidth, '');
        
            for channelIndex = 1:numChannels
                fprintf('%*s', ...
                    columnWidth, ...
                    sprintf('CH%d', channelIndex));
            end
        
            fprintf('\n');
        
        
            %% 실제 채워진 Row 수
            numFilledRows = min(numUpdates, historyLength);
        
        
            %% History 출력
            for historyIndex = 1:historyLength
        
                if historyIndex == 1
                    timeLabel = 't';
                else
                    timeLabel = sprintf('t-%d', historyIndex - 1);
                end
        
                fprintf('%*s', timeWidth, timeLabel);
        
        
                for channelIndex = 1:numChannels
        
                    value = history(historyIndex, channelIndex);
        
                    valueString = sprintf(numberFormat, value);
        
                    fprintf('%*s', ...
                        columnWidth, ...
                        valueString);
        
                end
        
                % 아직 데이터가 없는 Row 표시
                if historyIndex > numFilledRows
                    fprintf('   <- Empty');
                end
        
                fprintf('\n');
        
            end
        
        end


        

    end
end