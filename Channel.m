classdef Channel < handle
    properties
        id
        centerFreq
        bandwidth

        signals
    end

    methods
        %========== 채널 생성자 ==========
        function obj = Channel(id, centerFreq, bandwidth)
            obj.id = id;
            obj.centerFreq = centerFreq;
            obj.bandwidth = bandwidth;
            obj.signals = {};
        end

        %========== 채널 상태 초기화 ==========
        function reset(obj)
            obj.signals = {};
        end

        %========== Signal 추가 ==========
        function addSignal(obj, signal)
            obj.signals{end+1} = signal;
        end

        %========== Signal 가져오기 ==========
        function signals = getSignal(obj)
            signals = obj.signals;
        end



    end

end