classdef APJ < Node
    properties
        TargetUTId

        TxPower_dBm
        NoiseTemperature
        NoiseFigure_dB

        ObservedChannel
        PredictedChannel
        JammingChannel

        SINRThreshold_dB


        ObservationManager
        StateManager
        Agent
    end

    methods
        % ========== 생성자 ==========
        function obj = APJ(id, position, targetUTId)
            env;

            obj@Node(id, NodeType.APJ, position);

            obj.TargetUTId = targetUTId;

            obj.TxPower_dBm = apjTxPower_dBm;
            obj.RxGain_dBi = apjRxGain_dBi;

            obj.NoiseTemperature = noiseTemperature;
            obj.NoiseFigure_dB = apjNoiseFigure_dB;

            obj.SINRThreshold_dB = apjSINRThreshold_dB;

            obj.ObservedChannel = [];
            obj.PredictedChannel = [];
            obj.JammingChannel = [];

            obj.ObservationManager = ObservationManager(obj, numChannels);


        end
    end
end