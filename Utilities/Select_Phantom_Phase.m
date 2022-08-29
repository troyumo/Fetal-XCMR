function Phantom_Measurement = Select_Phantom_Phase(Phantom,InterpolatedPhase)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This script generates a phantom volume at simulated time points 
% without interpolation since we don't want to average relaxation times.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

InterpolatedPhase = round(InterpolatedPhase * 50);

Measured_Phases = linspace(0,50,size(Phantom,4)-1);
Measured_Phases = [-Measured_Phases(2),Measured_Phases];

i = find(Measured_Phases==InterpolatedPhase);
Phantom_Measurement=(Phantom(:,:,:,i));
end