clc;
clear all;
%%%%%%%%%%%%%%% Simulation Parameters %%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%% comb size 2 4 %%%%%%%%%%%%%%%%%% doppler added correctly
%%%%%%%%%%%%%%% two targets

nFrames = 1; % Number of 10 ms frames
fc = 25e9;    % Carrier frequency (Hz)
lambda = physconst('LightSpeed') / fc;  % Wavelength

% Configure UE position in xyz-coordinate plane
UEPos = [250 200 2]; % In meters. As per TR 38.901 Table 7.4.1-1,
                     
% the bistatic velocity and doppler freq
V_bis1 = 2; % 2m/s
freq_dop = 2*V_bis1/lambda;

V_bis2 = 10; %10 m/s
freq_dop2 = 2*V_bis2/lambda;


targetpos = [340 380 3];

targetpos2 = [400 420 3];

gNBPos = [0 0 20]; % Configure locate of gNb in xyz-coordinate plane


NTxAnt_x = 8;
NTxAnt_z = 8;

NRxAnt_x = 8;
NRxAnt_z = 8;

NTxAnts = NTxAnt_x *NTxAnt_z;       % Number of PDSCH transmission antennas (1,2,4,8,16,32,64,128,256,512,1024) >= NumLayers
NRxAnts = NRxAnt_x * NRxAnt_z; % Number of UE receive antennas (1 or even number >= NumLayers)

UEantennaPos = antennapos(NRxAnts,UEPos,lambda);
BSantennaPos = antennapos(NTxAnts,gNBPos,lambda);

DataType = 'single';    % Define data type ('single' or 'double') for resource grids and waveforms
SNRIn = [15]; % SNR range (dB)

DisplaySimulationInformation = true;



%%%%%%%%%%%%%% Configure carrier properties %%%%%%%%%%%%%%
Carrier = nrCarrierConfig;      % Carrier resource grid configuration
Carrier.NSizeGrid = 51;         % Bandwidth in number of resource blocks (51 RBs at 30 kHz SCS for 20 MHz BW)
Carrier.SubcarrierSpacing = 120;    % 15, 30, 60, 120 (kHz)
Carrier.CyclicPrefix = 'Normal';   % 'Normal' or 'Extended' (Extended CP is relevant for 60 kHz SCS only)
Carrier.NCellID = 1;               % Cell identity

%%%%%%%%%%%%% PRS Configuration %%%%%%%%%%%%%%%%%%%%%%%%%%%

prs = nrPRSConfig;
prs.PRSResourceSetPeriod = [80 0];
prs.PRSResourceOffset = 0:79;
prs.PRSResourceRepetition = 1;
prs.PRSResourceTimeGap = 1;
prs.MutingPattern1 = [];
prs.MutingPattern2 = [];
prs.NumRB = 51;
prs.RBOffset = 0;
prs.CombSize = 12;
prs.NumPRSSymbols = 12;
prs.SymbolStart = 1;
prs.REOffset = 0;

%%%%%%%%%%%%%%% PDSCH Configuration %%%%%%%%%%%%%%%%%%%%%%%%
PDSCH = nrPDSCHConfig;
PDSCH.PRBSet = 0:Carrier.NSizeGrid-1;          % PDSCH PRB allocation
PDSCH.MappingType = 'B';     % PDSCH mapping type ('A'(slot-wise),'B'(non slot-wise))
PDSCH.SymbolAllocation = [0,Carrier.SymbolsPerSlot-1];  % Starting symbol and number of symbols of each PDSCH allocation
PDSCH.VRBToPRBInterleaving = 0; % Disable interleaved resource mapping
PDSCH.VRBBundleSize = 4;
PDSCH.NumLayers = 1;            % Number of PDSCH transmission layers
PDSCH.Modulation = 'QPSK';          % 'QPSK', '16QAM', '64QAM', '256QAM'
PDSCHExtension.TargetCodeRate = 490/1024;         % Code rate used to calculate transport block sizes

PDSCHExtension.PRGBundleSize = [];     % 2, 4, or [] to signify "wideband"
PDSCH.RNTI = 1; % Scrambling identifiers
PDSCH.NID = Carrier.NCellID; % Scrambling identifiers

% Reserved PRB patterns, if required (for CORESETs, forward compatibility etc)
PDSCH.ReservedPRB{1}.SymbolSet = [];   % Reserved PDSCH symbols
PDSCH.ReservedPRB{1}.PRBSet = [];      % Reserved PDSCH PRBs
PDSCH.ReservedPRB{1}.Period = [];      % Periodicity of reserved resources



%%%%%%%%%%%%%% % DM-RS and antenna port configuration (TS 38.211 Section 7.4.1.1) %%%%%%%%%%%%%%%%%

PDSCH.DMRS.DMRSPortSet = 0:PDSCH.NumLayers-1; % DM-RS ports to use for the layers
% PDSCH.DMRS.DMRSTypeAPosition = 1;      % Mapping type A only. First DM-RS symbol position (2,3)
PDSCH.DMRS.DMRSLength = 1;             % Number of front-loaded DM-RS symbols (1(single symbol),2(double symbol))
PDSCH.DMRS.DMRSAdditionalPosition = 0; % Additional DM-RS symbol positions (max range 0...3)
PDSCH.DMRS.DMRSConfigurationType = 2;  % DM-RS configuration type (1,2)
PDSCH.DMRS.NumCDMGroupsWithoutData = 1;% Number of CDM groups without data
PDSCH.DMRS.NIDNSCID = 1;               % Scrambling identity (0...65535)
PDSCH.DMRS.NSCID = 0;                  % Scrambling initialization (0,1)

PDSCHExtension.LDPCDecodingAlgorithm = 'Normalized min-sum';    % LDPC decoder parameters
PDSCHExtension.MaximumLDPCIterationCount = 6;


%%%%%%%%%%%%%%% PT-RS configuration (TS 38.211 Section 7.4.1.2) %%%%%%%%%%%%%%% %%%%%%%%%%%
PDSCH.EnablePTRS = 0;                  % Enable or disable PT-RS (1 or 0)
PDSCH.PTRS.TimeDensity = 1;            % PT-RS time density (L_PT-RS) (1, 2, 4)
PDSCH.PTRS.FrequencyDensity = 2;       % PT-RS frequency density (K_PT-RS) (2 or 4)
PDSCH.PTRS.REOffset = '00';            % PT-RS resource element offset ('00', '01', '10', '11')
PDSCH.PTRS.PTRSPortSet = [];           % PT-RS antenna port, subset of DM-RS port set. Empty corresponds to lower DM-RS port number

%%%%%%%%%%%%%%%%%%%%%%%%


% HARQ process and rate matching/TBS parameters
PDSCHExtension.XOverhead = 6*PDSCH.EnablePTRS; % Set PDSCH rate matching overhead for TBS (Xoh) to 6 when PT-RS is enabled, otherwise 0
PDSCHExtension.NHARQProcesses = 16;    % Number of parallel HARQ processes to use
PDSCHExtension.EnableHARQ = false;      % Enable retransmissions for each process, using RV sequence [0,2,3,1]


% Array to store the maximum throughput for all SNR points
maxThroughput = zeros(length(SNRIn),1);
% Array to store the simulation throughput and BER for all SNR points
simThroughput = zeros(length(SNRIn),1);
numberbiterror = zeros(length(SNRIn),nFrames * Carrier.SlotsPerFrame);
errorratio = zeros(length(SNRIn),nFrames * Carrier.SlotsPerFrame);

% Set up redundancy version (RV) sequence for all HARQ processes
if PDSCHExtension.EnableHARQ
    % In the final report of RAN WG1 meeting #91 (R1-1719301), it was
    % observed in R1-1717405 that if performance is the priority, [0 2 3 1]
    % should be used. If self-decodability is the priority, it should be
    % taken into account that the upper limit of the code rate at which
    % each RV is self-decodable is in the following order: 0>3>2>1
    rvSeq = [0 2 3 1];
else
    % HARQ disabled - single transmission with RV=0, no retransmissions
    rvSeq = 0;
end


% Create DL-SCH encoder system object to perform transport channel encoding
encodeDLSCH = nrDLSCH;
encodeDLSCH.MultipleHARQProcesses = true;
encodeDLSCH.TargetCodeRate = PDSCHExtension.TargetCodeRate;


% Create DL-SCH decoder system object to perform transport channel decoding
% Use layered belief propagation for LDPC decoding, with half the number of
% iterations as compared to the default for belief propagation decoding
decodeDLSCH = nrDLSCHDecoder;
decodeDLSCH.MultipleHARQProcesses = true;
decodeDLSCH.TargetCodeRate = PDSCHExtension.TargetCodeRate;
decodeDLSCH.LDPCDecodingAlgorithm = PDSCHExtension.LDPCDecodingAlgorithm;
decodeDLSCH.MaximumLDPCIterationCount = PDSCHExtension.MaximumLDPCIterationCount;


% Path Loss Configuration

plCfg = nrPathLossConfig; 
plCfg.Scenario = 'Uma';
ifftvector_tot = 0;
dmrsifftvec_tot = 0;

ofdmInfo = nrOFDMInfo(Carrier);

for snrIdx = 1:numel(SNRIn)
% rng('default');




% Take copies of channel-level parameters to simplify subsequent parameter referencing
    carrier = Carrier;
    pdsch = PDSCH;
    pdschextra = PDSCHExtension;
    decodeDLSCHLocal = decodeDLSCH;  % Copy of the decoder handle to help PCT classification of variable
    decodeDLSCHLocal.reset();        % Reset decoder at the start of each SNR point
    pathFilters = [];

    SNRdB = SNRIn(snrIdx);

    fprintf('\nSimulating transmission scheme 1 (%dx%d) and SCS=%dkHz with LoS channel at %gdB SNR for %d 10ms frame(s)\n', ...
        NTxAnts,NRxAnts,carrier.SubcarrierSpacing, ...
        SNRdB,nFrames);

    harqSequence = 0:pdschextra.NHARQProcesses-1;     % Specify the fixed order in which we cycle through the HARQ process IDs

    % Initialize the state of all HARQ processes
    harqEntity = HARQEntity(harqSequence,rvSeq,pdsch.NumCodewords);

    % Total number of slots in the simulation period
    NSlots = nFrames * carrier.SlotsPerFrame;


   %%%%%%%%%%%%%%%%%%% trget 1 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    directionVector_BS_Target = gNBPos - targetpos;% Calculate the direction vector from BS to target
    directionVector_UE_BS = UEPos - gNBPos;% Calculate the direction vector from BS to UE
    directionVector_UEPos_Target = UEPos - targetpos ;% Calculate the direction vector from target to UE



    % Convert Cartesian coordinates to spherical coordinates
    [az_BS_Target, el_BS_Target, range_BS_Target] = cart2sph(directionVector_BS_Target(1), directionVector_BS_Target(2), directionVector_BS_Target(3));
    [az_UE_BS, el_UE_BS, range_UE_BS] = cart2sph(directionVector_UE_BS(1), directionVector_UE_BS(2), directionVector_UE_BS(3));
    [az_UEPos_Target, el_UEPos_Target, range_UEPos_Target] = cart2sph(directionVector_UEPos_Target(1), directionVector_UEPos_Target(2), directionVector_UEPos_Target(3));

    az_UEPos_Target = az_UEPos_Target/pi *180 +180;
    el_UEPos_Target = el_UEPos_Target/pi *180 +90;

    az_UE_BS = az_UE_BS/pi *180 +180;
    el_UE_BS = el_UE_BS/pi *180 +90;
%%%%%%%%%%%%%%%%%% target 2 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    directionVector_BS_Target2 = gNBPos - targetpos2;% Calculate the direction vector from BS to target
    directionVector_UEPos_Target2 = UEPos - targetpos2 ;% Calculate the direction vector from target to UE
    % Convert Cartesian coordinates to spherical coordinates
    [az_BS_Target2, el_BS_Target2, range_BS_Target2] = cart2sph(directionVector_BS_Target2(1), directionVector_BS_Target2(2), directionVector_BS_Target2(3));
    [az_UEPos_Target2, el_UEPos_Target2, range_UEPos_Target2] = cart2sph(directionVector_UEPos_Target2(1), directionVector_UEPos_Target2(2), directionVector_UEPos_Target2(3));

    az_UEPos_Target2 = az_UEPos_Target2/pi *180 +180;
    el_UEPos_Target2 = el_UEPos_Target2/pi *180 +90;

    % Obtain a precoding matrix (wtx) to be used in the transmission of the
    % first transport block

    [a,bsantpos] = steervec(NTxAnt_x,NTxAnt_z,targetpos,gNBPos,lambda);% steering vector from BS toward target
    [a2,bsantpos2] = steervec(NTxAnt_x,NTxAnt_z,targetpos2,gNBPos,lambda);% steering vector from BS toward target


    newWtx = (a+a2)/sqrt(NTxAnts);

    prsGrid = cell(1,1);
    dataGrid = cell(1,1);
    DMRSGrid = cell(1,1);
    PTRSGrid = cell(1,1);


    slotGridPRSnewjoint = [];
    slotGridPRSjoint = [];



    counter =0;

    % Loop over the entire waveform length
    for nslot = 0:NSlots-1
        carrier.NSlot = nslot;          % Update the carrier slot numbers for new slot

        % Calculate the transport block sizes for the transmission in the slot
        [pdschIndices,pdschIndicesInfo] = nrPDSCHIndices(carrier,pdsch);
        trBlkSizes = nrTBS(pdsch.Modulation,pdsch.NumLayers,numel(pdsch.PRBSet),pdschIndicesInfo.NREPerPRB,pdschextra.TargetCodeRate,pdschextra.XOverhead);


                % HARQ processing
        for cwIdx = 1:pdsch.NumCodewords
            % If new data for current process and codeword then create a new DL-SCH transport block
            if harqEntity.NewData(cwIdx)
                trBlk = randi([0 1],trBlkSizes(cwIdx),1);
                setTransportBlock(encodeDLSCH,trBlk,cwIdx-1,harqEntity.HARQProcessID);
                % If new data because of previous RV sequence time out then flush decoder soft buffer explicitly
                if harqEntity.SequenceTimeout(cwIdx)
                    resetSoftBuffer(decodeDLSCHLocal,cwIdx-1,harqEntity.HARQProcessID);
                end
            end
        end

        % Encode the DL-SCH transport blocks with HARQ
        codedTrBlocks = encodeDLSCH(pdsch.Modulation,pdsch.NumLayers, ...
           pdschIndicesInfo.G,harqEntity.RedundancyVersion,harqEntity.HARQProcessID);
         
         



        % Get precoding matrix (wtx) calculated in previous slot
        wtx = newWtx;
        % Create an empty resource grid spanning one slot in time domain
        slotGrid = nrResourceGrid(carrier,NTxAnts,OutputDataType=DataType);
        slotGridPRS = nrResourceGrid(carrier,1,OutputDataType=DataType);


        % Generate PRS symbols and indices
        prsSym = nrPRS(carrier,prs);
        prsInd = nrPRSIndices(carrier,prs);
        % map the PRS symbols to the antenna
        [prsAntSymbols,prsAntIndices] = nrPDSCHPrecode(carrier,prsSym,prsInd,wtx.');
        % Map PRS resources to slot grid
        slotGrid(prsAntIndices) = prsAntSymbols;
        prsGrid{1} = [prsGrid{1} slotGrid];
  
        slotGridPRS(prsInd) = prsSym;


        % Transmit data in slots in which the PRS is not transmitted by any of
        % the gNBs (to control the hearability problem)
        dataSlotGrid = nrResourceGrid(carrier,NTxAnts,OutputDataType=DataType);
        pdschslotgrid = nrResourceGrid(carrier,1,OutputDataType=DataType);

        DMRSSlotGrid = nrResourceGrid(carrier,NTxAnts,OutputDataType=DataType);
        DMRSSlotGridpos = nrResourceGrid(carrier,1,OutputDataType=DataType);
        PTRSSlotGrid = nrResourceGrid(carrier,NTxAnts,OutputDataType=DataType);

        % if all(cellfun(@isempty,{prsInd}))
        
                 
            % PDSCH modulation and precoding
            pdschSymbols = nrPDSCH(carrier,pdsch,codedTrBlocks);
            [pdschAntSymbols,pdschAntIndices] = nrPDSCHPrecode(carrier,pdschSymbols,pdschIndices,wtx.');

            % PDSCH mapping in grid associated with PDSCH transmission period
            dataSlotGrid(pdschAntIndices) = pdschAntSymbols;


            % PDSCH DM-RS precoding and mapping
            dmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
            dmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);
            [dmrsAntSymbols,dmrsAntIndices] = nrPDSCHPrecode(carrier,dmrsSymbols,dmrsIndices,wtx.');
            dataSlotGrid(dmrsAntIndices) = dmrsAntSymbols;
            DMRSSlotGrid(dmrsAntIndices) = dmrsAntSymbols;

            pdschslotgrid(pdschIndices) = pdschSymbols;


            DMRSSlotGridpos(dmrsIndices) = dmrsSymbols;

            % PDSCH PT-RS precoding and mapping
            ptrsSymbols = nrPDSCHPTRS(carrier,pdsch);
            ptrsIndices = nrPDSCHPTRSIndices(carrier,pdsch);
            [ptrsAntSymbols,ptrsAntIndices] = nrPDSCHPrecode(carrier,ptrsSymbols,ptrsIndices,wtx.');
            dataSlotGrid(ptrsAntIndices) = ptrsAntSymbols;
            PTRSSlotGrid(ptrsAntIndices) = ptrsAntSymbols;
        % end
        dataGrid{1} = [dataGrid{1} dataSlotGrid];
        DMRSGrid{1} = [DMRSGrid{1} DMRSSlotGrid];
        PTRSGrid{1} = [PTRSGrid{1} PTRSSlotGrid];
        
        
        p = 0.1;


        % OFDM modulation
        txWaveform = nrOFDMModulate(carrier, p * slotGrid + (1 - p) *dataSlotGrid);
        %txWaveform = nrOFDMModulate(carrier,prsGrid{1} + dataGrid{1});
        txWaveform1d = nrOFDMModulate(carrier,slotGridPRS);


        [t1 ,t2] = size(txWaveform);

        % PAPR
        Slotpower(nslot+1) = sum(abs(txWaveform).^2,"all") /(t2 * t1 );
        PAPR_RE(nslot+1) =  max( abs(txWaveform),[],'all' )^2;


        % Add Signal Delays, AWGN and Apply Path Loss
        speedOfLight = physconst('LightSpeed'); % Speed of light in m/s


        %%%%%%%%%%%%%%%%%%%%%%% target 1 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


        sampleDelay = zeros(1,1);
        radius = cell(1,1);
        radius = rangeangle(gNBPos',targetpos') + rangeangle(targetpos',UEPos');
        delay = radius/speedOfLight;                      % Delay in seconds
        sampleDelay(1) = round(delay*ofdmInfo.SampleRate);   % Delay in samples
        txWaveformdelay = [zeros(sampleDelay,size(txWaveform,2)); txWaveform];

        % Calculate path loss for gNB and UE pair
        losFlag = true; % Assuming the line of sight (LOS) flag as true, as we are only considering the LOS path delays in this example
        PLdB_gNB_target = nrPathLoss(plCfg,fc,losFlag,gNBPos(:),targetpos(:));
        PLdB_target_UE = nrPathLoss(plCfg,fc,losFlag,targetpos(:),UEPos(:));
        if PLdB_gNB_target < 0 || isnan(PLdB_gNB_target) || isinf(PLdB_gNB_target)
            error('nr5g:invalidPL',"Computed path loss (" + num2str(PLdB_gNB_target) + ...
                ") is invalid. Try changing the UE or gNB positions, or path loss configuration.");
        end
        if PLdB_target_UE < 0 || isnan(PLdB_target_UE) || isinf(PLdB_target_UE)
            error('nr5g:invalidPL',"Computed path loss (" + num2str(PLdB_target_UE) + ...
                ") is invalid. Try changing the UE or gNB positions, or path loss configuration.");
        end
            % PL = 10^(PLdB_gNB_target/10) + 10^(PLdB_target_UE/10);

            PL = 1;
%%%%%%%%%%%%%%%%%%%%%%%%%%% target 2 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        radius2 = cell(1,1);
        radius2 = rangeangle(gNBPos',targetpos2') + rangeangle(targetpos2',UEPos');
        delay2 = radius2/speedOfLight;                      % Delay in seconds
        sampleDelay2(1) = round(delay2*ofdmInfo.SampleRate);   % Delay in samples
        txWaveformdelay2 = [zeros(sampleDelay2,size(txWaveform,2)); txWaveform];

        % Calculate path loss for gNB and UE pair
        losFlag = true; % Assuming the line of sight (LOS) flag as true, as we are only considering the LOS path delays in this example
        PLdB_gNB_target2 = nrPathLoss(plCfg,fc,losFlag,gNBPos(:),targetpos2(:));
        PLdB_target_UE2 = nrPathLoss(plCfg,fc,losFlag,targetpos2(:),UEPos(:));
        if PLdB_gNB_target2 < 0 || isnan(PLdB_gNB_target2) || isinf(PLdB_gNB_target2)
            error('nr5g:invalidPL',"Computed path loss (" + num2str(PLdB_gNB_target2) + ...
                ") is invalid. Try changing the UE or gNB positions, or path loss configuration.");
        end
        if PLdB_target_UE2 < 0 || isnan(PLdB_target_UE2) || isinf(PLdB_target_UE2)
            error('nr5g:invalidPL',"Computed path loss (" + num2str(PLdB_target_UE2) + ...
                ") is invalid. Try changing the UE or gNB positions, or path loss configuration.");
        end
            % PL = 10^(PLdB_gNB_target/10) + 10^(PLdB_target_UE/10);

            PL2 = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




        % Add AWGN to the received time domain waveform
        % Normalize noise power by the IFFT size used in OFDM modulation,
        % as the OFDM modulator applies this normalization to the
        % transmitted waveform. Also normalize by the number of receive
        % antennas, as the channel model applies this normalization to the
        % received waveform, by default
        
        N0 = 1/sqrt(2*NRxAnts*double(ofdmInfo.Nfft)*Carrier.SubcarrierSpacing * 1e3);
        

        
                               
        
        SNR = 10^(SNRdB/10);
        % Add attenuate and SNR
        txWaveformdelay =  [txWaveformdelay; zeros(sampleDelay2 - sampleDelay,size(txWaveform,2))]/sqrt(PL);
        txWaveformdelay2 =  txWaveformdelay2/sqrt(PL);

%%%%%%%%%%%%%%%%%%%% Doppler %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        time=length(txWaveformdelay)/ofdmInfo.SampleRate*nslot:1/ofdmInfo.SampleRate:length(txWaveformdelay)/ofdmInfo.SampleRate-1/ofdmInfo.SampleRate+length(txWaveformdelay)/ofdmInfo.SampleRate*nslot;
        Doppler = repmat(exp(1j*2*pi*freq_dop*time).',1,size(txWaveform,2));
        Doppler2 = repmat(exp(1j*2*pi*freq_dop2*time).',1,size(txWaveform,2));
        






        


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




        % LoS Channel 
        [h,ueantpos] = steervec(NRxAnt_x,NRxAnt_z,targetpos,UEPos,lambda);  % steering vector from target toward UE
        % LoS Channel 2
        [h2,ueantpos2] = steervec(NRxAnt_x,NRxAnt_z,targetpos2,UEPos,lambda);  % steering vector from target2 toward UE

        H = a * h.' + a2 * h2.';
        rx = zeros(size(txWaveformdelay2 * H));
        rx =  (txWaveformdelay.*Doppler + txWaveformdelay2.*Doppler2) * H/(NRxAnts*NTxAnts);

        %calculating transmit/received power for normalization

        [p1 p2 p3] = size(txWaveform);
        powrx = sum(abs(rx).^2,'all')/(p1*p2*p3);
        normalization = N0^2/powrx; 
        [q1 q2 q3] = size(txWaveform);
        powtx(snrIdx) = sqrt(sum(abs(txWaveform).^2,'all')/(q1*q2*q3)*normalization);
        noise = N0*randn(size(rx),"like",rx) + 1j*N0*randn(size(rx),"like",rx);



        rx = sqrt(SNR) * rx *sqrt(normalization) + noise;



        scaler = 1;

      
        % if prs.PRSResourceOffset ~= 0
            offset = 0;

            [t,mag] = nrTimingEstimate(carrier,rx,dmrsIndices,dmrsSymbols);
            sampleDelayestimate = hSkipWeakTimingOffset(offset,t,mag);

        % end

            rxpdsch = rx(sampleDelayestimate+1:end,:);

            % Perform OFDM demodulation on the received data to recreate the
            % resource grid, including padding in the event that practical
            % synchronization results in an incomplete slot being demodulated
            rxGridpdsch = nrOFDMDemodulate(carrier,rxpdsch);
            [K,L,R] = size(rxGridpdsch);
            if (L < carrier.SymbolsPerSlot)
                rxGridpdsch = cat(2,rxGridpdsch,zeros(K,carrier.SymbolsPerSlot-L,R));
            end


            % Practical channel estimation between the received grid and
            % each transmission layer, using the PDSCH DM-RS for each
            % layer. This channel estimate includes the effect of
            % transmitter precoding
            [estChannelGridPorts,noiseEst] = hSubbandChannelEstimate(carrier,rxGridpdsch,...
                dmrsIndices,dmrsSymbols,pdschextra.PRGBundleSize,'CDMLengths',pdsch.DMRS.CDMLengths);
            
            % Average noise estimate across PRGs and layers
            noiseEst = mean(noiseEst,'all');


            slotGridchannel = p * slotGrid.*estChannelGridPorts; 



            % Get PDSCH resource elements from the received grid and
            % channel estimate
            [pdschRx,pdschHest] = nrExtractResources(pdschIndices,rxGridpdsch - slotGridchannel,estChannelGridPorts);

            % [prsRx,prsHest] = nrExtractResources(prsInd,slotGridchannel,estChannelGridPorts);


        if any(~cellfun(@isempty, {prsInd}))
            % R = sum(rx).' * conj(sum(rx));
            R = rx.' * conj(rx);
            N = size(R, 1);
            

            
            % Obtain eigenvalues and eigenvectors
            [eigenvecs, eigenvals] = eig(R);
            % Sort eigenvalues in descending order
            [sortedEigenvals, sortIdx] = sort(diag(eigenvals), 'descend');

            % Choose the N-Q smallest eigenvalues
            Q = 1; % Replace with your desired value
            selectedEigenvals = sortedEigenvals(Q+1:end);

            % Get corresponding eigenvectors for the selected eigenvalues
            selectedEigenvecs = eigenvecs(:, sortIdx(Q+1:end));

            % bigeig=eigenvecs(:, sortIdx(Q));
            % bigeig'*selectedEigenvecs*selectedEigenvecs'*bigeig;

            [phitarget, thetatarget, P] = MUSIC(selectedEigenvecs,Q,az_UEPos_Target,el_UEPos_Target,ueantpos);

            C_Tx_u = [sin(el_UE_BS/180*pi)*cos(az_UE_BS/180*pi) sin(el_UE_BS/180*pi)*sin(az_UE_BS/180*pi) cos(el_UE_BS/180*pi)];
            C_t_u = [sin(thetatarget/180*pi)*cos(phitarget/180*pi) sin(thetatarget/180*pi)*sin(phitarget/180*pi) cos(thetatarget/180*pi)];
            theta = acos(C_Tx_u * C_t_u.'/(norm(C_Tx_u) * norm(C_t_u) ));
            
            %%%%%%%%%%%%%%%%%%%%% MUSIC %%%%%%%%%%%%%%%%%%%%%%%%%
            % array = phased.ULA(4,lambda/2);
            % estimator = phased.MUSICEstimator2D('SensorArray',array,...
            %     'OperatingFrequency',fc,'NumSignals',1,...
            %     'AzimuthScanAngles',-180:1:180,...
            %     'ElevationScanAngles',-90:1:90);
            % 
            % [doas] = estimator(rx);
            % figure; 
            % plotSpectrum(estimator);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % rxprs = nrOFDMModulate(carrier,slotGridchannel);
            % rxGridprs = nrOFDMDemodulate(carrier,[zeros(sampleDelay,size(txWaveform,2)); rxprs]*h/NRxAnts);

            rxGridprs = nrOFDMDemodulate(carrier,rx*(h+h2)/(NRxAnts));

            [a1 a2 a3] = size(rxGridprs);
            if a2 > 14
                rxGridprs = rxGridprs(:,1:14);
            end

            % Find non-zero elements in slotGridPRS
            nonZeroIndices = slotGridPRS ~= 0;


            % Create a new smaller matrix by removing zero elements from A
            slotGridPRSnew = rxGridprs .* nonZeroIndices;
             counter = counter+1;
           
            %%%%%%%%%% Range estimation %%%%%%%%%%%%%%%%%%
            % Concatinating and removing the zero elements of colum of slotGridPRSnew 
                Restimate = zeros(prs.NumPRSSymbols-prs.SymbolStart,1);
            for i=(1+prs.SymbolStart):prs.NumPRSSymbols+1
            
                ifftvector = slotGridPRSnew(:,i)./slotGridPRS(:,i);
                iTF = isnan(ifftvector);
                ifftvector(iTF) = 0;
                ifftsize = size(ifftvector,1);
                ifftscaler = 1*scaler;
                prsifft(:,i) = ifftvector;
                ifftvector_tot= ifftvector_tot + ifftvector;
                r_l(i,:,counter) = abs(ifft(ifftvector,ifftsize*ifftscaler));
                [amount, ind] = max(r_l(i,:,counter));
                Restimate(i- prs.SymbolStart) = (ind-1)*physconst('LightSpeed')/(ifftsize * Carrier.SubcarrierSpacing * 1e3 *ifftscaler);
                range_error(i- prs.SymbolStart) = abs(Restimate(i- prs.SymbolStart) - delay*physconst('LightSpeed'));

                
            end
            delayerror = range_error/physconst('LightSpeed');
            R_max = physconst('LightSpeed')/( Carrier.SubcarrierSpacing * 1e3 ); % the maximum unambiguous range
            rangeresolution = physconst('LightSpeed')/(ifftsize * Carrier.SubcarrierSpacing * 1e3 *ifftscaler);
            sampleDelayestimate = round(mean(Restimate)/physconst('LightSpeed')*ofdmInfo.SampleRate);
            

            Rest = (mean(Restimate(1+prs.SymbolStart:end))^2 - range_UE_BS^2)/(2*mean(Restimate(1+prs.SymbolStart:end)) + 2*range_UE_BS * sin(theta - pi/2) );
            targetlocest = UEPos + Rest*C_t_u;
            targetlocest(3) = abs(targetlocest(3));
            Range_est_er = norm(targetlocest - targetpos);




            % plotgNBAndUEPositions(gNBPos,UEPos,targetpos,targetlocest)





            if nslot < (prs.PRSResourceRepetition * size(prs.PRSResourceOffset,2) + prs.PRSResourceOffset)
               slotGridPRSnewjoint = [slotGridPRSnewjoint slotGridPRSnew];
               slotGridPRSjoint = [slotGridPRSjoint slotGridPRS];

            end



        end







        % if all(cellfun(@isempty, {prsInd}))

            
            % Remove precoding from estChannelGridPorts to get channel
            % estimate w.r.t. antennas
            estChannelGridAnts = precodeChannelEstimate(carrier,estChannelGridPorts,wtx');
            
            
            % Equalization
            [pdschEq,csi] = nrEqualizeMMSE(pdschRx,pdschHest,noiseEst);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                pdschgrid = nrOFDMDemodulate(carrier,rx*(h+h2)/(NRxAnts));
                [a1 a2 a3] = size(pdschgrid);
                if a2 > 14
                    pdschgrid = pdschgrid(:,1:14);
                end


                pdschnonzeroind = pdschslotgrid ~= 0;

                pdschslotgridnew = pdschgrid .* pdschnonzeroind;

            for i=1:(carrier.SymbolsPerSlot-1)


                pdschifftvec = pdschslotgridnew(:,i)./pdschslotgrid(:,i);

                iTFpdsch = isnan(pdschifftvec);
                pdschifftvec(iTFpdsch) = 0;

                ifftsizepdsch = size(pdschifftvec,1);
                pdschifftscaler = 1*scaler;

                r_l_pdsch(i,:,counter) = abs(ifft(pdschifftvec,ifftsizepdsch*pdschifftscaler));

                [amount_pdsch, ind_pdsch] = max(r_l_pdsch(i,:,counter));
                Restimate_pdsch(i,counter) = (ind_pdsch-1)*physconst('LightSpeed')/(ifftsizepdsch * Carrier.SubcarrierSpacing * 1e3 *pdschifftscaler);
                range_error_pdsch(i,counter) = abs(Restimate_pdsch(i,counter) - delay*physconst('LightSpeed'));


            end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 

            rxgriddmrs = nrOFDMDemodulate(carrier,rx*(h+h2)/sqrt(NRxAnts));
            [a1 a2 a3] = size(rxgriddmrs);
            if a2 > 14
               rxgriddmrs = rxgriddmrs(:,1:14);
            end



            dmrsnonzeroind = DMRSSlotGridpos ~= 0;

            dmrsslotgridnew = rxgriddmrs .* dmrsnonzeroind;

            dmrsifftvec = dmrsslotgridnew(:,1)./DMRSSlotGridpos(:,1);

            iTFdmrs = isnan(dmrsifftvec);
            dmrsifftvec(iTFdmrs) = 0;
            ifftsizedmrs = size(dmrsifftvec,1);
            dmrsifftscaler = 1*scaler;
            dmrsifftvec_tot = dmrsifftvec_tot + dmrsifftvec;






            r_l_dmrs(counter,:) = abs(ifft(dmrsifftvec,ifftsizedmrs*dmrsifftscaler));
            [amount_dmrs, ind_dmrs] = max(r_l_dmrs(counter,:));
            Restimate_dmrs(counter) = (ind_dmrs-1)*physconst('LightSpeed')/(ifftsizedmrs * Carrier.SubcarrierSpacing * 1e3 *dmrsifftscaler);
            range_error_dmrs(counter) = abs(Restimate_dmrs(counter) - delay*physconst('LightSpeed'));


            for i=(1+prs.SymbolStart):prs.NumPRSSymbols


            end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%












            % Common phase error (CPE) compensation

            if ~isempty(ptrsIndices)
                % Initialize temporary grid to store equalized symbols
                tempGrid = nrResourceGrid(carrier,pdsch.NumLayers);

                % Extract PT-RS symbols from received grid and estimated
                % channel grid
                [ptrsRx,ptrsHest,~,~,ptrsHestIndices,ptrsLayerIndices] = nrExtractResources(ptrsIndices,rxGridpdsch,estChannelGridAnts,tempGrid);
                ptrsHest = nrPDSCHPrecode(carrier,ptrsHest,ptrsHestIndices,permute(wtx.',[2 1 3]));

                % Equalize PT-RS symbols and map them to tempGrid
                ptrsEq = nrEqualizeMMSE(ptrsRx,ptrsHest,noiseEst);
                tempGrid(ptrsLayerIndices) = ptrsEq;

                % Estimate the residual channel at the PT-RS locations in
                % tempGrid
                cpe = nrChannelEstimate(tempGrid,ptrsIndices,ptrsSymbols);

                % Sum estimates across subcarriers, receive antennas, and
                % layers. Then, get the CPE by taking the angle of the
                % resultant sum
                cpe = angle(sum(cpe,[1 3 4]));

                % Map the equalized PDSCH symbols to tempGrid
                tempGrid(pdschIndices) = pdschEq;

                % Correct CPE in each OFDM symbol within the range of reference
                % PT-RS OFDM symbols
                symLoc = pdschIndicesInfo.PTRSSymbolSet(1)+1:pdschIndicesInfo.PTRSSymbolSet(end)+1;
                tempGrid(:,symLoc,:) = tempGrid(:,symLoc,:).*exp(-1i*cpe(symLoc));

                % Extract PDSCH symbols
                pdschEq = tempGrid(pdschIndices);
            end

        

            % Decode PDSCH physical channel
            [dlschLLRs,rxSymbols] = nrPDSCHDecode(carrier,pdsch,pdschEq,noiseEst);

            % Scale LLRs by CSI
            csi = nrLayerDemap(csi); % CSI layer demapping
            for cwIdx = 1:pdsch.NumCodewords
                Qm = length(dlschLLRs{cwIdx})/length(rxSymbols{cwIdx}); % bits per symbol
                csi{cwIdx} = repmat(csi{cwIdx}.',Qm,1);                 % expand by each bit per symbol
                dlschLLRs{cwIdx} = dlschLLRs{cwIdx} .* csi{cwIdx}(:);   % scale by CSI
            end

            % Decode the DL-SCH transport channel with HARQ
            decodeDLSCHLocal.TransportBlockLength = trBlkSizes;
            [decbits,blkerr] = decodeDLSCHLocal(dlschLLRs,pdsch.Modulation,pdsch.NumLayers,harqEntity.RedundancyVersion,harqEntity.HARQProcessID);

            % Decode the DL-SCH transport channel withOUT HARQ
              % [decbits,blkerr] = decodeDLSCHLocal(dlschLLRs,pdsch.Modulation,pdsch.NumLayers,harqEntity.RedundancyVersion);


            % Store values to calculate throughput
            simThroughput(snrIdx) = simThroughput(snrIdx) + sum(~blkerr .* trBlkSizes);
            maxThroughput(snrIdx) = maxThroughput(snrIdx) + sum(trBlkSizes);


            % Update current process with CRC error and advance to next process
            procstatus = updateAndAdvance(harqEntity,blkerr,trBlkSizes,pdschIndicesInfo.G);
            
            if (DisplaySimulationInformation)
                fprintf('\n(%3.2f%%) NSlot=%d, %s',100*(nslot+1)/NSlots,nslot,procstatus);
            end
            % Get precoding matrix for next slot
            % newWtx = hSVDPrecoders(carrier,pdsch,estChannelGridAnts,pdschextra.PRGBundleSize);
            % newWtx = newWtx.';

            [numberbiterror(snrIdx,nslot+1),errorratio(snrIdx,nslot+1)] = biterr(trBlk,decbits);
            
        % end
        

        
    end
    BER = sum(errorratio)/(carrier.SlotsPerFrame);
    BR = 1e-6*maxThroughput(snrIdx)/(nFrames*10e-3) - sum(errorratio)*1e-6*maxThroughput(snrIdx)/(nFrames*10e-3)/(carrier.SlotsPerFrame);

    PAPR_PRS = 10*log10(PAPR_RE(1)/(sum(Slotpower)/NSlots));
    PAPR_tot = 10*log10((max(PAPR_RE)/(sum(Slotpower)/NSlots)));




            %%%%%%%%% doppler freq estimation %%%%%%%%%%%%%
            PRSsymbolduration = ofdmInfo.SymbolLengths(2)/ofdmInfo.SampleRate;
            % PRSsymbolduration = 0.001;
            m=0:(carrier.SymbolsPerSlot)*prs.PRSResourceRepetition*size(prs.PRSResourceOffset,2)-1;
            doppler = exp(1j*2*pi*m*PRSsymbolduration*freq_dop);
            doppler_span = repmat(doppler,(carrier.NSizeGrid)*12,1);
            % slotGridPRSnewjointdoppler = slotGridPRSnewjoint .* doppler_span;
            slotGridPRSnewjointdoppler = slotGridPRSnewjoint;


          % Concatinating and removing the zero elements of row of slotGridPRSnew
            for i=1:(prs.NumRB*12)
                fftvector = slotGridPRSnewjointdoppler(i,:)./slotGridPRSjoint(i,:);
                TF = isnan(fftvector);
                fftvector(TF) = 0;
                % fftvector = nonzeros(slotGridPRSnewjointdoppler(i,:))./nonzeros(slotGridPRSjoint(i,:));
                fftsize = (carrier.SymbolsPerSlot)*prs.PRSResourceRepetition*size(prs.PRSResourceOffset,2);
                fftscaler = 1;
                v_d(i,:) = abs(fft(fftvector,fftsize*fftscaler));
                [amount_v, ind_v] = max(v_d(i,:));
                speedest(i) = (ind_v-1)*physconst('LightSpeed')/(2*(carrier.SymbolsPerSlot)*prs.PRSResourceRepetition*fc*PRSsymbolduration * fftscaler * size(prs.PRSResourceOffset,2));
                speedesterror(i) = abs(speedest(i) - V_bis1);

            end

                speedresolution = physconst('LightSpeed')/(2*(carrier.SymbolsPerSlot)*prs.PRSResourceRepetition*fc*PRSsymbolduration * fftscaler * size(prs.PRSResourceOffset,2));

    if (DisplaySimulationInformation)
        fprintf('\n');
    end

    fprintf('\nThroughput(Mbps) for %d frame(s) = %.4f\n',nFrames,1e-6*simThroughput(snrIdx)/(nFrames*10e-3));
    fprintf('Throughput(%%) for %d frame(s) = %.4f\n',nFrames,simThroughput(snrIdx)*100/maxThroughput(snrIdx));
end

% r_l_PRS_dmrs = abs(ifft(ifftvector_tot/max(ifftvector_tot) + dmrsifftvec_tot/max(dmrsifftvec_tot),ifftsize*ifftscaler));

r_l_PRS_dmrs = abs(ifft(ifftvector_tot + dmrsifftvec_tot,ifftsize*ifftscaler));

% plotGrid({prsGrid{1}(:,:,1)},{dataGrid{1}(:,:,1)});
% plotGridfull2({prsGrid{1}(:,:,1)},{dataGrid{1}(:,:,1)},{DMRSGrid{1}(:,:,1)},{PTRSGrid{1}(:,:,1)});
% xlim([0.5 14.5]);
% ylim([0.5 12.5]);
% crop_left = 0.2; % left boundary
% crop_bottom = 0.1; % bottom boundary
% crop_width = 0.8; % width
% crop_height = 0.8; % height
% 
% % Get the current axes position
% ax = gca;
% ax_pos = ax.Position;
% 
% % Calculate the cropping dimensions in figure coordinates
% crop_x = crop_left * ax_pos(3);
% crop_y = crop_bottom * ax_pos(4);
% crop_w = crop_width * ax_pos(3);
% crop_h = crop_height * ax_pos(4);
% 
% % Crop the plot
% ax.Position = [crop_x crop_y crop_w crop_h];
% 
% % Save the cropped plot as a PDF file
% exportgraphics(gcf, 'RA.pdf', 'ContentType', 'vector');


r_l_dmrs = mean(r_l_dmrs)/max(mean(r_l_dmrs));
r_l = mean(r_l,[1 3])/max(mean(r_l,[1 3]));


figure;
plot(rangeresolution*(0:(size(r_l,2)-1)),r_l,'DisplayName','Estimation');
ylabel('Magnitude','FontSize',14)
xlabel('Distance (m)','FontSize',14)
xPosition = delay*physconst('LightSpeed');  % Adjust this value based on your needs
line([xPosition, xPosition], ylim, 'Color', 'r', 'LineStyle', '--', 'DisplayName', 'Target 1');
xPosition2 = delay2*physconst('LightSpeed');  % Adjust this value based on your needs
line([xPosition2, xPosition2], ylim, 'Color', 'g', 'LineStyle', '--', 'DisplayName', 'Target 2');

% Add legend
legend('show');
crop_left = 0.2; % left boundary
crop_bottom = 0.1; % bottom boundary
crop_width = 0.8; % width
crop_height = 0.8; % height

% Get the current axes position
ax = gca;
ax_pos = ax.Position;

% Calculate the cropping dimensions in figure coordinates
crop_x = crop_left * ax_pos(3);
crop_y = crop_bottom * ax_pos(4);
crop_w = crop_width * ax_pos(3);
crop_h = crop_height * ax_pos(4);

% Crop the plot
ax.Position = [crop_x crop_y crop_w crop_h];

% Save the cropped plot as a PDF file
exportgraphics(gcf, 'range_prs12_alpha1.pdf', 'ContentType', 'vector');

% 
% figure;
% plot(rangeresolution*(0:(size(r_l_dmrs,2)-1)),r_l_dmrs,'DisplayName','Estimation');
% ylabel('Magnitude')
% xlabel('Distance (m)')
% 
% xPosition = delay*physconst('LightSpeed');  % Adjust this value based on your needs
% line([xPosition, xPosition], ylim, 'Color', 'r', 'LineStyle', '--', 'DisplayName', 'Target 1');
% xPosition2 = delay2*physconst('LightSpeed');  % Adjust this value based on your needs
% line([xPosition2, xPosition2], ylim, 'Color', 'g', 'LineStyle', '--', 'DisplayName', 'Target 2');
% % Add legend
% legend('show');


% figure;
% plot(rangeresolution*(0:(size(r_l_dmrs,2)-1)),r_l_dmrs.* r_l,'DisplayName','Estimation');
% ylabel('Magnitude','FontSize',14)
% xlabel('Distance (m)','FontSize',14)
% 
% xPosition = delay*physconst('LightSpeed');  % Adjust this value based on your needs
% line([xPosition, xPosition], ylim, 'Color', 'r', 'LineStyle', '--', 'DisplayName', 'Target 1');
% xPosition2 = delay2*physconst('LightSpeed');  % Adjust this value based on your needs
% line([xPosition2, xPosition2], ylim, 'Color', 'g', 'LineStyle', '--', 'DisplayName', 'Target 2');
% 
% % Add legend
% legend('show');
% crop_left = 0.2; % left boundary
% crop_bottom = 0.1; % bottom boundary
% crop_width = 0.8; % width
% crop_height = 0.8; % height
% 
% % Get the current axes position
% ax = gca;
% ax_pos = ax.Position;
% 
% % Calculate the cropping dimensions in figure coordinates
% crop_x = crop_left * ax_pos(3);
% crop_y = crop_bottom * ax_pos(4);
% crop_w = crop_width * ax_pos(3);
% crop_h = crop_height * ax_pos(4);
% 
% % Crop the plot
% ax.Position = [crop_x crop_y crop_w crop_h];
% 
% % Save the cropped plot as a PDF file
% exportgraphics(gcf, 'range_prs12_dmrs_alpha1.pdf', 'ContentType', 'vector');

% 
figure;
plot(rangeresolution*(0:(size(r_l_dmrs,2)-1)),r_l_PRS_dmrs,'DisplayName','Estimation');
ylabel('Magnitude','FontSize',14)
xlabel('Distance (m)','FontSize',14)

xPosition = delay*physconst('LightSpeed');  % Adjust this value based on your needs
line([xPosition, xPosition], ylim, 'Color', 'r', 'LineStyle', '--', 'DisplayName', 'Target 1');
xPosition2 = delay2*physconst('LightSpeed');  % Adjust this value based on your needs
line([xPosition2, xPosition2], ylim, 'Color', 'g', 'LineStyle', '--', 'DisplayName', 'Target 2');

% Add legend
legend('show');


crop_left = 0.2; % left boundary
crop_bottom = 0.1; % bottom boundary
crop_width = 0.8; % width
crop_height = 0.8; % height

% Get the current axes position
ax = gca;
ax_pos = ax.Position;

% Calculate the cropping dimensions in figure coordinates
crop_x = crop_left * ax_pos(3);
crop_y = crop_bottom * ax_pos(4);
crop_w = crop_width * ax_pos(3);
crop_h = crop_height * ax_pos(4);

% Crop the plot
ax.Position = [crop_x crop_y crop_w crop_h];

% Save the cropped plot as a PDF file
exportgraphics(gcf, 'range_prs12_dmrs_alpha1.pdf', 'ContentType', 'vector');











% 
% 
% 
% 
% figure;
% plot(speedresolution*(0:(size(v_d,2)-1)),mean(v_d),'DisplayName','Estimation');
% % title('PRS + DMRS')
% ylabel('Magnitude')
% xlabel('Velocity (m/s)')
% 
% velocity = V_bis1;  % Adjust this value based on your needs
% line([velocity, velocity], ylim, 'Color', 'r', 'LineStyle', '--', 'DisplayName', 'target');
% velocity2 = V_bis2;  % Adjust this value based on your needs
% line([velocity2, velocity2], ylim, 'Color', 'g', 'LineStyle', '--', 'DisplayName', 'target');
% 
% % Add legend
% legend('show');
% 
% crop_left = 0.2; % left boundary
% crop_bottom = 0.1; % bottom boundary
% crop_width = 0.8; % width
% crop_height = 0.8; % height
% 
% % Get the current axes position
% ax = gca;
% ax_pos = ax.Position;
% 
% % Calculate the cropping dimensions in figure coordinates
% crop_x = crop_left * ax_pos(3);
% crop_y = crop_bottom * ax_pos(4);
% crop_w = crop_width * ax_pos(3);
% crop_h = crop_height * ax_pos(4);
% 
% % Crop the plot
% ax.Position = [crop_x crop_y crop_w crop_h];
% 
% % Save the cropped plot as a PDF file
% exportgraphics(gcf, 'range_prs12_dmrs_alpha1.pdf', 'ContentType', 'vector');












% 
% 
% 
% figure;
% plot(speedresolution*(0:(size(v_d,2)-1)),v_d(i,:),'DisplayName','Estimation');
% % title('PRS + DMRS')
% ylabel('Magnitude')
% xlabel('Velocity (m/s)')
% 
% velocity = V_bis1;  % Adjust this value based on your needs
% line([velocity, velocity], ylim, 'Color', 'r', 'LineStyle', '--', 'DisplayName', 'target');
% 
% % Add legend
% legend('show');
% velocity2 = V_bis2;  % Adjust this value based on your needs
% line([velocity2, velocity2], ylim, 'Color', 'g', 'LineStyle', '--', 'DisplayName', 'target');
% 

