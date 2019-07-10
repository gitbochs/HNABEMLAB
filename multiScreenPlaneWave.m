clc;
clear classes;
% run addPathsHNA() to add necessary search paths
%wavenumber
kwave=250;

%create 'screen' object ---------------------------------------------------
vertices =   [1    0;
              0    0];
          
segs = [0 .45 .5 1];

Gamma=MultiScreen(vertices,segs);

%inident plane wave -------------------------------------------------------
d = [1 -1]./sqrt(2); %direction as a vector
uinc=planeWave(kwave,d);
    
%make an HNA basis on Gamma -----------------------------------------------
pMax = 16 ; %polynomial degree
cL = 2; %layers of grading per polynomial degree
sigmaGrad=0.15; %grading ratio
nLayers = cL*(pMax+1)-1; %number of layers of grading
throwAwayParam = 0; %no need to remove any basis elements
OverSample = 1.5; %choose amount to oversample by (50% here)
% construct the HNA basis (single mesh):
VHNA = HNAoverlappingMesh(Gamma, pMax, kwave, nLayers, sigmaGrad);
%VHNA = HNAoverlappingMesh(Gamma, pMax, kwave, nLayers, sigmaGrad);
DOFs = length(VHNA.el); %get total #DOFs

% construct the single layer potential 'operator' ---------------------------
S=singleLayer(kwave,Gamma);

%solve (and time)
tic;
[v_N, GOA, colMatrix, colRHS] = ColHNA(S, VHNA, uinc, Gamma,'oversample', OverSample, 'progress');
T = toc;

disp('Plotting output');

%plot the far-field pattern:
figure(1);
theta = linspace(0,2*pi,5000);
Fv_N = FarField(Gamma, v_N, kwave, theta);
FPsi = FarField(Gamma, GOA, kwave, theta);
plot(theta,(FPsi(:,1)+Fv_N(:,1)));
xlim([0 2*pi]);
xlabel('\theta');

%now plot the solution in the domain:
figure(2);
domainPlot(Gamma,uinc,GOA,v_N,kwave);

%now compute the complimentary sound-hard aperature problem, by Babinet's
%principle:
figure(3);
BabinetComplementPlot(Gamma,uinc,GOA,v_N,kwave);