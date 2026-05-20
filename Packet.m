classdef Packet
    properties
        srcId
        dstId
        payload
    end

    methods
        
        function obj = Packet(srcId, dstId, payload)
            obj.srcId = srcId;
            obj.dstId = dstId;
            obj.payload = payload;
        end

    end
end