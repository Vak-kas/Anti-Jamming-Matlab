classdef Jammer < Node
    methods
        %========== 생성자 ==========
        function obj = Jammer(id, FHP)
            obj@Node(id, FHP)
        end

        function jam(obj, power)
            sig = Signal(SignalType.JAMMING, [], power, obj.id, obj.currentChannel.id);
            obj.currentChannel.addSignal(sig);
        end
    end
end