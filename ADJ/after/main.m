clc;
clear;
clear variables;
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
Beams = BeamFactory.createBeams(numBeams, maxBeamFootprintDiameter, beamRadius, beamMaxGain_dBi, beam3dBWidth_deg, beamEIRPDensity_dBW_per_MHz, channelBandwidth_Hz);

for beamIndex = 1:numBeams
    SatelliteNode.addBeam(Beams(beamIndex));
end


%%  ==================== UT 생성 ====================
UTs = UTFactory.createUTs(Beams, numUTs);


%% ===================== APJ 생성 =====================
APJNode = APJFactory.createAPJ(UTs, Beams, targetUTId, targetJammerDistance);


%% ==================== Debug ====================
% DebugHelper.printSatelliteInfo(SatelliteNode);
% DebugHelper.printUTInfo(UTs, Beams, SatelliteNode);
DebugHelper.printAPJInfo(APJNode, UTs, SatelliteNode);
% DebugHelper.printBeamUTAssociation(Beams, UTs);

%% ==================== Figure ====================
FigureHelper.plotSystemDeployment(SatelliteNode, Beams, UTs, APJNode, maxBeamFootprintDiameter);