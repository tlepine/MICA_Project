%% Main script to test ecg function without gui
% This file computes a simple analysis of an ecg signal. You can use it to test the different processing methods. 
% This first version will plot the temporal signal, compute its cardiac rythma and display the different P, Q, R, S, T points for a specific segment.  

clear; close all; clc;
addpath(genpath('.'));

%% Load a signal
[file,path] = uigetfile('../data/ecg_normal_1.mat', 'rt');
signal = load(fullfile(path, file));
data = signal.ecg; % Your ecg data
Fs = signal.Fs; % Sampling frequency
N = size(data,2); % Data length
time_axis = (1:N)/Fs;

%% Threshold method
th = 200; % threshold
i_seg = 10; % Segment number to plot

% Time plot
figure;
plot(time_axis, data); grid on;
hold on; plot(time_axis, th*ones(1,N), 'red');
xlabel('Time (s)');
ylabel('Magnitude');
title('Time evolution of the loaded signal')

% Print BPM
[bpm, R_locs] = bpm_threshold(data, th, Fs);
% Figures PQRST
[segment, P_loc, Q_loc, R_loc, S_loc, T_loc] = ecg_threshold(data, R_locs, i_seg);
time_segment = (1:length(segment))/Fs;

figure;
h = plot(time_segment, segment); grid on;
hold on;
%plot(time_segment(P_loc),segment(P_loc), '*','Color','red'); text(time_segment(P_loc),segment(P_loc),' P ','Color','red','FontSize',14);
%plot(time_segment(Q_loc),segment(Q_loc), '*','Color','red'); text(time_segment(Q_loc),segment(Q_loc),' Q ','Color','red','FontSize',14);
%plot(time_segment(R_loc),segment(R_loc), '*','Color','red'); text(time_segment(R_loc),segment(R_loc),' R ','Color','red','FontSize',14);
%plot(time_segment(S_loc),segment(S_loc), '*','Color','red'); text(time_segment(S_loc),segment(S_loc),' S ','Color','red','FontSize',14);
plot(time_segment(T_loc),segment(T_loc), '*','Color','red'); text(time_segment(T_loc),segment(T_loc),' T ','Color','red','FontSize',14);
hold off;
xlabel('Time (s)');
ylabel('Magnitude');
title('ECG segment characteristic')

%% Your turn : My new method ! 
%%% Band-pass filter
ecg_1 = filter([1 0 0 0 0 0 -1], [1 -1], data); %low_pass filter
ecg_1 = filter([1 0 0 0 0 0 -1], [1 -1], ecg_1); %square
delay_bandpass = 5; % delai cree par le filtre passe bas
b1 = zeros(1,33);
b1(1,1) = -1;
b1(1,17) = 32;
b1(1,18) = -32;
b1(1,32) = 1;

ecg_2 = filter(b1, [1 -1], ecg_1); %high-pass filter
delay_bandpass = delay_bandpass + 16; % ajout du delai du filtre passe haut

%%% Derivative
 b2 = [1 2 0 -2 -1]*(1/8)*Fs;   
delay = 0; % delai introduit par la causalite forcee du filtre
ecg_3 = filter(b2, 1, ecg_2); %derivative filter shifted
delay = delay + 2; % delai introduit par le filtre derivant

%%% Squared
ecg_4 = ecg_3.^2;

%%% Moving Window Integration
N = 0.15 * Fs -1; % double of the width of an average QRS complex = 0.15s = 0.15 * Fs points
% -1 pour avoir un delay entier lorsqu'on calcule le delai
Smwi = (1/N)*conv(ones(1,N),ecg_4);
figure;
plot(Smwi);
title('Smwi');
delay = delay + (N-1)/2; % la fenetre introduit un delai de (N-1)/2

delay_vector = zeros(1,delay); %creation du vecteur delai
delay_vector(1,delay)=1; % mise en place d'un dirac a la position delay
ecg_2_delay = conv(ecg_2,delay_vector);% ajout du delai a la sortie du filtre passe_bande


%%% Thresholding
th = mean(Smwi); % seuil arbitraire
 for i=1:length(Smwi)
     if (Smwi(1,i) < th)  
         Smwi(1,i)=0;
     end
 end
 
 %%% Locations of R, Q and S
i=1;
R_locs_PT = [];
Q_locs_PT = [];
S_locs_PT = [];

while i<length(ecg_2_delay)
     if Smwi(i)~=0 % si on trouve un complexe
         complex_start = i;
         j=i;
         while Smwi(j)~=0 % on va chercher la fin du complexe
             j=j+1;
         end
         complex_end=j;
         
         % Locations of R inside complex i:j (max search)
         [max_value max_pos]=max(ecg_2_delay(complex_start:complex_end));
         R_locs_PT = [R_locs_PT max_pos+complex_start-1];
         
         % Locations of Q inside complex i:j (previous min search)
         [min_value min_pos]=min(ecg_2_delay(complex_start:complex_start+max_pos));
         Q_locs_PT = [Q_locs_PT min_pos+complex_start-1];
         
         
         % Locations of S inside complex i:j (next min search)
         [min_value min_pos]=min(ecg_2_delay(complex_start+max_pos:complex_end));
         S_locs_PT = [S_locs_PT min_pos+complex_start+max_pos-1];
         
         i=j; % on reprend la recherche apres le complexe
     else
        i=i+1;
     end
end
 
% comparaison  du signal ecg apres passe bande et apres traitement
figure;
hold on; plot(ecg_2_delay/max(ecg_2)); plot(Smwi/max(Smwi)); hold off

% compensation du retard des positions des ondes QRS pour etre en accord
% avec les donnees data
delay_tot = delay + delay_bandpass; % delai total de la methode de pan and tompkins
R_locs_PT = R_locs_PT ;

% affichage des points sur l'ecg apr�s le passe bande
figure;
 time_segment = (1:length(ecg_2_delay))/Fs;
 h = plot(time_segment, ecg_2_delay); grid on;
 hold on;
plot(time_segment(R_locs_PT),ecg_2_delay(R_locs_PT), '*','Color','red'); text(ecg_2_delay(R_locs_PT),ecg_2_delay(R_locs_PT),' R ','Color','red','FontSize',14);
%plot(time_segment_data(Q_locs_PT),data(Q_locs_PT), '*','Color','blue'); text(data(Q_locs_PT),data(Q_locs_PT),' Q ','Color','blue','FontSize',14);
%plot(time_segment_data(S_locs_PT),data(S_locs_PT), '*','Color','green'); text(data(S_locs_PT),data(S_locs_PT),' S ','Color','green','FontSize',14);
 hold off;
 xlabel('Time (s)');
 ylabel('Magnitude');
 title('ECG segment_ecg characteristic')

 %%% Locations of T and P
delay2 = 0;
ecg_5 = filter([1 0 0 0 0 0 -1], [1], data);
delay2 = delay2 + 3;
ecg_6 = filter([1 0 0 0 0 0 0 0 -1], [1 -1], ecg_5);
delay2 = delay2 + 4;

delay_vector = zeros(1,delay); % creation du vecteur delai
delay_vector(1,delay)=1; % mise en place d'un dirac a la position delay
ecg_delay2 = conv(data,delay_vector);% ajout du delai a la sortie du filtre passe_bande

% T_locs_new = [];
% for i=1:length(R_locs_PT)-1
%    % Etude de l'intervalle R(i)->R(i+1) 
%    RR_start = S_locs_PT(i);
%    RR_end = R_locs_PT(i) + round((R_locs_PT(i+1)-R_locs_PT(i))*0.7);
%    [maxs_value, maxs_pos] = findpeaks(ecg_6(RR_start:RR_end));
%    [max_value, max_pos] = max(ecg_2_delay(RR_start+maxs_pos));
%    max_pos = RR_start + max_pos;
%    T_locs_new = [T_locs_new max_pos-1];
% end


%figure;
%hold on; plot(ecg_2_delay2/max(ecg_2_delay2)); plot(ecg_6/max(ecg_6)); hold off

% plot final de l'ecg avec les points trouves
%  figure;
%  time_segment_data = (1:length(data))/Fs;
%  h = plot(time_segment_data, data); grid on;
%  hold on;
% % plot(time_segment_ecg(P_ecg_loc),segment_ecg(P_ecg_loc), '*','Color','red'); text(time_segment_ecg(P_ecg_loc),segment(P_ecg_loc),' P ','Color','red','FontSize',14);
% plot(time_segment_data(R_locs_PT),data(R_locs_PT), '*','Color','red'); text(data(R_locs_PT),data(R_locs_PT),' R ','Color','red','FontSize',14);
% %plot(time_segment_data(Q_locs_PT),data(Q_locs_PT), '*','Color','blue'); text(data(Q_locs_PT),data(Q_locs_PT),' Q ','Color','blue','FontSize',14);
% %plot(time_segment_data(S_locs_PT),data(S_locs_PT), '*','Color','green'); text(data(S_locs_PT),data(S_locs_PT),' S ','Color','green','FontSize',14);
% %plot(time_segment_ecg(T_locs_PT),ecg_2_delay(T_locs_PT), '*','Color','red'); text(ecg_2_delay(T_locs_PT),ecg_2_delay(T_locs_PT),' T ','Color','red','FontSize',14);
%  hold off;
%  xlabel('Time (s)');
%  ylabel('Magnitude');
%  title('ECG segment_ecg characteristic')
