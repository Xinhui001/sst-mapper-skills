%% plot_sst.m - CMEMS SST plot with m_map
% Load sst_data.mat, produce publication-quality SST map.
% Adjust LON, LAT, SST_RANGE, TITLE per task.

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

%% Map
figure('Position', [100, 100, 1200, 900]);
m_proj('mercator', 'lon', LON_RANGE, 'lat', LAT_RANGE);

m_pcolor(lon, lat, sst);
shading interp;
colormap(jet);
caxis(SST_RANGE);

hold on;
m_gshhs('i', 'patch', [0.7 0.7 0.7], 'edgecolor', [0.3 0.3 0.3], 'linewidth', 0.4);

m_grid('box', 'on', 'tickdir', 'out', 'fontsize', 13, ...
       'linestyle', ':', 'linewidth', 0.3, 'gridcolor', [0.5 0.5 0.5]);

cb = colorbar;
set(cb, 'FontSize', 12, 'FontWeight', 'bold');
ylabel(cb, 'SST ({\circ}C)', 'FontSize', 14);

title(TITLE_STR, 'FontSize', 16, 'FontWeight', 'bold');
hold off;
