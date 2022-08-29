function [KSPACE,TIME,NOISE,ACQ,PHYSIO,GROUNDTRUTH] = Fetal_XCMR_Generate_Data(ACQ,PHYSIO)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This is the main script used to generate Fetal XCMR data. AQC and PHYSIO
% are structures containing user selected acquisition parameters generated
% from Fetal_XCMR_Cartesian_Demo_Parameters or
% Fetal_XCMR_Radial_Demo_Parameters or a custom parameter file.
% Alternatively you can run this script without inputs and edit the
% hardcoded values listed below. This script generates KSpace, measured
% time points, noise, and optional ground truth images for comparison.
%\
% Simulation and reconstruction of radial data requires the iGRASP code
% from Li Feng and Ricardo Otazo.
% Feng L, Grimm R, Tobias Block K, Chandarana H, Kim S, Xu J, Axel L, Sodickson DK, Otazo R. Golden-angle radial sparse parallel MRI: Combination of compressed sensing, parallel imaging, and golden-angle radial sampling for fast and flexible dynamic volumetric MRI. Magn Reson Med. 2013 Oct 18. doi: 10.1002/mrm.24980.
% It can be downloaded here:
% https://cai2r.net/resources/software/grasp-matlab-code
%
% Christopher W. Roy 2018-12-04
% fetal.xcmr@gmail.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

addpath('Utilities')
KSPACE=[];
TIME=[];
NOISE=[];
GROUNDTRUTH=[];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% User Selected Acquisition Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% User parameters can be given as an input or set within the main script.
if ~exist('ACQ','var')||isempty(ACQ)
    ACQ.GroundTruthFlag = 1; %
    ACQ.Trajectory           = 'CART'; % ['CART' or 'RAD']
    ACQ.SliceOrientation     = 'TRA';  % ['TRA' or 'SAG' or 'COR' or 'SAx']
    ACQ.FlipAngle            = 70;     % [Use reasonable scanner values i.e. 70] degrees
    ACQ.TR                   = 4.06;   % [Use reasonable scanner values i.e. 3-5] ms
    ACQ.TE                   = 2;      % [Use reasonable scanner values i.e. 1-3] ms
    
    ACQ.SliceThickness       = 4;      % [Use reasonable scanner values i.e. 3-8] mm
    ACQ.nSlices              = 1;      % [Choose according to slice thickness and heart dimensions which are aprox. 50mm x 57mm x 46mm)]
    ACQ.SpatialResolution    = 1;      % [Use reasonable scanner values i.e. 1-2] mm
    
    ACQ.nCoils               = 8;      % [Use reasonable (even numbered) scanner values: 4-32]
    ACQ.SNR                  = 20;     % [Use reasonable scanner values]
    
    % For radial this determines the number of spokes
    ACQ.nMeasurements        = 1000;    % [Use reasonable scanner values 500-5000]
    % or For Cartesian this determines the number of frames which is then multiplied by the number of lines to get the equivalent number of measurements. This is ignored for radial
    ACQ.nFrames              = 20;     % [Use reasonable scanner values 1-30]
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% User Selected Physiological Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~exist('PHYSIO','var')||isempty(PHYSIO)
    % Displacement of the fetus in 3 directions based on maternal respiration
    % Can choose any value but the code will restrict fetal movement within the region of the maternal abdomen
    PHYSIO.RespiratoryMotionAmplitude = [1,1,1];
    % Displacement of the fetus in 3 directions based on random gross fetal movement
    % Can choose any value but the code will restrict fetal movement within the region of the maternal abdomen
    PHYSIO.FetalMotionAmplitude = [0,0,0];
    % Fetal cardiac Motion (Yes = 1, No = 0)
    PHYSIO.CardiacMotionFlag = 1;
    % Maternal respiratory Motion (Yes = 1, No = 0 (i.e. breath-hold) )
    PHYSIO.RespiratoryMotionFlag = 0;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% End of User selected Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Some error checking. Could be improved
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
while(1)
    % Make the trajectory and slice orientation parameters case insensitive
    ACQ.Trajectory=upper(ACQ.Trajectory);
    ACQ.SliceOrientation=upper(ACQ.SliceOrientation);
    if strcmpi(ACQ.Trajectory,'RAD')
        % Check to see if non-uniform fourier transform from iGRASP code is in
        % the matlab path
        if exist('MCNUFFT.m','file')==0
            inputdlg('Simulation and reconstruction of radial data requires the iGRASP code. Add to path or downloaded from: https://cai2r.net/resources/software/grasp-matlab-code','Error');
            break
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % End of error checking
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Run Main Code
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Load XCAT volumes, change orientation, crop, and convert to MR contrast
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    Path=[cd,filesep,'Source Images',filesep];
    RemainingTime=10;% Set arbitrary starting value for remaining time
    ElapsedTime=0;
    myTime0=tic;
    for iFile=1:length(dir([Path,'*Fetal_Cardiac*']))
        myTime=tic;
        clc
        
        display(['Loading XCAT Volumes. Elapsed Time: ',num2str(round(ElapsedTime)),'s. Estimated Time Remaining: ',num2str(round(RemainingTime.*(length(dir([Path,'*Fetal_Cardiac*']))-iFile))),' s'])
        
        load([Path,'Fetal_Cardiac_phase_',num2str(iFile),'.mat'],'Fetal')
        load([Path,'Maternal_Respiratory_Phase_',num2str(iFile),'.mat'],'Maternal')
        if strcmpi(ACQ.SliceOrientation,'TRA')
            Fetal=fliplr(permute(Fetal,[2,1,3]));
            Maternal=fliplr(permute(Maternal,[2,1,3]));
        elseif strcmpi(ACQ.SliceOrientation,'SAG')
            Fetal=permute(Fetal,[2,3,1]);
            Maternal=permute(Maternal,[2,3,1]);
        elseif strcmpi(ACQ.SliceOrientation,'COR')
            Fetal=imrotate(permute(Fetal,[3,1,2]),180);
            Maternal=imrotate(permute(Maternal,[3,1,2]),180);
        elseif strcmpi(ACQ.SliceOrientation,'SAx')
            Fetal=permute(imrotate(permute(imrotate(Fetal,230,'crop'),[1,3,2]),205,'crop'),[2,3,1]);
            Maternal=permute(imrotate(permute(imrotate(Maternal,230,'crop'),[1,3,2]),205,'crop'),[2,3,1]);
        end
        if iFile==1
            SIM.CardiacSlices = Extract_Cardiac_Slices(Fetal==50);
            if strcmpi(ACQ.SliceOrientation,'SAG')
                SIM.CenterSlicePosition=round(range(SIM.CardiacSlices)/2)+5;
            elseif strcmpi(ACQ.SliceOrientation,'SAx')
                SIM.CenterSlicePosition=round(range(SIM.CardiacSlices)/2)-5;
            else
                SIM.CenterSlicePosition=round(range(SIM.CardiacSlices)/2);
            end
            SIM.SlicesToLoad=SIM.CardiacSlices(SIM.CenterSlicePosition)-floor((3*ACQ.SliceThickness/ACQ.SpatialResolution-1)/2):SIM.CardiacSlices(SIM.CenterSlicePosition)+ceil((3*ACQ.SliceThickness/ACQ.SpatialResolution-1)/2);
            SIM.SlicesToMeasure=1+ceil(10/ACQ.SliceThickness):ceil(10/ACQ.SliceThickness)+ACQ.nSlices;
            SIM.FetalT1=zeros(size(Maternal,1),size(Maternal,2),length(SIM.SlicesToLoad),20,'single');
            SIM.FetalT2=zeros(size(Maternal,1),size(Maternal,2),length(SIM.SlicesToLoad),20,'single');
            SIM.MaternalT1=zeros(size(Maternal,1),size(Maternal,2),length(SIM.SlicesToLoad),20,'single');
            SIM.MaternalT2=zeros(size(Maternal,1),size(Maternal,2),length(SIM.SlicesToLoad),20,'single');
        end
        [SIM.FetalT1(:,:,:,iFile),SIM.FetalT2(:,:,:,iFile),~,~]=XCAT_to_T1T2(Fetal(:,:,SIM.SlicesToLoad),'Fetal');
        [SIM.MaternalT1(:,:,:,iFile),SIM.MaternalT2(:,:,:,iFile),~,~]=XCAT_to_T1T2(Maternal(:,:,SIM.SlicesToLoad),'Maternal');
        ElapsedTime=toc(myTime0);
        RemainingTime=toc(myTime);
    end
    VolumeLoadingTime=ElapsedTime;
    display(['XCAT Volumes loaded in: ',num2str(round(VolumeLoadingTime)),'s'])
    
    [y,x]=Shrink_Volume(SIM.MaternalT1);
    SIM.MaternalT1=SIM.MaternalT1(y,x,:,:);
    SIM.MaternalT2=SIM.MaternalT2(y,x,:,:);
    SIM.FetalT1=SIM.FetalT1(y,x,:,:);
    SIM.FetalT2=SIM.FetalT2(y,x,:,:);
    SIM.FetalT1=cat(4,SIM.FetalT1(:,:,:,end),SIM.FetalT1,SIM.FetalT1(:,:,:,1));
    SIM.FetalT2=cat(4,SIM.FetalT2(:,:,:,end),SIM.FetalT2,SIM.FetalT2(:,:,:,1));
    SIM.MaternalT1=cat(4,SIM.MaternalT1(:,:,:,end),SIM.MaternalT1,SIM.MaternalT1(:,:,:,1));
    SIM.MaternalT2=cat(4,SIM.MaternalT2(:,:,:,end),SIM.MaternalT2,SIM.MaternalT2(:,:,:,1));
    clear Fetal Maternal iFile x y z
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Set up some MR imaging parameters
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if strcmpi(ACQ.Trajectory,'SPIR')
        ACQ.FOV=2*round(0.5*sqrt(size(SIM.FetalT1,1)^2+size(SIM.FetalT1,2)^2));
        ACQ.MatrixSize=2*round(0.5*ACQ.FOV/ACQ.SpatialResolution);
        [ACQ.kx,ACQ.ky] = Radial_Trajectory(ACQ.MatrixSize, ACQ.nMeasurements, 1);
        ACQ.ImSize=2*round(0.5*size(SIM.FetalT1(:,:,1,1))/ACQ.SpatialResolution);
        ACQ.FOVFreq=size(SIM.FetalT1,1);
        ACQ.FOVPhase=size(SIM.FetalT1,2);
        ACQ.MatrixSizeFreq=2*round(0.5*ACQ.FOVFreq/ACQ.SpatialResolution);
        ACQ.MatrixSizePhase=2*round(0.5*ACQ.FOVPhase/ACQ.SpatialResolution);
    end
    ACQ.TIME=reshape(ACQ.TR*(0:(ACQ.nMeasurements*ACQ.nSlices)-1),ACQ.nMeasurements,ACQ.nSlices);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Simulate motion
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if PHYSIO.CardiacMotionFlag
        BaseRR=round(60000/180):round(60000/110);BaseRR=BaseRR(randperm(length(BaseRR),1));
        PHYSIO.RRInterval = Generate_Variation(6, 0.14, range(ACQ.TIME(:)), BaseRR);
        PHYSIO.CardiacPhases=Calculate_Phases(ACQ.TIME(:),cumsum([0,PHYSIO.RRInterval]));clear BaseRR
    else
        PHYSIO.CardiacPhases=zeros(size(ACQ.TIME));
    end
    
    if PHYSIO.RespiratoryMotionFlag
        PHYSIO.Mode='FB';
        if sum(PHYSIO.FetalMotionAmplitude)~=0
            PHYSIO.Mode='RDM';
        end
        BaseRR=3000:5000;BaseRR=BaseRR(randperm(length(BaseRR),1));
        PHYSIO.RPInterval = Generate_Variation(6, 0.14, range(ACQ.TIME(:)), BaseRR);
        PHYSIO.RespiratoryPhases=Calculate_Phases(ACQ.TIME(:),cumsum([0,PHYSIO.RPInterval])); clear BaseRR
    else
        PHYSIO.Mode='BH';
        if sum(PHYSIO.FetalMotionAmplitude)~=0
            PHYSIO.Mode='BH_RDM';
        end
        PHYSIO.RespiratoryPhases=zeros(size(ACQ.TIME(:)));
    end
    
    load('XCAT_Coordinates','Maternal_Coordinates','Fetal_Coordinates')
    SIM.Maternal_Coordinates=Maternal_Coordinates;clear Maternal_Coordinates
    SIM.Fetal_Coordinates=Fetal_Coordinates;clear Fetal_Coordinates
    
    PHYSIO.Motion=PHYSIO.RespiratoryMotionAmplitude.*bsxfun(@minus,Interp_Motion(SIM.Maternal_Coordinates,PHYSIO.RespiratoryPhases),SIM.Fetal_Coordinates);%mean(SIM.Maternal_Coordinates,1));
    PHYSIO.RespiratoryMotion=Interp_Motion(SIM.Maternal_Coordinates,PHYSIO.RespiratoryPhases);
    
    PHYSIO.Motion(:,1) = PHYSIO.Motion(:,1) + PHYSIO.FetalMotionAmplitude(1)*Generate_Motion(ACQ.nMeasurements*ACQ.nSlices);
    PHYSIO.Motion(:,2) = PHYSIO.Motion(:,2) + PHYSIO.FetalMotionAmplitude(2)*Generate_Motion(ACQ.nMeasurements*ACQ.nSlices);
    PHYSIO.Motion(:,3) = PHYSIO.Motion(:,3) + PHYSIO.FetalMotionAmplitude(3)*Generate_Motion(ACQ.nMeasurements*ACQ.nSlices);
    PHYSIO.Motion(PHYSIO.Motion>10)=10;PHYSIO.Motion(PHYSIO.Motion<-10)=-10;
    
    if strcmpi(ACQ.SliceOrientation,'TRA')
        PHYSIO.Motion=[PHYSIO.Motion(:,2),-PHYSIO.Motion(:,1),PHYSIO.Motion(:,3)];
    elseif strcmpi(ACQ.SliceOrientation,'SAG')
        PHYSIO.Motion=[PHYSIO.Motion(:,2),PHYSIO.Motion(:,3),PHYSIO.Motion(:,1)];
    elseif strcmpi(ACQ.SliceOrientation,'COR')
        PHYSIO.Motion=[-PHYSIO.Motion(:,3),PHYSIO.Motion(:,1),-PHYSIO.Motion(:,2)];
    elseif strcmpi(ACQ.SliceOrientation,'SAx')
        R=[cosd(230),-sind(230),0;sind(230),cosd(230),0;0,0,1];
        for i=1:size(PHYSIO.Motion,1)
            PHYSIO.Motion(i,:)=R*(PHYSIO.Motion(i,:)');
        end
        PHYSIO.Motion=[PHYSIO.Motion(:,1),PHYSIO.Motion(:,3),PHYSIO.Motion(:,2)];
        R=[cosd(205),-sind(205),0;sind(205),cosd(205),0;0,0,1];
        for i=1:size(PHYSIO.Motion,1)
            PHYSIO.Motion(i,:)=R*(PHYSIO.Motion(i,:)');
        end
        PHYSIO.Motion=[PHYSIO.Motion(:,2),PHYSIO.Motion(:,3),PHYSIO.Motion(:,1)];
        clear R i
    end
    
    PHYSIO.CardiacPhases=reshape(PHYSIO.CardiacPhases,[ACQ.nMeasurements,ACQ.nSlices]);
    PHYSIO.RespiratoryPhases=reshape(PHYSIO.RespiratoryPhases,[ACQ.nMeasurements,ACQ.nSlices]);
    PHYSIO.Motion=reshape(PHYSIO.Motion,[ACQ.nMeasurements,ACQ.nSlices,3]);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Simulate MR Data
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if strcmpi(ACQ.Trajectory,'SPIR')
        if ACQ.nCoils==1
            ACQ.Coils=ones([ACQ.FOV,ACQ.FOV]);
        else
            ACQ.Coils = Simulate_Coils([ACQ.FOV,ACQ.FOV],ACQ.nCoils);
        end
    end
    if strcmpi(ACQ.Trajectory,'SPIR')
        KSPACE=zeros(size(ACQ.kx,1),size(ACQ.kx,2),ACQ.nCoils,ACQ.nSlices,'single');
        ACQ.Coils=Resize_Volume(ACQ.Coils,ACQ.MatrixSize);
        TIME=zeros(size(ACQ.TIME));
        % Optional turn on to have ground truth comparison
        if    ACQ.GroundTruthFlag
            T1Vol=zeros(ACQ.FOVFreq,ACQ.FOVPhase,size(SIM.SlicesToLoad,2),ACQ.nMeasurements,'single');
            T2Vol=zeros(ACQ.FOVFreq,ACQ.FOVPhase,size(SIM.SlicesToLoad,2),ACQ.nMeasurements,'single');
        else
            T1Vol=[];
            T2Vol=[];
        end
    end
    
    ProgressCounter=0;
    RemainingTime=1;% Set arbitrary starting value for remaining time
    ElapsedTime=0;
    myTime0=tic;
    
    PreviousTime=10000;% Keep the elapsed time from jumping around during long simulations.
    for iSlice=1:ACQ.nSlices
        for iMeas=1:ACQ.nMeasurements
            myTime=tic;
            clc
            
            display(['XCAT Volumes loaded In: ',num2str(round(VolumeLoadingTime)),'s'])
            
            if round(RemainingTime.*(ACQ.nMeasurements*ACQ.nSlices-ProgressCounter))<PreviousTime
                display(['Simulating XCMR Data. Elapsed Time: ',num2str(round(ElapsedTime)),'s. Estimated Time Remaining: ',num2str(round(RemainingTime.*(ACQ.nMeasurements*ACQ.nSlices-ProgressCounter))),' s'])
                PreviousTime=round(RemainingTime.*(ACQ.nMeasurements*ACQ.nSlices-ProgressCounter));
            else
                display(['Simulating XCMR Data. Elapsed Time: ',num2str(round(ElapsedTime)),'s. Estimated Time Remaining: ',num2str(PreviousTime),' s'])
            end
            ProgressCounter=ProgressCounter+1;
            
            Measurement_T1=Select_Phantom_Phase(SIM.FetalT1,PHYSIO.CardiacPhases(iMeas,iSlice));
            Measurement_T1=circshift(Measurement_T1,ceil(squeeze(PHYSIO.Motion(iMeas,iSlice,:))));
            
            Measurement_T2=Select_Phantom_Phase(SIM.FetalT2,PHYSIO.CardiacPhases(iMeas,iSlice));
            Measurement_T2=circshift(Measurement_T2,ceil(squeeze(PHYSIO.Motion(iMeas,iSlice,:))));

            if strcmpi(ACQ.Trajectory,'SPIR')
                T1Vol(:,:,:,iMeas)=Measurement_T1+Select_Phantom_Phase(SIM.MaternalT1,PHYSIO.RespiratoryPhases(iMeas,iSlice));
                T2Vol(:,:,:,iMeas)=Measurement_T2+Select_Phantom_Phase(SIM.MaternalT2,PHYSIO.RespiratoryPhases(iMeas,iSlice));
                
                TIME(iMeas,iSlice)=ACQ.TIME(iMeas,iSlice);
            end
            ElapsedTime=toc(myTime0);
            RemainingTime=toc(myTime);
        end
        
    end
    % save outputs to a mat file
    output_file = [ACQ.Trajectory '_' ACQ.SliceOrientation '_RESP_' strrep(num2str(PHYSIO.RespiratoryMotionAmplitude(:)'),' ','') 
        '_GFM_' strrep(num2str(PHYSIO.FetalMotionAmplitude(:)'),' ','') '.mat'];
    save(output_file, 'T1Vol', 'T2Vol', 'TIME');
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % End of MR Simulation
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
end
