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
            fprintf('\n');
            fprintf('========== Channel Information ==========\n');
            fprintf('\n[Service Channels]\n');

            for k = 1:numel(ServiceChannels)
                fprintf('Channel %2d | Type: %s\n', ...
                    ServiceChannels(k).Id, ...
                    string(ServiceChannels(k).Type));
            end

            fprintf('\n[Control Channels]\n');

            for k = 1:numel(ControlChannels)
                fprintf('Channel %2d | Type: %s\n', ...
                    ControlChannels(k).Id, ...
                    string(ControlChannels(k).Type));
            end

            fprintf('=========================================\n');

        end


    end

end