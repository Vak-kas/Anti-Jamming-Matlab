classdef DebugHelper

    methods (Static)

        %% UT-Satellite 거리 체크용 
        function printAssociationDistances(UTs, Satellites)
            fprintf('\n');
            fprintf('========== UT-Satellite Distance ==========\n');

            for n = 1:numel(Satellites)
                utId = Satellites(n).AssociatedUTId;
                distance = UTs(utId).distanceTo(Satellites(n));
                fprintf(['Satellite %d - UT %d | ' ...
                         'Distance: %.2f km\n'], ...
                    Satellites(n).Id, ...
                    utId, ...
                    distance / 1e3);
            end

            fprintf('===========================================\n');
        end

        %% 채널 출력
        function printChannels(ServiceChannels, ControlChannels)
            fprintf('\n========== Channel Information ==========\n');
            fprintf('\n[Service Channels]\n');
        
            for k = 1:numel(ServiceChannels)
                fprintf('Channel %2d\n', ServiceChannels(k).Id);
                packets = ServiceChannels(k).Packets;
        
                if isempty(packets)
                    fprintf('    (Empty)\n');
                    continue;
                end
        
                for p = 1:numel(packets)
                    packet = packets(p);
        
                    fprintf('    %s | %s %d -> %s %d\n', ...
                        string(packet.Type), ...
                        string(packet.SourceType), packet.SourceId, ...
                        string(packet.DestinationType), packet.DestinationId);
        
                end
        
            end
        
            fprintf('\n[Control Channels]\n');

            for k = 1:numel(ControlChannels)
                fprintf('Channel %2d\n', ControlChannels(k).Id);
                packets = ControlChannels(k).Packets;
        
                if isempty(packets)
                    fprintf('    (Empty)\n');
                    continue;
                end
        
                for p = 1:numel(packets)
                    packet = packets(p);
                    fprintf('    %s | %s %d -> %s %d\n', ...
                        string(packet.Type), ...
                        string(packet.SourceType), packet.SourceId, ...
                        string(packet.DestinationType), packet.DestinationId);
                end
        
            end
        
            fprintf('=========================================\n');
        
        end


        %% SINR 디버깅 출력

        function printSINR(satelliteId, targetUTId, channelId, distance_m, receivedPower_W, interferencePower_W, noisePower_W, ...
                SINR_linear, SINR_dB, threshold_dB)

            receivedPower_dBm = DebugHelper.wattToDbm(receivedPower_W);
            noisePower_dBm = DebugHelper.wattToDbm(noisePower_W);

            if interferencePower_W > 0
                interferencePower_dBm = DebugHelper.wattToDbm(interferencePower_W);

            else
                interferencePower_dBm = -Inf;
            end

            if SINR_dB >= threshold_dB
                result = "ACK";
            else
                result = "NACK";
            end

            fprintf('\n');
            fprintf('========== SINR Debug ==========\n');
            fprintf('Satellite ID       : %d\n', satelliteId);
            fprintf('Target UT ID       : %d\n', targetUTId);
            fprintf('Channel ID         : %d\n', channelId);
            fprintf('Distance           : %.2f km\n', distance_m / 1e3);
            fprintf('Desired Power      : %.4e W | %.4f dBm\n', receivedPower_W, receivedPower_dBm);

            if interferencePower_W > 0
                fprintf('Interference Power : %.4e W | %.4f dBm\n',interferencePower_W, interferencePower_dBm);
            else
                fprintf('Interference Power : 0 W | -Inf dBm\n');
            end

            fprintf('Noise Power        : %.4e W | %.4f dBm\n',noisePower_W, noisePower_dBm);
            fprintf('SINR Linear        : %.4e\n', SINR_linear);
            fprintf('SINR dB            : %.4f dB\n', SINR_dB);
            fprintf('Threshold          : %.4f dB\n', threshold_dB);
            fprintf('HARQ Result        : %s\n', result);
            fprintf('================================\n');

        end

        %% W -> dBm 변환
        function power_dBm = wattToDbm(power_W)
            if power_W > 0
                power_dBm = 10 * log10(power_W) + 30;
            else
                power_dBm = -Inf;
            end
        end


    end

end