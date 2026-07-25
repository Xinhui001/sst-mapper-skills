%% plot_sst.m - CMEMS SST publication-grade map using m_map
%  Apply top-journal standards: parula, cm-sized figure, 7-8pt fonts.
%  Adjust LON, LAT, SST_RANGE, TITLE per task.
clc; clear; close all;

%% CONFIG (edit per task)
M_MAP_PATH = 'E:\matlab_2025b\toolbox\m_map';
DATA_FILE  = 'sst_data.mat';
LON_RANGE  = [117 135];
LAT_RANGE  = [25 41];
SST_RANGE  = [18 32];
TITLE_STR  = 'East China Sea SST';

%% Setup
addpath(M_MAP_PATH);
load(DATA_FILE);
time = datetime(time_raw, 'ConvertFrom', 'posixtime');

%% Map (cm, single-column 89mm)
figure('Units', 'centimeters', 'Position', [2, 2, 8.9, 6.5]);
m_proj('mercator', 'lon', LON_RANGE, 'lat', LAT_RANGE);

m_pcolor(lon, lat, sst);
shading interp;
colormap(parula(256));          % top journals: never jet
caxis(SST_RANGE);

hold on;
m_gshhs('i', 'patch', [0.7 0.7 0.7], 'edgecolor', [0.3 0.3 0.3], 'linewidth', 0.3);

m_grid('box', 'on', 'tickdir', 'out', 'fontsize', 7, ...
       'linestyle', ':', 'linewidth', 0.3, 'gridcolor', [0.5 0.5 0.5]);

cb = colorbar;
set(cb, 'FontSize', 7, 'FontWeight', 'bold');
ylabel(cb, 'SST ({\circ}C)', 'FontSize', 7);

title(TITLE_STR, 'FontSize', 8, 'FontWeight', 'bold');
hold off;

