classdef (Abstract) Node < handle
    properties
        Id
        Position
        TxPower_dBm
    end

    methods
        % ========== 생성자 ==========
        function obj = Node(id, position, txPower_dBm)
            obj.Id = id;
            obj.Position = position(:);
            obj.TxPower_dBm = txPower_dBm;
        end


        % ========== 위치 반환 ==========
        function Position = getPosition(obj)
            Position = obj.Position; % Access the Position property
        end



        % ========== 거리차이 계산 ==========
        function distance = distanceTo(obj, otherNode)
            distance = norm(obj.Position - otherNode.Position);
        end


    end

end