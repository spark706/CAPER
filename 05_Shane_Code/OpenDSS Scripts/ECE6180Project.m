% ECE 6180                      Project                     Shane Kimble

% Load DSS file location
load('COMMONWEALTH_Location.mat');

% Load Historical Data
%  Loads 12am - 11:59pm on given date (1 min resolution)
date = '06/01/2014';
n = 60*24; % Number of minutes in a day
index = n*(datenum(date)-datenum('01/01/2014'));
load('CMNWLTH.mat');
for i=0:n-1
    DATA(i+1).Time = [sprintf('%02d',floor(i/60)),':',sprintf('%02d',mod(i,60))];
    
    DATA(i+1).VoltagePhaseA = CMNWLTH.Voltage.A(index+i);
    DATA(i+1).VoltagePhaseB = CMNWLTH.Voltage.B(index+i);
    DATA(i+1).VoltagePhaseC = CMNWLTH.Voltage.C(index+i);
    
    DATA(i+1).CurrentPhaseA = CMNWLTH.Amp.A(index+i);
    DATA(i+1).CurrentPhaseB = CMNWLTH.Amp.B(index+i);
    DATA(i+1).CurrentPhaseC = CMNWLTH.Amp.C(index+i);
    
    DATA(i+1).RealPowerPhaseA = CMNWLTH.kW.A(index+i);
    DATA(i+1).RealPowerPhaseB = CMNWLTH.kW.B(index+i);
    DATA(i+1).RealPowerPhaseC = CMNWLTH.kW.C(index+i);
    
    DATA(i+1).ReactivePowerPhaseA = CMNWLTH.kVAR.A(index+i);
    DATA(i+1).ReactivePowerPhaseB = CMNWLTH.kVAR.B(index+i);
    DATA(i+1).ReactivePowerPhaseC = CMNWLTH.kVAR.C(index+i);
end
clear CMNWLTH

% Generate Load Shape
fileID = fopen([filelocation,'Loadshape.dss'],'wt');
fprintf(fileID,['New loadshape.LS_PhaseA npts=1440 sinterval=60 mult=(',...
    sprintf('%f ',[DATA.RealPowerPhaseA]/max([DATA.RealPowerPhaseA])),...
    ') action=normalize\n\n']);
fprintf(fileID,['New loadshape.LS_PhaseB npts=1440 sinterval=60 mult=(',...
    sprintf('%f ',[DATA.RealPowerPhaseB]/max([DATA.RealPowerPhaseB])),...
    ') action=normalize\n\n']);
fprintf(fileID,['New loadshape.LS_PhaseC npts=1440 sinterval=60 mult=(',...
    sprintf('%f ',[DATA.RealPowerPhaseC]/max([DATA.RealPowerPhaseC])),...
    ') action=normalize\n\n']);
fclose(fileID);

% Setup the COM server
[DSSCircObj, DSSText, gridpvPath] = DSSStartup;
DSSCircuit = DSSCircObj.ActiveCircuit;

% Compile Circuit
DSSText.command = ['Compile ',[filelocation,filename]];

% Configure Simulation
DSSText.command = 'set mode = snapshot';
DSSText.command = 'set mode = daily';
DSSCircuit.Solution.Number = 1;
DSSCircuit.Solution.Stepsize = 60;
DSSCircuit.Solution.dblHour = 0.0;

% Loop through load shape
for t = 1:n
    % Solve at current time step
    
    % Read Data from OpenDSS
    
end
