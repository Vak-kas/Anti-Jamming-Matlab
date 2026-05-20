classdef Node < handle

    properties
        id
        currentChannel
        FHP
    end

    methods
        function obj = Node(id, FHP)
            obj.id = id;
            obj.FHP = FHP;

            obj.currentChannel = -1;
        end
    end

end