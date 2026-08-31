classdef APJDFactory
    methods (Static)

        %% ========== APJD 생성 ==========
        function APJDNode = createAPJD( ...
                UTs, ...
                Beams, ...
                targetUTId, ...
                targetJammerDistance)

            % Target UT
            targetUT = UTs(targetUTId);

            % Target UT 위치
            targetPosition = targetUT.getPosition();

            % Target UT가 속한 Beam
            targetBeam = Beams(targetUT.AssociatedBeamId);

            % APJD 위치 생성
            apjdPosition = ...
                APJDFactory.generateAPJDPosition( ...
                    targetPosition, ...
                    targetBeam, ...
                    targetJammerDistance);

            % APJD 객체 생성
            APJDNode = ...
                APJD( ...
                    1001, ...
                    apjdPosition, ...
                    targetUTId);
        end


        %% ========== APJD 위치 생성 ==========
        function position = generateAPJDPosition( ...
                targetPosition, ...
                targetBeam, ...
                targetJammerDistance)

            maxPlacementAttempts = 10000;

            isPlaced = false;
            attemptCount = 0;

            while ~isPlaced

                attemptCount = attemptCount + 1;

                % 최대 시도 횟수 초과
                if attemptCount > maxPlacementAttempts

                    error( ...
                        "APJDFactory:PlacementFailed", ...
                        [ ...
                        "Target UT로부터 %.2f km 거리이면서 " ...
                        "Beam %d 내부인 APJD 위치를 찾지 못했습니다." ...
                        ], ...
                        targetJammerDistance / 1e3, ...
                        targetBeam.Id);
                end


                %% Target UT 기준 랜덤 방향 생성
                randomAngle = 2 * pi * rand();


                %% APJD 후보 위치
                x = ...
                    targetPosition(1) ...
                    + targetJammerDistance ...
                    * cos(randomAngle);

                y = ...
                    targetPosition(2) ...
                    + targetJammerDistance ...
                    * sin(randomAngle);

                z = 0;

                candidatePosition = [x y z];


                %% Target Beam 내부인지 검사
                distanceToBeamCenter = ...
                    targetBeam.groundDistanceTo( ...
                        candidatePosition);


                if distanceToBeamCenter <= targetBeam.Radius
                    isPlaced = true;
                end
            end


            %% 최종 APJD 위치
            position = candidatePosition;
        end

    end
end