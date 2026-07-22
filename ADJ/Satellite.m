classdef Satellite < Node
    properties
        AssociatedUTId
        Threshold
    end

    methods
        % ========== 생성자 ========== %
        function obj = Satellite(id, position, txPower_dBm, associatedUTId, threshold)
            obj@Node(id, NodeType.Satellite, position, txPower_dBm);
            obj.AssociatedUTId = associatedUTId;
            obj.Threshold = threshold;
        end

        % ========== HARQ Feedback ========== %
        function feedback = generateHARQFeedback(obj, sinr)
            feedback = sinr > obj.Threshold; % Generate feedback based on SINR and threshold
        end
    end
end