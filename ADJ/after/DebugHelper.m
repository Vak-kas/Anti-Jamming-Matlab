classdef DebugHelper
    methods (Static)

        % ============================================================
        % Time Slot 출력
        % ============================================================
        function printTimeSlot(slotIndex)

            fprintf("\n");
            fprintf("------------------------------------------------------------\n");
            fprintf("Time Slot %d\n", slotIndex);
            fprintf("------------------------------------------------------------\n");

        end


        %% ========== Agent Training 결과 출력 ==========
        function printAgentTraining(beam, lossValue, trainingInfo)

            fprintf("\n");
            fprintf("============================================================\n");
            fprintf("Agent Training - Beam %d\n", beam.Id);
            fprintf("============================================================\n");

            fprintf("  Replay Buffer Count      : %d / %d\n", ...
                beam.Agent.ReplayBuffer.Count, ...
                beam.Agent.ReplayBuffer.Capacity);

            fprintf("  Batch Size               : %d\n", ...
                beam.Agent.BatchSize);

            fprintf("  Training Step            : %d\n", ...
                beam.Agent.TrainingStep);

            fprintf("  Epsilon                  : %.6f\n", ...
                beam.Agent.Epsilon);


            fprintf("\n");
            fprintf("  [Training]\n");

            if isempty(lossValue)

                fprintf("    Status                 : SKIPPED\n");
                fprintf("    Reason                 : Replay Buffer not ready\n");

            else

                fprintf("    Status                 : EXECUTED\n");
                fprintf("    Loss                   : %.8f\n", lossValue);

                fprintf("    Mean Q-Value           : %.6f\n", ...
                    trainingInfo.MeanQValue);

                fprintf("    Max Q-Value            : %.6f\n", ...
                    trainingInfo.MaxQValue);

                fprintf("    Mean Target Q-Value    : %.6f\n", ...
                    trainingInfo.MeanTargetQValue);

            end


            currentState = beam.StateManager.getState();
            currentOccupancy = zeros(1, beam.Agent.NumActions);

            dlState = beam.Agent.convertStateToDLArray(currentState);
            dlOccupancy = beam.Agent.convertOccupancyToDLArray(currentOccupancy);

            dlQValues = predict( ...
                beam.Agent.QNetwork, ...
                dlState, ...
                dlOccupancy ...
            );

            qValues = extractdata(dlQValues);
            qValues = qValues(:);


            fprintf("\n");
            fprintf("  [Current Q-Values]\n");

            [~, greedyAction] = max(qValues);

            for channelIndex = 1:numel(qValues)

                fprintf("    CH %2d : %10.6f", ...
                    channelIndex, ...
                    qValues(channelIndex));

                if channelIndex == greedyAction
                    fprintf("  <-- Greedy");
                end

                fprintf("\n");

            end

            fprintf("============================================================\n");

        end


        %% ========== APJ 예측 정확도 기록 ==========
        function recordAPJPrediction(slotIndex, predictedChannel, actualChannel, numChannels)

            newData.slot = slotIndex;
            newData.predicted = predictedChannel;
            newData.actual = actualChannel;

            data = DebugHelper.APJPredictionStorage('add', newData);

            totalCount = numel(data.actual);

            isCorrect = (predictedChannel == actualChannel);

            cumulativeAccuracy = mean(data.predicted == data.actual);

            recentWindow = min(100, totalCount);
            recentPredicted = data.predicted(end-recentWindow+1:end);
            recentActual = data.actual(end-recentWindow+1:end);
            recentAccuracy = mean(recentPredicted == recentActual);

            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('APJ Channel Prediction Evaluation\n');
            fprintf('============================================================\n');

            fprintf('  Slot                     : %d\n', slotIndex);
            fprintf('  Predicted Channel        : %d\n', predictedChannel);
            fprintf('  Actual Channel           : %d\n', actualChannel);

            if isCorrect
                fprintf('  Result                   : HIT\n');
            else
                fprintf('  Result                   : MISS\n');
            end

            fprintf('  Cumulative Accuracy      : %.2f %%\n', cumulativeAccuracy * 100);
            fprintf('  Recent Accuracy (%d)     : %.2f %%\n', recentWindow, recentAccuracy * 100);
            fprintf('============================================================\n');

        end


        %% ========== APJ Prediction Storage ==========
        function data = APJPredictionStorage(action, newData)

            persistent storage

            if isempty(storage)
                storage.slots = [];
                storage.predicted = [];
                storage.actual = [];
            end

            switch action
                case 'add'
                    storage.slots(end+1) = newData.slot;
                    storage.predicted(end+1) = newData.predicted;
                    storage.actual(end+1) = newData.actual;

                case 'get'
                    % 아무 작업 없음

                case 'reset'
                    storage.slots = [];
                    storage.predicted = [];
                    storage.actual = [];
            end

            data = storage;

        end


        %% ========== SINR 계산 상세 출력 ==========
        function printSINRCalculation( ...
                utId, ...
                desiredBeamId, ...
                channelId, ...
                centerFrequency_Hz, ...
                bandwidth_Hz, ...
                satelliteDistance, ...
                desiredTxPower_dBm, ...
                desiredTxGain_dBi, ...
                rxGain_dBi, ...
                desiredPower_W, ...
                interferencePackets, ...
                interferenceGain_dBi, ...
                interferencePowerEach_W, ...
                interferencePower_W, ...
                jammingPackets, ...
                jammingDistance, ...
                jammerTxPower_dBm, ...
                jammerTxGain_dBi, ...
                jammingPowerEach_W, ...
                jammingPower_W, ...
                noisePower_W, ...
                SINR_dB, ...
                sinrThreshold_dB)

            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('SINR Calculation - UT %d\n', utId);
            fprintf('============================================================\n');

            fprintf('  Channel                  : %d\n', channelId);
            fprintf('  Center Frequency         : %.3f MHz\n', ...
                centerFrequency_Hz / 1e6);
            fprintf('  Bandwidth                : %.3f kHz\n', ...
                bandwidth_Hz / 1e3);

            fprintf('\n');

            fprintf('  [Desired Signal]\n');
            fprintf('    Beam ID                : %d\n', desiredBeamId);
            fprintf('    Satellite-UT Distance  : %.3f km\n', ...
                satelliteDistance / 1e3);
            fprintf('    Tx Power               : %.3f dBm\n', ...
                desiredTxPower_dBm);
            fprintf('    Tx Gain                : %.3f dBi\n', ...
                desiredTxGain_dBi);
            fprintf('    UT Rx Gain             : %.3f dBi\n', ...
                rxGain_dBi);

            fprintf('    Received Power         : %.6e W (%8.3f dBm)\n', ...
                desiredPower_W, ...
                DebugHelper.wattToDbm(desiredPower_W));

            fprintf('\n');


            fprintf('  [Co-channel Interference]\n');

            if isempty(interferencePackets)

                fprintf('    Interfering Beams      : None\n');

            else

                fprintf('    Number of Interferers  : %d\n', ...
                    numel(interferencePackets));

                for interferenceIndex = 1:numel(interferencePackets)

                    interferencePacket = ...
                        interferencePackets(interferenceIndex);

                    fprintf('    #%d Beam %-3d | Gain: %8.3f dBi | Power: %8.3f dBm\n', ...
                        interferenceIndex, ...
                        interferencePacket.BeamId, ...
                        interferenceGain_dBi(interferenceIndex), ...
                        DebugHelper.wattToDbm( ...
                            interferencePowerEach_W(interferenceIndex)));
                end
            end

            fprintf('    Total Interference     : %.6e W (%8.3f dBm)\n', ...
                interferencePower_W, ...
                DebugHelper.wattToDbm(interferencePower_W));

            fprintf('\n');


            fprintf('  [APJ Jamming]\n');

            if isempty(jammingPackets)

                fprintf('    Status                 : NONE\n');

            else

                fprintf('    Status                 : ACTIVE\n');
                fprintf('    Number of Jammers      : %d\n', ...
                    numel(jammingPackets));

                if ~isempty(jammingDistance)
                    fprintf('    APJ-UT Distance        : %.3f km\n', ...
                        jammingDistance / 1e3);
                end

                fprintf('    APJ Tx Power           : %.3f dBm\n', ...
                    jammerTxPower_dBm);

                fprintf('    APJ Tx Gain            : %.3f dBi\n', ...
                    jammerTxGain_dBi);

                for jammingIndex = 1:numel(jammingPackets)

                    fprintf('    #%d Received Jam Power : %.6e W (%8.3f dBm)\n', ...
                        jammingIndex, ...
                        jammingPowerEach_W(jammingIndex), ...
                        DebugHelper.wattToDbm( ...
                            jammingPowerEach_W(jammingIndex)));
                end

            end

            fprintf('    Total Jamming Power    : %.6e W (%8.3f dBm)\n', ...
                jammingPower_W, ...
                DebugHelper.wattToDbm(jammingPower_W));

            fprintf('\n');


            fprintf('  [Noise]\n');

            fprintf('    Noise Power            : %.6e W (%8.3f dBm)\n', ...
                noisePower_W, ...
                DebugHelper.wattToDbm(noisePower_W));

            fprintf('\n');


            fprintf('  [Result]\n');

            fprintf('    Desired Power          : %8.3f dBm\n', ...
                DebugHelper.wattToDbm(desiredPower_W));

            fprintf('    Interference Power     : %8.3f dBm\n', ...
                DebugHelper.wattToDbm(interferencePower_W));

            fprintf('    Jamming Power          : %8.3f dBm\n', ...
                DebugHelper.wattToDbm(jammingPower_W));

            fprintf('    Noise Power            : %8.3f dBm\n', ...
                DebugHelper.wattToDbm(noisePower_W));

            fprintf('    SINR                    : %8.3f dB\n', ...
                SINR_dB);

            fprintf('    SINR Threshold          : %8.3f dB\n', ...
                sinrThreshold_dB);

            if SINR_dB >= sinrThreshold_dB
                fprintf('    HARQ Result             : ACK\n');
            else
                fprintf('    HARQ Result             : NACK\n');
            end

            fprintf('============================================================\n');
        end


        %% ========== Watt -> dBm ==========
        function power_dBm = wattToDbm(power_W)

            if power_W <= 0
                power_dBm = -Inf;
            else
                power_dBm = 10 * log10(power_W) + 30;
            end

        end


        %% ========== Target UT HARQ 결과 기록 ==========
        function recordTargetUTOutcome(slotIndex, packetType, SINR_dB, reconnaissanceDuration)

            if isempty(packetType)
                return;
            end

            isACK = (packetType == PacketType.ACK);

            newData.slot = slotIndex;
            newData.isACK = isACK;
            newData.SINR_dB = SINR_dB;
            newData.isAttackPhase = (slotIndex > reconnaissanceDuration);

            DebugHelper.TargetUTStorage('add', newData);

        end


        %% ========== Target UT Outcome Storage ==========
        function data = TargetUTStorage(action, newData)

            persistent storage

            if isempty(storage)
                storage.slots = [];
                storage.isACK = [];
                storage.SINR_dB = [];
                storage.isAttackPhase = [];
            end

            switch action
                case 'add'
                    storage.slots(end+1) = newData.slot;
                    storage.isACK(end+1) = newData.isACK;
                    storage.SINR_dB(end+1) = newData.SINR_dB;
                    storage.isAttackPhase(end+1) = newData.isAttackPhase;

                case 'get'
                    % 아무 작업 없음

                case 'reset'
                    storage.slots = [];
                    storage.isACK = [];
                    storage.SINR_dB = [];
                    storage.isAttackPhase = [];
            end

            data = storage;

        end


        %% ========== Target UT 정찰/공격 구간 비교 Summary ==========
        function printTargetUTSummary()

            data = DebugHelper.TargetUTStorage('get', []);

            if isempty(data.slots)
                fprintf('기록된 Target UT 데이터가 없습니다.\n');
                return;
            end

            attackIdx = logical(data.isAttackPhase);
            reconIdx = ~attackIdx;
            isACK = logical(data.isACK);

            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('TARGET UT THROUGHPUT SUMMARY (Reconnaissance vs Attack)\n');
            fprintf('============================================================\n');

            fprintf('  Total Slots               : %d\n', numel(data.slots));
            fprintf('  Reconnaissance Slots      : %d\n', sum(reconIdx));
            fprintf('  Attack Slots              : %d\n', sum(attackIdx));

            fprintf('\n');
            fprintf('  [ACK Rate]\n');
            fprintf('    Reconnaissance Phase   : %.2f %%\n', mean(isACK(reconIdx)) * 100);

            if any(attackIdx)
                fprintf('    Attack Phase           : %.2f %%\n', mean(isACK(attackIdx)) * 100);
            else
                fprintf('    Attack Phase           : N/A (no attack slots yet)\n');
            end

            fprintf('\n');
            fprintf('  [Mean SINR]\n');
            fprintf('    Reconnaissance Phase   : %.3f dB\n', mean(data.SINR_dB(reconIdx)));

            if any(attackIdx)
                fprintf('    Attack Phase           : %.3f dB\n', mean(data.SINR_dB(attackIdx)));
            else
                fprintf('    Attack Phase           : N/A\n');
            end

            fprintf('============================================================\n');

        end


        %% ========== Target UT ACK Rate 추이 그래프 ==========
        function plotTargetUTThroughput(windowSize)

            if nargin < 1
                windowSize = 100;
            end

            data = DebugHelper.TargetUTStorage('get', []);

            if isempty(data.slots)
                fprintf('기록된 Target UT 데이터가 없습니다.\n');
                return;
            end

            slots = data.slots;
            ackHistory = double(data.isACK);
            attackPhase = logical(data.isAttackPhase);

            rollingACKRate = movmean(ackHistory, [windowSize-1, 0]);
            cumulativeACKRate = cumsum(ackHistory) ./ (1:numel(ackHistory));

            attackStartIdx = find(attackPhase, 1);

            figure;

            subplot(2,1,1);
            plot(slots, cumulativeACKRate * 100, 'LineWidth', 1.2);
            hold on;
            plot(slots, rollingACKRate * 100, 'LineWidth', 1.2);
            if ~isempty(attackStartIdx)
                xline(slots(attackStartIdx), '--r', 'Attack Start', 'LineWidth', 1.2);
            end
            hold off;
            xlabel('Time Slot');
            ylabel('ACK Rate (%)');
            title('Target UT ACK Rate over Time');
            legend('Cumulative', sprintf('Rolling (window=%d)', windowSize), 'Location', 'southwest');
            grid on;
            ylim([0 100]);

            subplot(2,1,2);
            rollingSINR = movmean(data.SINR_dB, [windowSize-1, 0]);
            plot(slots, rollingSINR, 'LineWidth', 1.2);
            hold on;
            if ~isempty(attackStartIdx)
                xline(slots(attackStartIdx), '--r', 'Attack Start', 'LineWidth', 1.2);
            end
            hold off;
            xlabel('Time Slot');
            ylabel('SINR (dB)');
            title(sprintf('Target UT SINR over Time (Rolling window=%d)', windowSize));
            grid on;

        end


        %% ========== APJ Channel Prediction 최종 Summary ==========
        function printAPJPredictionSummary(numChannels)

            data = DebugHelper.APJPredictionStorage('get', []);

            predicted = data.predicted;
            actual = data.actual;
            slots = data.slots;

            totalCount = numel(actual);

            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('APJ CHANNEL PREDICTION SUMMARY\n');
            fprintf('============================================================\n');

            if totalCount == 0
                fprintf('  No prediction samples recorded.\n');
                fprintf('============================================================\n');
                return;
            end

            correctCount = sum(predicted == actual);
            incorrectCount = totalCount - correctCount;
            accuracy = correctCount / totalCount;
            randomBaseline = 1 / numChannels;

            fprintf('  Number of Channels       : %d\n', numChannels);
            fprintf('  Prediction Samples       : %d\n', totalCount);
            fprintf('  First Evaluated Slot     : %d\n', slots(1));
            fprintf('  Last Evaluated Slot      : %d\n', slots(end));

            fprintf('\n');
            fprintf('  [Overall Prediction Performance]\n');
            fprintf('    Correct Predictions    : %d\n', correctCount);
            fprintf('    Wrong Predictions      : %d\n', incorrectCount);
            fprintf('    Accuracy               : %6.2f %%\n', accuracy * 100);
            fprintf('    Random Baseline        : %6.2f %%\n', randomBaseline * 100);
            fprintf('    Improvement over Random: %6.2f x\n', accuracy / randomBaseline);

            recentWindow = min(100, totalCount);
            recentPredicted = predicted(end-recentWindow+1:end);
            recentActual = actual(end-recentWindow+1:end);
            recentAccuracy = mean(recentPredicted == recentActual);

            fprintf('\n');
            fprintf('  [Recent Performance]\n');
            fprintf('    Window Size            : %d\n', recentWindow);
            fprintf('    Accuracy               : %6.2f %%\n', recentAccuracy * 100);

            fprintf('\n');
            fprintf('  [Per-Channel Prediction Performance]\n');

            for ch = 1:numChannels
                actualCount = sum(actual == ch);
                predictedCount = sum(predicted == ch);
                correctChannelCount = sum((predicted == ch) & (actual == ch));

                if actualCount > 0
                    channelRecall = correctChannelCount / actualCount;
                    fprintf(['    CH %2d | Actual: %4d | Predicted: %4d | ' ...
                        'Correct: %4d | Recall: %6.2f %%\n'], ...
                        ch, actualCount, predictedCount, correctChannelCount, channelRecall * 100);
                else
                    fprintf(['    CH %2d | Actual: %4d | Predicted: %4d | ' ...
                        'Correct: %4d | Recall:   N/A\n'], ...
                        ch, actualCount, predictedCount, correctChannelCount);
                end
            end

            fprintf('============================================================\n');

        end


        %% ========== APJ Prediction Accuracy 추이 그래프 ==========
        function plotAPJAccuracyTrend(windowSize)

            if nargin < 1
                windowSize = 100;
            end

            data = DebugHelper.APJPredictionStorage('get', []);

            predicted = data.predicted;
            actual = data.actual;
            slots = data.slots;

            if isempty(slots)
                fprintf('기록된 예측 데이터가 없습니다.\n');
                return;
            end

            correctHistory = double(predicted == actual);

            cumulativeAccuracy = cumsum(correctHistory) ./ (1:numel(correctHistory));
            rollingAccuracy = movmean(correctHistory, [windowSize-1, 0]);

            figure;
            plot(slots, cumulativeAccuracy * 100, 'LineWidth', 1.2);
            hold on;
            plot(slots, rollingAccuracy * 100, 'LineWidth', 1.2);
            yline(100 / max(actual), '--', 'Random Baseline');
            hold off;

            xlabel('Time Slot');
            ylabel('Accuracy (%)');
            title('APJ Channel Prediction Accuracy over Time');
            legend('Cumulative Accuracy', sprintf('Rolling Accuracy (window=%d)', windowSize), 'Location', 'southeast');
            grid on;
            ylim([0 100]);

        end


        %% ========== APJ Prediction Storage 초기화 ==========
        function data = APJPredictionStorage_unused()
            data = [];
        end

    end
end