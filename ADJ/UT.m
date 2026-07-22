classdef UT < Node
    properties
        IsTarget = false
        SelectedChannel
    end

    methods
        % ========== 생성자 ========== %
        function obj = UT(id, position, txPower_dBm, isTarget)
            obj@Node(id, position, txPower_dBm);
            obj.IsTarget = isTarget;
            obj.SelectedChannel = 1;
        end
    end
end