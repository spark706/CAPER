% DSSInitialize initializes an OpenDSS Circuit in snapshot mode
%clear
%clc
close('all')

% Find CAPER directory
fid = fopen('pathdef.m','r');
rootlocation = textscan(fid,'%c')';
rootlocation = regexp(rootlocation{1}','C:[^.]*?CAPER\\','match','once');
fclose(fid);
rootlocation = [rootlocation,'07_CYME\'];

% Read in filelocation
filename = 0;
% ******To skip UIGETFILE uncomment desired filename*******
% ***(Must be in rootlocation CAPER03_OpenDSS_Circuits\)***
filename = 'Master.dss'; filelocation = [rootlocation,'Commonwealth_ret_01311205.sxst_DSS\'];
while ~filename
    [filename,filelocation] = uigetfile({'*.*','All Files'},'Select DSS Master File',...
        rootlocation);
end

% Setup the COM server
[DSSCircObj, DSSText, gridpvPath] = DSSStartup;
DSSCircuit = DSSCircObj.ActiveCircuit;

% Compile Circuit
DSSText.command = ['Compile ',[filelocation,filename]];

% Configure Simulation
DSSText.command = 'Set Mode=Snapshot';
DSSCircuit.Solution.Solve

Lines = getLineInfo(DSSCircObj);