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

    end
end