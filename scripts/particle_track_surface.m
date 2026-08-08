%% particle_track_surface.m
%% 表层粒子追踪模型（初步版）
%% ========================================================================
%% 功能:
%%   1. 读取 CMEMS 每日流速 (GLORYS uo_glor / vo_glor)
%%   2. 把每日流速在时间上线性插值到逐小时
%%   3. 从台湾东北部起点开始, 逐小时积分追踪粒子位置
%%   4. 用 m_map 画轨迹动图并合成 GIF
%%
%% 说明:
%%   - 只考虑表层 (Z_IDX=1), 不考虑垂向运动
%%   - 当前数据: 2024-12-15 ~ 2024-12-31 (17天, 每天一个场)
%%   - 积分方式默认 RK4, 可改成 'euler' 对比
%% ========================================================================

clc; clear; close all;

addpath('E:\matlab_2025b\toolbox\m_map');

%% ====== 配置区 ======
NC_FILE  = 'E:\matlab_project\test\test5\cmems_mod_glo_phy-all_my_0.25deg_P1D-m_1785640011786.nc';
OUT_DIR  = 'E:\matlab_project\test\test5\output_15d\';
if ~exist(OUT_DIR, 'dir')
    mkdir(OUT_DIR);
end

U_VAR = 'uo_glor';          % 东向流速变量 (GLORYS 集合成员)
V_VAR = 'vo_glor';          % 北向流速变量
Z_IDX = 1;                  % 表层索引: 第一层, 中心约 0.5 m

LON0       = 122.5;         % 起点经度 (台湾东北部)
LAT0       = 25.5;          % 起点纬度
START_DATE = [];            % 空 = 从数据第一个时刻开始; 也可写 datetime(2024,12,15,0,0,0)

TRACK_HOURS = 15*24;        % 最多追踪 15 天 (360 小时)
HOUR_STEP   = 1;            % 积分/输出时间步 (小时)
INTEGRATOR  = 'rk4';        % 'rk4' 或 'euler'

MAP_RANGE  = [120 127 22 32]; % 地图范围 [lon_min lon_max lat_min lat_max]
SPEED_MAX  = 1.5;             % 流速色标上限 (m/s), 所有帧固定
DELAY_TIME = 0.15;            % GIF 每帧间隔 (秒)
FRAME_DPI  = 150;             % 单帧 PNG 分辨率
FINAL_DPI  = 300;             % 顶刊静态图分辨率
DECIMATE   = 4;               % 矢量箭头抽稀间隔
VREF       = 0.5;             % 参考矢量大小 (m/s)
MAKE_GIF   = true;            % true = 画动图; false = 只算轨迹并保存

%% ====== 1. 读取数据 ======
fprintf('=== Step 1: read data ===\n');
lon = ncread(NC_FILE, 'longitude');
lat = ncread(NC_FILE, 'latitude');
depth = ncread(NC_FILE, 'depth');
tim_raw = ncread(NC_FILE, 'time');

nlon = numel(lon);
nlat = numel(lat);
nt   = numel(tim_raw);

uo_all = ncread(NC_FILE, U_VAR);   % MATLAB 读取维度顺序: (lon,lat,depth,time)
vo_all = ncread(NC_FILE, V_VAR);
assert(size(uo_all,1)==nlon && size(uo_all,2)==nlat && ...
       size(uo_all,3)>=Z_IDX && size(uo_all,4)==nt, ...
       '维度顺序与预期不符, 请检查 ncread 输出');

uo_surf = double(squeeze(uo_all(:,:,Z_IDX,:)));  % (lon,lat,time)
vo_surf = double(squeeze(vo_all(:,:,Z_IDX,:)));

time_dn = datenum(datetime(tim_raw, 'ConvertFrom', 'posixtime'));  % UTC 时间
fprintf('  Grid: %d lon x %d lat, depth %d layers, %d days\n', ...
        nlon, nlat, numel(depth), nt);
fprintf('  Time: %s ~ %s (UTC)\n', datestr(time_dn(1)), datestr(time_dn(end)));
fprintf('  Surface layer center: %.2f m\n', depth(Z_IDX));

%% ====== 2. 时间插值: 每日 -> 每小时 ======
fprintf('=== Step 2: time interpolation daily -> hourly ===\n');
time_hr_dn = time_dn(1):(HOUR_STEP/24):time_dn(end);
nthr = numel(time_hr_dn);

% 把 (lon,lat,time) 重排成 (time, lon*lat), 一次 interp1 完成全部格点
Umat = reshape(permute(uo_surf, [3 1 2]), nt, []);
Vmat = reshape(permute(vo_surf, [3 1 2]), nt, []);
uo_hr = permute(reshape(interp1(time_dn, Umat, time_hr_dn, 'linear'), ...
                        [nthr nlon nlat]), [2 3 1]);   % (lon,lat,hour)
vo_hr = permute(reshape(interp1(time_dn, Vmat, time_hr_dn, 'linear'), ...
                        [nthr nlon nlat]), [2 3 1]);
fprintf('  %d days -> %d hourly steps\n', nt, nthr);

%% ====== 3. 粒子追踪 ======
if isempty(START_DATE)
    start_dn = time_dn(1);
else
    start_dn = datenum(START_DATE);
end
[~, start_idx] = min(abs(time_hr_dn - start_dn));
start_idx = max(start_idx, 1);

% 数据末尾之后没有流速, 不能继续积分
max_hours = nthr - start_idx;
TRACK_HOURS = min(TRACK_HOURS, max_hours);
fprintf('=== Step 3: integrate particle (%s, %d h) ===\n', INTEGRATOR, TRACK_HOURS);

traj = NaN(TRACK_HOURS+1, 2);
traj(1,:) = [LON0, LAT0];
lonp = LON0;
latp = LAT0;
last_valid = 1;

for k = 1:TRACK_HOURS
    t_now = time_hr_dn(start_idx + k - 1);
    dt_dn = HOUR_STEP/24;

    if strcmpi(INTEGRATOR, 'rk4')
        % RK4: 每步取 4 个斜率, 比欧拉法更稳
        [u1, v1] = velocity_at(lon, lat, uo_hr, vo_hr, time_hr_dn, ...
                               t_now, lonp, latp);
        [du1, dv1] = vel_to_deg(u1, v1, latp);

        [u2, v2] = velocity_at(lon, lat, uo_hr, vo_hr, time_hr_dn, ...
                               t_now + 0.5*dt_dn, lonp + 0.5*du1, latp + 0.5*dv1);
        [du2, dv2] = vel_to_deg(u2, v2, latp + 0.5*dv1);

        [u3, v3] = velocity_at(lon, lat, uo_hr, vo_hr, time_hr_dn, ...
                               t_now + 0.5*dt_dn, lonp + 0.5*du2, latp + 0.5*dv2);
        [du3, dv3] = vel_to_deg(u3, v3, latp + 0.5*dv2);

        [u4, v4] = velocity_at(lon, lat, uo_hr, vo_hr, time_hr_dn, ...
                               t_now + dt_dn, lonp + du3, latp + dv3);
        [du4, dv4] = vel_to_deg(u4, v4, latp + dv3);

        if any(isnan([u1 v1 u2 v2 u3 v3 u4 v4]))
            fprintf('  Particle left data domain after %d h\n', k-1);
            break;
        end

        dlon = (du1 + 2*du2 + 2*du3 + du4) / 6;
        dlat = (dv1 + 2*dv2 + 2*dv3 + dv4) / 6;
    else
        % 欧拉法: x(t+dt) = x(t) + v*dt
        [u, v] = velocity_at(lon, lat, uo_hr, vo_hr, time_hr_dn, ...
                             t_now, lonp, latp);
        if isnan(u)
            fprintf('  Particle left data domain after %d h\n', k-1);
            break;
        end
        [dlon, dlat] = vel_to_deg(u, v, latp);
    end

    lonp = lonp + dlon;
    latp = latp + dlat;
    traj(k+1,:) = [lonp, latp];
    last_valid = k + 1;
end

traj = traj(1:last_valid, :);
fprintf('  Tracked %d hours, final position: %.4fE, %.4fN\n', ...
        last_valid-1, traj(end,1), traj(end,2));

% 保存轨迹结果, 之后可以只读 .mat 分析, 不必重跑全部帧
save(fullfile(OUT_DIR, 'track_result.mat'), ...
     'lon', 'lat', 'time_dn', 'time_hr_dn', 'traj', ...
     'LON0', 'LAT0', 'start_idx', 'last_valid', ...
     'INTEGRATOR', 'HOUR_STEP', 'TRACK_HOURS');

%% ====== 4. 画轨迹动图 + 合成 GIF ======
if MAKE_GIF
fprintf('=== Step 4: draw animation + GIF ===\n');
frame_dir = fullfile(OUT_DIR, 'frames_track');
if ~exist(frame_dir, 'dir')
    mkdir(frame_dir);
end
gif_path = fullfile(OUT_DIR, 'particle_track_surface.gif');

for k = 1:last_valid
    tq = time_hr_dn(start_idx + k - 1);
    spd = sqrt(uo_hr(:,:,start_idx+k-1).^2 + vo_hr(:,:,start_idx+k-1).^2)';
    spd = fill_nan_field(spd);   % 仅画图: 用周围格点预测并填充 NaN

    figure('Visible','off','Units','centimeters','Position',[2 2 10 11]);
    m_proj('mercator', 'lon', MAP_RANGE(1:2), 'lat', MAP_RANGE(3:4));
    m_pcolor(lon, lat, spd);
    shading interp;
    colormap(parula(256));
    caxis([0 SPEED_MAX]);
    hold on;

    m_gshhs('i', 'patch', [0.7 0.7 0.7], 'edgecolor', [0.3 0.3 0.3], 'linewidth', 0.4);

    % 已走过的轨迹
    if k >= 2
        m_line(traj(1:k,1), traj(1:k,2), 'color', [0.85 0.33 0.10], ...
               'linewidth', 1.6);
    end
    % 起点 (绿色) 和当前粒子 (红色)
    m_line(LON0, LAT0, 'marker', 'o', 'markersize', 8, ...
           'color', [0.0 0.55 0.0], 'linestyle', 'none');
    m_line(traj(k,1), traj(k,2), 'marker', 'o', 'markersize', 8, ...
           'color', [0.85 0.10 0.10], 'linestyle', 'none');
    hold off;

    m_grid('box','on','tickdir','out','fontsize',9, ...
           'linestyle',':','linewidth',0.4,'gridcolor',[0.5 0.5 0.5]);
    cb = colorbar;
    set(cb, 'FontSize', 10, 'LineWidth', 0.4);
    ylabel(cb, 'Speed (m/s)', 'FontSize', 10);
    title(sprintf('Surface Particle %s UTC', ...
          datestr(datetime(tq,'ConvertFrom','datenum'), 'yyyy-mm-dd HH:MM')), ...
          'FontSize', 12, 'FontWeight', 'bold');

    fname = fullfile(frame_dir, sprintf('frame_h%04d.png', k-1));
    print(gcf, '-dpng', sprintf('-r%d', FRAME_DPI), fname);
    close(gcf);

    % 逐帧写入 GIF
    [idx, cm] = rgb2ind(imread(fname), 256);
    if k == 1
        imwrite(idx, cm, gif_path, 'gif', 'Loopcount', inf, 'DelayTime', DELAY_TIME);
    else
        imwrite(idx, cm, gif_path, 'gif', 'WriteMode', 'append', 'DelayTime', DELAY_TIME);
    end
    if mod(k, 12) == 0
        fprintf('  Frame %d/%d\n', k, last_valid);
    end
end

% 最后再存一张完整轨迹静态图
figure('Visible','off','Units','centimeters','Position',[2 2 12 13]);
m_proj('mercator', 'lon', MAP_RANGE(1:2), 'lat', MAP_RANGE(3:4));
spd0 = sqrt(uo_hr(:,:,start_idx).^2 + vo_hr(:,:,start_idx).^2)';
spd0 = fill_nan_field(spd0);   % 仅画图: 用周围格点预测并填充 NaN
m_pcolor(lon, lat, spd0);
shading interp;
colormap(parula(256));
caxis([0 SPEED_MAX]);
hold on;

% 流速矢量箭头 (抽稀) + 参考矢量
uo0 = uo_hr(:,:,start_idx)';
vo0 = vo_hr(:,:,start_idx)';
iq = 1:DECIMATE:nlon;
jq = 1:DECIMATE:nlat;
u_q = uo0(jq,iq);
v_q = vo0(jq,iq);
[lon_q, lat_q] = meshgrid(lon(iq), lat(jq));
m_quiver(lon_q, lat_q, u_q, v_q, 'color', [0.2 0.2 0.2], ...
         'AutoScaleFactor', 0.6, 'linewidth', 0.4);
rx = max(lon) - 1.5;
ry = min(lat) + 1;
m_quiver(rx, ry, VREF, 0, 'color', [0.2 0.2 0.2], ...
         'AutoScaleFactor', 0.6, 'linewidth', 0.8);
text(rx + 0.3, ry, sprintf('%.1f m/s', VREF), 'FontSize', 11, 'FontWeight', 'bold');

m_gshhs('i', 'patch', [0.7 0.7 0.7], 'edgecolor', [0.3 0.3 0.3], 'linewidth', 0.4);
m_line(traj(:,1), traj(:,2), 'color', [0.85 0.33 0.10], 'linewidth', 2.0);
m_line(LON0, LAT0, 'marker', 'o', 'markersize', 8, ...
       'color', [0.0 0.55 0.0], 'linestyle', 'none');
m_line(traj(end,1), traj(end,2), 'marker', 'o', 'markersize', 10, ...
       'color', [0.85 0.10 0.10], 'linestyle', 'none');
hold off;
m_grid('box','on','tickdir','out','fontsize',11, ...
       'linestyle',':','linewidth',0.4,'gridcolor',[0.5 0.5 0.5]);
cb = colorbar;
set(cb, 'FontSize', 12, 'LineWidth', 0.5);
ylabel(cb, 'Speed (m/s)', 'FontSize', 12);
title(sprintf('Particle Track %s -> %s UTC', ...
      datestr(datetime(time_hr_dn(start_idx),'ConvertFrom','datenum'),'yyyy-mm-dd HH:MM'), ...
      datestr(datetime(time_hr_dn(start_idx+last_valid-1),'ConvertFrom','datenum'),'yyyy-mm-dd HH:MM')), ...
      'FontSize', 15, 'FontWeight', 'bold');
print(gcf, '-dpng', sprintf('-r%d', FINAL_DPI), fullfile(OUT_DIR, 'particle_track_final.png'));
close(gcf);

fprintf('  GIF: %s\n', gif_path);
end
fprintf('All done\n');

%% ========================================================================
%% 局部函数
%% ========================================================================

%% 用周围有效格点预测并填充 NaN (regionfill 拉普拉斯补值)
% 只用于画图平滑, 不参与粒子轨迹积分
function F = fill_nan_field(F)
    nanmask = isnan(F);
    if ~any(nanmask(:))
        return;
    end
    F(nanmask) = 0;
    F = regionfill(F, nanmask);
end

%% 查询 (lon,lat) 在 tq 时刻的流速
% 先在时间上找相邻两个小时, 再分别做空间线性插值, 最后时间线性插值
function [u, v] = velocity_at(lon, lat, uo_hr, vo_hr, time_hr_dn, tq, lonq, latq)
    if lonq < min(lon) || lonq > max(lon) || ...
       latq < min(lat) || latq > max(lat) || ...
       tq < time_hr_dn(1) || tq > time_hr_dn(end)
        u = NaN;
        v = NaN;
        return;
    end

    idx = find(time_hr_dn <= tq, 1, 'last');
    idx = min(max(idx, 1), numel(time_hr_dn) - 1);
    frac = (tq - time_hr_dn(idx)) / (time_hr_dn(idx+1) - time_hr_dn(idx));

    % uo_hr(:,:,k) 是 (lon,lat), interp2 需要 (lat,lon) 矩阵
    u1 = interp2(lon, lat, uo_hr(:,:,idx)', lonq, latq, 'linear');
    u2 = interp2(lon, lat, uo_hr(:,:,idx+1)', lonq, latq, 'linear');
    v1 = interp2(lon, lat, vo_hr(:,:,idx)', lonq, latq, 'linear');
    v2 = interp2(lon, lat, vo_hr(:,:,idx+1)', lonq, latq, 'linear');

    u = u1 + frac * (u2 - u1);
    v = v1 + frac * (v2 - v1);
end

%% 把 (u,v) 每小时位移换算成经/纬度增量
function [dlon, dlat] = vel_to_deg(u, v, lat)
    sec_per_hour = 3600;
    m_per_deg_lat = 111320;
    m_per_deg_lon = 111320 * cosd(lat);
    dlon = u * sec_per_hour / m_per_deg_lon;
    dlat = v * sec_per_hour / m_per_deg_lat;
end
