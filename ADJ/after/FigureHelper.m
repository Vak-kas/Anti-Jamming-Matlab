classdef FigureHelper
    methods (Static)

        % ============================================================
        % 전체 시스템 배치 출력
        % ============================================================
        function plotSystemDeployment( ...
                SatelliteNode, ...
                Beams, ...
                UTs, ...
                APJNode, ...
                maxBeamFootprintDiameter)

            %% =====================================================
            % Figure 생성
            % ======================================================
            figure( ...
                'Name', 'System Deployment', ...
                'NumberTitle', 'off', ...
                'Units', 'normalized', ...
                'Position', [0.03 0.05 0.88 0.88] ...
            );

            hold on;
            grid on;
            axis equal;
            box on;

            ax = gca;

            ax.FontSize = 12;
            ax.LineWidth = 1;
            ax.TickDir = 'out';

            % Grid를 너무 진하지 않게
            ax.GridAlpha = 0.15;
            ax.MinorGridAlpha = 0.10;

            theta = linspace(0, 2*pi, 500);


            %% =====================================================
            % Satellite Beam Footprint
            % ======================================================
            footprintRadius_km = ...
                (maxBeamFootprintDiameter / 2) / 1e3;

            footprintX = ...
                footprintRadius_km * cos(theta);

            footprintY = ...
                footprintRadius_km * sin(theta);

            hFootprint = plot( ...
                footprintX, ...
                footprintY, ...
                'k--', ...
                'LineWidth', 2 ...
            );


            %% =====================================================
            % Beam 영역
            % ======================================================
            hBeam = [];
            hBeamCenter = [];

            for beamIndex = 1:numel(Beams)

                beam = Beams(beamIndex);

                centerX_km = ...
                    beam.CenterPosition(1) / 1e3;

                centerY_km = ...
                    beam.CenterPosition(2) / 1e3;

                radius_km = ...
                    beam.Radius / 1e3;


                % Beam 원
                beamX = ...
                    centerX_km ...
                    + radius_km * cos(theta);

                beamY = ...
                    centerY_km ...
                    + radius_km * sin(theta);


                % Beam 경계
                currentBeam = plot( ...
                    beamX, ...
                    beamY, ...
                    'b-', ...
                    'LineWidth', 1.0 ...
                );


                % Beam 중심
                currentCenter = plot( ...
                    centerX_km, ...
                    centerY_km, ...
                    'bx', ...
                    'MarkerSize', 8, ...
                    'LineWidth', 1.5 ...
                );


                % Legend는 첫 번째 Beam만 사용
                if beamIndex == 1
                    hBeam = currentBeam;
                    hBeamCenter = currentCenter;
                end

            end


            %% =====================================================
            % UT 위치
            % ======================================================
            hUT = [];
            hTargetUT = [];

            for utIndex = 1:numel(UTs)

                ut = UTs(utIndex);

                utX_km = ...
                    ut.Position(1) / 1e3;

                utY_km = ...
                    ut.Position(2) / 1e3;


                % Target UT
                if ut.IsTarget

                    hTargetUT = plot( ...
                        utX_km, ...
                        utY_km, ...
                        'r*', ...
                        'MarkerSize', 13, ...
                        'LineWidth', 2 ...
                    );

                % Normal UT
                else

                    currentUT = plot( ...
                        utX_km, ...
                        utY_km, ...
                        'ko', ...
                        'MarkerSize', 6, ...
                        'MarkerFaceColor', 'w', ...
                        'LineWidth', 1.2 ...
                    );

                    % Legend는 첫 번째 Normal UT만 사용
                    if isempty(hUT)
                        hUT = currentUT;
                    end

                end

            end


            %% =====================================================
            % APJ 위치
            % ======================================================
            hAPJ = [];

            if ~isempty(APJNode)

                apjX_km = ...
                    APJNode.Position(1) / 1e3;

                apjY_km = ...
                    APJNode.Position(2) / 1e3;


                hAPJ = plot( ...
                    apjX_km, ...
                    apjY_km, ...
                    'md', ...
                    'MarkerSize', 10, ...
                    'MarkerFaceColor', 'm', ...
                    'LineWidth', 1.5 ...
                );


                %% -------------------------------------------------
                % Target UT ↔ APJ 연결선
                % --------------------------------------------------
                targetUT = ...
                    UTs(APJNode.TargetUTId);

                targetX_km = ...
                    targetUT.Position(1) / 1e3;

                targetY_km = ...
                    targetUT.Position(2) / 1e3;


                plot( ...
                    [targetX_km apjX_km], ...
                    [targetY_km apjY_km], ...
                    'm--', ...
                    'LineWidth', 1.2, ...
                    'HandleVisibility', 'off' ...
                );

            end


            %% =====================================================
            % Satellite Ground Projection
            % ======================================================
            satelliteX_km = ...
                SatelliteNode.Position(1) / 1e3;

            satelliteY_km = ...
                SatelliteNode.Position(2) / 1e3;


            hSatellite = plot( ...
                satelliteX_km, ...
                satelliteY_km, ...
                'ks', ...
                'MarkerSize', 11, ...
                'MarkerFaceColor', 'k', ...
                'LineWidth', 1.2 ...
            );


            %% =====================================================
            % Axis 설정
            % ======================================================
            margin_km = 30;

            xlim([ ...
                -footprintRadius_km - margin_km, ...
                 footprintRadius_km + margin_km ...
            ]);

            ylim([ ...
                -footprintRadius_km - margin_km, ...
                 footprintRadius_km + margin_km ...
            ]);


            xlabel( ...
                'X Position [km]', ...
                'FontSize', 13 ...
            );

            ylabel( ...
                'Y Position [km]', ...
                'FontSize', 13 ...
            );


            title( ...
                'Satellite Beam and Ground Node Deployment', ...
                'FontSize', 15, ...
                'FontWeight', 'bold' ...
            );


            %% =====================================================
            % Legend 생성
            % ======================================================
            legendHandles = [];
            legendLabels = {};


            % Beam Footprint
            legendHandles(end+1) = ...
                hFootprint;

            legendLabels{end+1} = ...
                'Beam footprint boundary';


            % Beam
            if ~isempty(hBeam)

                legendHandles(end+1) = ...
                    hBeam;

                legendLabels{end+1} = ...
                    'Beam';

            end


            % Beam Center
            if ~isempty(hBeamCenter)

                legendHandles(end+1) = ...
                    hBeamCenter;

                legendLabels{end+1} = ...
                    'Beam center';

            end


            % Normal UT
            if ~isempty(hUT)

                legendHandles(end+1) = ...
                    hUT;

                legendLabels{end+1} = ...
                    'UT';

            end


            % Target UT
            if ~isempty(hTargetUT)

                legendHandles(end+1) = ...
                    hTargetUT;

                legendLabels{end+1} = ...
                    'Target UT';

            end


            % APJ
            if ~isempty(hAPJ)

                legendHandles(end+1) = ...
                    hAPJ;

                legendLabels{end+1} = ...
                    'APJ';

            end


            % Satellite
            legendHandles(end+1) = ...
                hSatellite;

            legendLabels{end+1} = ...
                'Satellite ground projection';


            legend( ...
                legendHandles, ...
                legendLabels, ...
                'Location', 'eastoutside', ...
                'FontSize', 10 ...
            );


            hold off;

        end


        % ============================================================
        % Beam1(Target UT) 실시간 성공률(ACK ratio) 출력
        % ------------------------------------------------------------
        % 호출 예 (TimeSlot.run 등에서 한 줄만 추가):
        %   FigureHelper.plotBeam1SuccessRate(slotIndex, actualTargetACK);
        %
        % persistent 변수로 Figure/버퍼 상태를 유지하므로,
        % 매 슬롯 이 한 줄만 호출하면 알아서 창을 만들고 갱신합니다.
        % ============================================================
        function plotBeam1SuccessRate(slotIndex, isACK, shortWindow, emaSpan)
            % 하위 호환용 wrapper — 내부적으로 plotSuccessRate 호출
            if nargin < 3, shortWindow = []; end
            if nargin < 4, emaSpan = []; end
            FigureHelper.plotSuccessRate(slotIndex, isACK, 'Beam1 (Target UT)', shortWindow, emaSpan);
        end

        % ============================================================
        % 임의의 지표(0~1 사이 값)에 대한 실시간 성공률 플롯 (범용)
        % ------------------------------------------------------------
        % 호출 예:
        %   FigureHelper.plotSuccessRate(slotIndex, actualTargetACK, 'Beam1 (Target UT)');
        %   FigureHelper.plotSuccessRate(slotIndex, successRatio, 'All UTs (Aggregate)');
        %
        % seriesName마다 별도 Figure/버퍼 상태를 유지하므로(내부적으로
        % containers.Map 사용), 같은 파일에서 여러 지표를 동시에
        % 각자의 창에 실시간으로 그릴 수 있습니다.
        % ============================================================
        function plotSuccessRate(slotIndex, value, seriesName, shortWindow, emaSpan)

            persistent stateMap

            if nargin < 4 || isempty(shortWindow)
                shortWindow = 100;
            end
            if nargin < 5 || isempty(emaSpan)
                emaSpan = 200;
            end
            alpha = 2 / (emaSpan + 1);

            if isempty(stateMap)
                stateMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            %% =====================================================
            % 이 seriesName의 Figure 최초 1회 생성
            % ======================================================
            needsInit = ~isKey(stateMap, seriesName);
            if ~needsInit
                s = stateMap(seriesName);
                needsInit = ~isvalid(s.figHandle);
            end

            if needsInit
                s = struct();

                s.figHandle = figure( ...
                    'Name', sprintf('%s 실시간 성공률', seriesName), ...
                    'NumberTitle', 'off' ...
                );

                s.axHandle = axes(s.figHandle);
                hold(s.axHandle, 'on');
                grid(s.axHandle, 'on');
                s.axHandle.GridAlpha = 0.15;

                ylim(s.axHandle, [0 1]);
                xlabel(s.axHandle, 'Time Slot', 'FontSize', 12);
                ylabel(s.axHandle, sprintf('%s Ratio', seriesName), 'FontSize', 12);
                title(s.axHandle, ...
                    sprintf('%s 실시간 성공률', seriesName), ...
                    'FontSize', 14, 'FontWeight', 'bold');

                s.rawLine = animatedline(s.axHandle, ...
                    'LineStyle', 'none', ...
                    'Marker', '.', ...
                    'MarkerSize', 4, ...
                    'Color', [0.85 0.85 0.85], ...
                    'DisplayName', 'Per-slot value');

                % 노이즈 많은 실시간 곡선 → 회색, 얇게
                s.shortLine = animatedline(s.axHandle, ...
                    'Color', [0.55 0.55 0.55], ...
                    'LineWidth', 1.0, ...
                    'DisplayName', sprintf('Noisy rolling (window=%d)', shortWindow));

                % 매끈한 평균 곡선 → 파란색, 굵게 (EMA)
                s.longLine = animatedline(s.axHandle, ...
                    'Color', [0.00 0.30 0.80], ...
                    'LineWidth', 2.2, ...
                    'DisplayName', sprintf('Smoothed EMA (span=%d)', emaSpan));

                legend(s.axHandle, 'Location', 'southeast');

                s.history = [];
                s.emaValue = [];

                stateMap(seriesName) = s;
            end

            s = stateMap(seriesName);

            %% =====================================================
            % 짧은 윈도우(노이즈) 갱신
            % ======================================================
            s.history(end+1) = double(value); %#ok<AGROW>
            n = numel(s.history);
            shortRatio = mean(s.history(max(1, n-shortWindow+1):n));

            addpoints(s.rawLine, slotIndex, double(value));
            addpoints(s.shortLine, slotIndex, shortRatio);

            %% =====================================================
            % EMA 갱신 — 첫 슬롯부터 바로 값이 생김 (대기 없음)
            % ======================================================
            if isempty(s.emaValue)
                s.emaValue = double(value);
            else
                s.emaValue = alpha * double(value) + (1 - alpha) * s.emaValue;
            end
            addpoints(s.longLine, slotIndex, s.emaValue);

            xlim(s.axHandle, [1, max(slotIndex, shortWindow)]);

            if mod(slotIndex, 5) == 0 || slotIndex == 1
                drawnow limitrate;
            end

            stateMap(seriesName) = s;

        end


        function plotBeamAPJGreedyAgreement()

            data = ...
                DebugHelper.beamAPJQAgreementData( ...
                    'get', ...
                    [] ...
                );
        
        
            if isempty(data.Slot)
                return;
            end
        
        
            matchHistory = ...
                double( ...
                    data.BeamGreedy == data.APJGreedy ...
                );
        
        
            windowSize = 100;
        
        
            movingAgreement = ...
                movmean( ...
                    matchHistory, ...
                    [windowSize-1 0] ...
                );
        
        
            figure;
        
            plot( ...
                data.Slot, ...
                movingAgreement * 100, ...
                'LineWidth', ...
                1.5 ...
            );
        
        
            xlabel('Time Slot');
        
            ylabel('Greedy Agreement (%)');
        
            title( ...
                sprintf( ...
                    'Beam1-APJ Greedy Policy Agreement (Moving Window = %d)', ...
                    windowSize ...
                ) ...
            );
        
            ylim([0 100]);
        
            grid on;
        
        end
    
        function plotBeamAPJQMAE()
        
            data = ...
                DebugHelper.beamAPJQAgreementData( ...
                    'get', ...
                    [] ...
                );
        
        
            if isempty(data.Slot)
                return;
            end
        
        
            windowSize = 100;
        
        
            movingQMAE = ...
                movmean( ...
                    data.QMAE, ...
                    [windowSize-1 0] ...
                );
        
        
            figure;
        
            plot( ...
                data.Slot, ...
                movingQMAE, ...
                'LineWidth', ...
                1.5 ...
            );
        
        
            xlabel('Time Slot');
        
            ylabel('Q-Value MAE');
        
            title( ...
                sprintf( ...
                    'Beam1-APJ Q-Value MAE (Moving Window = %d)', ...
                    windowSize ...
                ) ...
            );
        
            grid on;
        
        end
    

        function plotBeamAPJCosineSimilarity()

            data = ...
                DebugHelper.beamAPJQAgreementData( ...
                    'get', ...
                    [] ...
                );
        
        
            if isempty(data.Slot)
                return;
            end
        
        
            windowSize = 100;
        
        
            movingCosine = ...
                movmean( ...
                    data.Cosine, ...
                    [windowSize-1 0], ...
                    'omitnan' ...
                );
        
        
            figure;
        
            plot( ...
                data.Slot, ...
                movingCosine, ...
                'LineWidth', ...
                1.5 ...
            );
        
        
            xlabel('Time Slot');
        
            ylabel('Cosine Similarity');
        
            title( ...
                sprintf( ...
                    'Beam1-APJ Q-Vector Cosine Similarity (Moving Window = %d)', ...
                    windowSize ...
                ) ...
            );
        
            ylim([0 1]);
        
            grid on;
        
        end
    
        function plotBeamAPJQCorrelation()
    
        data = ...
            DebugHelper.beamAPJQAgreementData( ...
                'get', ...
                [] ...
            );
    
    
        if isempty(data.Slot)
            return;
        end
    
    
        windowSize = 100;
    
    
        movingCorrelation = ...
            movmean( ...
                data.Correlation, ...
                [windowSize-1 0], ...
                'omitnan' ...
            );
    
    
        figure;
    
        plot( ...
            data.Slot, ...
            movingCorrelation, ...
            'LineWidth', ...
            1.5 ...
        );
    
    
        xlabel('Time Slot');
    
        ylabel('Pearson Correlation');
    
        title( ...
            sprintf( ...
                'Beam1-APJ Q-Vector Correlation (Moving Window = %d)', ...
                windowSize ...
            ) ...
        );
    
        ylim([-1 1]);
    
        grid on;
    
    end
    
    
    end
end