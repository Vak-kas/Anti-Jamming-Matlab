classdef BeamFactory
    methods (Static)
        % ========== 빔 전체 생성 ==========
        function beams = createBeams(numBeams, maxBeamFootprintDiameter, beamRadius, beamMaxGain_dBi, beam3dBWidth_deg, beamEIRPDensity_dBW_per_MHz, channelBandwidth_Hz)
            
            beamDiameter = beamRadius * 2;

            maxBeamCenterRadius = (maxBeamFootprintDiameter / 2) - beamRadius; % Beam 전체가 Satellite coverage 내부에 포함되도록 제한
            minimumBeamSpacing = beamDiameter; % Beam끼리 겹치지 않도록 최소 중심 거리 설정

            % Beam Tx Power 계산
            beamTxPower_dBm = BeamFactory.calculateBeamTxPower_dBm(beamEIRPDensity_dBW_per_MHz, channelBandwidth_Hz, beamMaxGain_dBi);

            % Beam 중심 좌표 생성
            beamCenters = BeamFactory.generateBeamCenters(numBeams, maxBeamCenterRadius, minimumBeamSpacing);

            % Beam 배열 생성
            beams = Beam.empty(0, numBeams);

            for beamIndex = 1:numBeams
                associatedUTId = beamIndex;
                beams(beamIndex) = Beam(beamIndex, beamCenters(beamIndex, :), beamRadius, beamTxPower_dBm, beamMaxGain_dBi, beam3dBWidth_deg, associatedUTId);
            end

        end


        % ========== Beam 중심 좌표 생성 ==========
        function beamCenters = generateBeamCenters(numBeams, maxBeamCenterRadius, minimumBeamSpacing)
            beamCenters = zeros(numBeams, 3); %[x y z]
            maxPlacementAttempts = 10000;

             for beamIndex = 1:numBeams
                isPlaced = false;
                attemptCount = 0;

                while ~isPlaced

                    attemptCount = attemptCount + 1;

                    if attemptCount > maxPlacementAttempts
                        error("BeamFactory:PlacementFailed", "Beam %d를 배치하지 못했습니다.", beamIndex);
                    end

                    % Satellite coverage 내부에서 랜덤 중심 생성

                    % sqrt(rand())를 사용하면

                    % 원 내부에서 면적 기준 균일 분포가 됨

                    randomRadius = sqrt(rand()) * maxBeamCenterRadius;
                    randomAngle = 2 * pi * rand();

                    x = randomRadius * cos(randomAngle);
                    y = randomRadius * sin(randomAngle);
                    z = 0;
                    candidateCenter = [x y z];

                    % 기존 Beam과 겹치는지 검사

                    if beamIndex == 1
                        isPlaced = true;
                    else
                        existingCenters = beamCenters(1:beamIndex-1, 1:2);
                        candidateXY = candidateCenter(1:2);
                        distances = sqrt(sum((existingCenters - candidateXY).^2, 2));

                        % 모든 Beam과 최소 거리 이상 떨어져 있는 경우만 배치
                        if all(distances >= minimumBeamSpacing)
                            isPlaced = true;
                        end
                    end

                end
             
                beamCenters(beamIndex, :) = candidateCenter; % 최종 Beam 중심 저장

            end
        end


        % ========== EIRP Density 기반 Beam Tx Power 계산 ==========
         function beamTxPower_dBm = calculateBeamTxPower_dBm(beamEIRPDensity_dBW_per_MHz, channelBandwidth_Hz, beamMaxGain_dBi)
            channelBandwidth_MHz = channelBandwidth_Hz / 1e6; %Hz -> MHz
            beamEIRP_dBW = beamEIRPDensity_dBW_per_MHz + 10 * log10(channelBandwidth_MHz); % EIRP = EIRP Density + 10log10(BW_MHz)

            % EIRP -> 실제 Beam Tx Power  = EIRP[dBW] = Tx Power[dBW] + Antenna Gain[dBi]
            beamTxPower_dBW = beamEIRP_dBW - beamMaxGain_dBi;
            beamTxPower_dBm = beamTxPower_dBW + 30;


        end

    end

end