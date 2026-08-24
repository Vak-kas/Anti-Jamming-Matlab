clc;
clear;
clear variables;
clear DebugHelper;
close all;

%% ==================== Environment Settings ====================
env;

%% ==================== 채널 생성 ====================
ServiceChannels = Channel.empty(0, numChannels);
ControlChannels = Channel.empty(0, numChannels);

for k = 1:numChannels
    centerFreq_Hz = serviceBandStart_Hz + (k-0.5) * channelSpacing_Hz;
    serviceChannelStart_Hz = centerFreq_Hz - channelBandwidth_Hz/2;
    serviceChannelEnd_Hz   = centerFreq_Hz + channelBandwidth_Hz/2;
    ServiceChannels(k) = Channel(k, ChannelType.Service, serviceChannelStart_Hz, serviceChannelEnd_Hz);
    ControlChannels(k) = Channel(k, ChannelType.Control, 1, 2);
end

%% ==================== Satellite 생성 ====================
satellitePosition = [0 0 satelliteAltitude];
SatelliteNode = Satellite(9999, satellitePosition, numBeams);

%%  ==================== Beam 생성 ====================
Beams = BeamFactory.createBeams(numBeams, maxBeamFootprintDiameter, beamRadius, beamSpacing, beamMaxGain_dBi, beam3dBWidth_deg, beamEIRPDensity_dBW_per_MHz, channelBandwidth_Hz);

for beamIndex = 1:numBeams
    SatelliteNode.addBeam(Beams(beamIndex));
end

%%  ==================== UT 생성 ====================
UTs = UTFactory.createUTs(Beams, numUTs);

%% ===================== APJ 생성 =====================
APJNode = APJFactory.createAPJ(UTs, Beams, targetUTId, targetJammerDistance);

%% ==================== Time Slot 루프 ====================
timeSlot = TimeSlot();

for slotIndex = 1:numTimeSlots
    timeSlot.run(slotIndex, UTs, SatelliteNode, APJNode, ServiceChannels, ControlChannels);
end


%% ==================== 결과 요약 / 그래프 ====================
DebugHelper.printTargetUTSummary();
DebugHelper.plotTargetUTThroughput(100);

DebugHelper.printAPJPredictionSummary(numel(ServiceChannels));
DebugHelper.plotAPJAccuracyTrend(100);