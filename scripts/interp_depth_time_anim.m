%% interp_depth_time_anim.m
%% 功能: 东海区域 → 垂向插值到目标深度 → 时间插值到6h → GIF动图
%%
%% 修改以下参数即可适配不同深度/区域:
%%   z_target  — 目标深度(米)
%%   lo1/lo2/la1/la2 — 区域边界
%%   NC_FILE   — NetCDF 文件路径
%%   HOUR_STEP — 时间插值分辨率(小时)
%% ========================================================================
clc; clear; close all;

addpath('E:\matlab_project\test\test2');          % plot_sst_map.m
addpath('E:\matlab_2025b\toolbox\m_map');          % m_map 工具箱
NC_FILE = 'E:\matlab_project\test\test2\cmems_mod_glo_phy-all_my_0.25deg_P1D-m_1783733214798.nc';

%% ====== 参数设置 ======
OUT_DIR = 'E:\matlab_project\test\test3\output\';
mkdir(OUT_DIR);

% 目标区域 (东海)
lo1 = 117; lo2 = 135; la1 = 25; la2 = 41;
ex = 2;  % 外扩2度防止插值边缘白边

% ===== 修改以下参数适配不同任务 =====
z_target = 50;       % 目标深度 (米)
HOUR_STEP = 6;       % 时间插值分辨率 (小时)
% ===================================

%% ====== 1. 读取坐标 ======
fprintf('=== 第1步 读取坐标 ===\n');
lon_all = ncread(NC_FILE, 'longitude');
lat_all = ncread(NC_FILE, 'latitude');
depth_all = ncread(NC_FILE, 'depth');
time_raw = ncread(NC_FILE, 'time');
time_dn = datenum(datetime(time_raw, 'ConvertFrom', 'posixtime'));
time_dt = datetime(time_dn, 'ConvertFrom', 'datenum');
ndepth = length(depth_all);
ntime = length(time_raw);

%% ====== 2. 裁剪区域 (外扩) ======
elo1 = lo1 - ex; elo2 = lo2 + ex;
ela1 = la1 - ex; ela2 = la2 + ex;
[~, i1] = min(abs(lon_all - elo1));
[~, i2] = min(abs(lon_all - elo2));
[~, j1] = min(abs(lat_all - ela1));
[~, j2] = min(abs(lat_all - ela2));
lon = lon_all(i1:i2); lat = lat_all(j1:j2);
nlon = length(lon); nlat = length(lat);

%% ====== 3. 读取数据 ======
thetao = ncread(NC_FILE, 'thetao_glor', ...
    [i1, j1, 1, 1], [nlon, nlat, ndepth, ntime]);

%% ====== 4. 垂向插值 ======
fprintf('\n=== 第4步 垂向插值 --> %.0f m ===\n', z_target);
z_query = min(max(z_target, min(depth_all)), max(depth_all));
sst_depth = NaN(nlon, nlat, ntime);
tic;
for i = 1:nlon
    for j = 1:nlat
        for t = 1:ntime
            prof = squeeze(thetao(i, j, :, t));
            if all(isnan(prof)), continue; end
            valid = ~isnan(prof);
            if sum(valid) < 2, continue; end
            sst_depth(i, j, t) = interp1(depth_all(valid), prof(valid), ...
                                        z_query, 'linear');
        end
    end
    if mod(i, 20) == 0
        fprintf('  进度: %d/%d lon, %.1f s\n', i, nlon, toc);
    end
end
fprintf('  垂向插值完成 (%.1f s)\n', toc);

%% ====== 5. 时间插值: 每日 --> %d-hourly ======
fprintf('\n=== 第5步 时间插值 --> %d-hourly ===\n', HOUR_STEP);
time_6h = time_dn(1):(HOUR_STEP/24):time_dn(end);
nt_6h = length(time_6h);
sst_6h = NaN(nlon, nlat, nt_6h);
tic;
for i = 1:nlon
    for j = 1:nlat
        ts = squeeze(sst_depth(i, j, :));
        if all(isnan(ts)), continue; end
        valid = ~isnan(ts);
        if sum(valid) < 2, continue; end
        sst_6h(i, j, :) = interp1(time_dn(valid), ...
            double(ts(valid)), time_6h, 'linear');
    end
    if mod(i, 20) == 0
        fprintf('  进度: %d/%d lon, %.1f s\n', i, nlon, toc);
    end
end
fprintf('  时间插值完成 (%.1f s)\n', toc);

%% ====== [可选] 6. 异常场计算 ======
% 启用异常: 用异常代替绝对值, 使动图变化更明显
USE_ANOMALY = true;  % false = 使用绝对温度

if USE_ANOMALY
    sst_mean = mean(sst_6h, 3, 'omitnan');
    plot_data = sst_6h - sst_mean;
    anom_max = max(abs(plot_data(:)));
    caxis_val = [-ceil(anom_max*2)/2, ceil(anom_max*2)/2];
    cb_label = 'SST Anomaly ({\circ}C)';
    plot_title_prefix = 'Anomaly';
else
    plot_data = sst_6h;
    caxis_val = [floor(min(sst_6h(:))), ceil(max(sst_6h(:)))];
    cb_label = 'SST ({\circ}C)';
    plot_title_prefix = '';
end

%% ====== 7. 保存结果 ======
save(fullfile(OUT_DIR, 'interp_data.mat'), ...
    'lon', 'lat', 'z_target', 'time_6h', 'sst_6h');

%% ====== 8. 画 GIF 动图 ======
% 裁剪到目标范围
[~, i_lo1] = min(abs(lon - lo1));
[~, i_lo2] = min(abs(lon - lo2));
[~, i_la1] = min(abs(lat - la1));
[~, i_la2] = min(abs(lat - la2));
lon_plot = lon(i_lo1:i_lo2);  lat_plot = lat(i_la1:i_la2);
plot_frames = plot_data(i_lo1:i_lo2, i_la1:i_la2, :);
plot_frames = permute(plot_frames, [2, 1, 3]);  % (lat, lon, time)

frame_dir = fullfile(OUT_DIR, sprintf('frames_%dm_%dh\\', z_target, HOUR_STEP));
mkdir(frame_dir);

time_6h_dt = datetime(time_6h, 'ConvertFrom', 'datenum');
for t = 1:nt_6h
    sst_frame = plot_frames(:, :, t);
    title_text = sprintf('East China Sea  %d m  %s', z_target, datestr(time_6h_dt(t)));
    % 调用 plot_sst_map，传递色标标签 (cb_label)
    plot_sst_map(lon_plot, lat_plot, sst_frame, title_text, caxis_val, ...
        sprintf('%s %dm %dh', plot_title_prefix, z_target, HOUR_STEP), cb_label);
    fname = sprintf('frame_%dm_t%03d.png', z_target, t);
    % 输出 TIFF (顶刊首选) 或 PNG
    print(gcf, '-dtiffn', '-r300', fullfile(frame_dir, fname));
    close(gcf);
    if mod(t, 5) == 0, fprintf('  帧 %d/%d\n', t, nt_6h); end
end

% 合成 GIF
gif_path = fullfile(OUT_DIR, sprintf('sst_%dm_%dh.gif', z_target, HOUR_STEP));
for t = 1:nt_6h
    [idx, cmap] = rgb2ind(imread(fullfile(frame_dir, ...
        sprintf('frame_%dm_t%03d.tif', z_target, t))), 256);
    if t == 1
        imwrite(idx, cmap, gif_path, 'gif', 'Loopcount', inf, 'DelayTime', 0.4);
    else
        imwrite(idx, cmap, gif_path, 'gif', 'WriteMode', 'append', 'DelayTime', 0.4);
    end
end
fprintf('\n  GIF: %s\n', gif_path);
fprintf('  全部完成！\n');

