classdef Beam < handle
    properties
        Id

        % ========== Geometry ==========
        CenterPosition          % 지상 Beam 중심 [x y 0]
        Radius                  % Beam 반경 [m]

        % ========== Antenna ==========
        MaxTxGain_dBi           % 최대 Tx Gain
        Beamwidth3dB_deg        % 3 dB Beamwidth [deg]

        % ========== Transmission ==========
        TxPower_dBm
        SelectedChannel

        % ========== Association ==========
        AssociatedUTId

        % ========== DRL ==========
        Agent
        ObservationManager
    end

    methods
        % ========== 생성자 ==========
        function obj = Beam(id, centerPosition, radius, txPower_dBm, maxTxGain_dBi, beamwidth3dB_deg, associatedUTId)
            obj.Id = id;

            obj.CenterPosition = centerPosition;
            obj.Radius = radius;

            obj.MaxTxGain_dBi = maxTxGain_dBi;
            obj.Beamwidth3dB_deg = beamwidth3dB_deg;

            obj.TxPower_dBm = txPower_dBm;
            obj.SelectedChannel = 1;

            obj.AssociatedUTId = associatedUTId;

            obj.Agent = [];
            obj.ObservationManager = [];
        end

        % ========== 빔 중심 주파수 가져오기 ==========
        function position = getCenterPosition(obj)
            position = obj.CenterPosition;
        end

        % ========== Beam 중심으로부터 지상 거리 계산 ==========
        function distance = groundDistanceTo(obj, position)
            beamCenter = obj.CenterPosition(:);
            position = position(:);
            distance = norm(beamCenter(1:2) - position(1:2));
        end
    end
end