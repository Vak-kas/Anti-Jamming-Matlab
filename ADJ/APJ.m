classdef APJ < Node
    properties
        TargetUTId
        SelectChannel
    end

    methods
        % ========== 생성자 ========== %
        function obj = APJ(id, position, txPower_dBm, targetUTid)
            obj@Node(id, position, txPower_dBm);
            obj.TargetUTId = targetUTid;
        end
    end

end