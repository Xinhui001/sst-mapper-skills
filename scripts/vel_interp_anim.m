%% vel_interp_anim.m
%% 东海 50m 垂直插值 + 6h 时间插值 + 流速矢量动图
%%
%% 步骤:
%%   1. 读取 uo_glor/vo_glor
%%   2. 垂向插值 (permute+reshape+interp1) 到 50m
%%   3. 时间插值 (permute+reshape+interp1) 到 6h
%%   4. m_pcolor 流速 + m_quiver 矢量 + GIF
%% ========================================================================
clc; clear; close all;

addpath('E:\matlab_project\test\test2');
addpath('E:\matlab_2025b\toolbox\m_map');
NC_FILE='E:\matlab_project\test\test4\cmems_mod_glo_phy-all_my_0.25deg_P1D-m_1785316779916.nc';
OUT_DIR='E:\matlab_project\test\test4\output\';
mkdir(OUT_DIR);

%% ====== 参数设置 ======
Z_TARGET=50;        % 目标深度 (m)
HOUR_STEP=6;        % 时间插值分辨率 (h)
DECIMATE=4; VREF=0.5;
T_MAX_SPEED=1.5;    % 色标上限 (m/s)

%% ====== 1. 读取坐标 ======
fprintf('=== Step 1: read coordinates ===\n');
lon=ncread(NC_FILE,'longitude');
lat=ncread(NC_FILE,'latitude');
depth=ncread(NC_FILE,'depth');
tim=ncread(NC_FILE,'time');
tdt=datetime(tim,'ConvertFrom','posixtime');
time_dn=datenum(tdt);
nlon=length(lon); nlat=length(lat); nd=length(depth); nt_orig=length(tim);
fprintf('  Grid: %d lon x %d lat, depth %d layers, %d time steps\n',nlon,nlat,nd,nt_orig);
fprintf('  Depth range: %.1f ~ %.1f m\n',min(depth),max(depth));
fprintf('  Time: %s ~ %s\n',datestr(tdt(1)),datestr(tdt(end)));

%% ====== 2. 垂向插值 (向量化) ======
fprintf('=== Step 2: vertical interp --> %d m ===\n',Z_TARGET); tic;
zq=min(max(Z_TARGET,min(depth)),max(depth));
uo_all=ncread(NC_FILE,'uo_glor');  % (lon,lat,depth,time)
vo_all=ncread(NC_FILE,'vo_glor');
fprintf('  uo_glor size: %s\n',mat2str(size(uo_all)));

% permute: (lon,lat,depth,time) -> (depth,lon,lat,time) -> (depth, lon*lat*time)
Yu=reshape(permute(uo_all,[3,1,2,4]),nd,[]);
Yv=reshape(permute(vo_all,[3,1,2,4]),nd,[]);
uo_z=reshape(interp1(depth,Yu,zq,'linear'),[nlon,nlat,nt_orig]);
vo_z=reshape(interp1(depth,Yv,zq,'linear'),[nlon,nlat,nt_orig]);
fprintf('  Vertical interp done (%.1f s)\n',toc);

%% ====== 3. 时间插值 (向量化) ======
fprintf('=== Step 3: time interp --> %dh ===\n',HOUR_STEP); tic;
time_6h=time_dn(1):(HOUR_STEP/24):time_dn(end); nt_6h=length(time_6h);
fprintf('  %d steps -> %d steps\n',nt_orig,nt_6h);

% permute: (lon,lat,time) -> (time,lon,lat) -> (time, lon*lat)
Yu=interp1(time_dn,reshape(permute(uo_z,[3,1,2]),nt_orig,[]),time_6h,'linear');
Yv=interp1(time_dn,reshape(permute(vo_z,[3,1,2]),nt_orig,[]),time_6h,'linear');
uo_6h=permute(reshape(Yu,[nt_6h,nlon,nlat]),[2,3,1]);  % (lon,lat,nt_6h)
vo_6h=permute(reshape(Yv,[nt_6h,nlon,nlat]),[2,3,1]);
time_6h_dt=datetime(time_6h,'ConvertFrom','datenum');
fprintf('  Time interp done (%.1f s)\n',toc);

%% ====== 4. 动图 ======
fprintf('=== Step 4: draw frames + GIF ===\n');
frame_dir=fullfile(OUT_DIR,'frames_50m_6h\'); mkdir(frame_dir);
gif_path=fullfile(OUT_DIR,'current_50m_6h.gif');
smx=T_MAX_SPEED;

for t=1:nt_6h
    uo=uo_6h(:,:,t)';  % (lon,lat) -> (lat,lon) for m_pcolor
    vo=vo_6h(:,:,t)';
    spd=sqrt(uo.^2+vo.^2);
    iq=1:DECIMATE:nlon; jq=1:DECIMATE:nlat;
    u_q=uo(jq,iq); v_q=vo(jq,iq);
    [lon_q,lat_q]=meshgrid(lon(iq),lat(jq));
    rx=max(lon)-1.5; ry=min(lat)+1;
    
    figure('Visible','off','Units','centimeters','Position',[2,2,8.9,10]);
    m_proj('mercator','lon',[min(lon) max(lon)],'lat',[min(lat) max(lat)]);
    m_pcolor(lon,lat,spd); shading interp;
    colormap(parula(256)); caxis([0 smx]); hold on;
    m_quiver(lon_q,lat_q,u_q,v_q,'color',[0.2 0.2 0.2],'AutoScaleFactor',0.6,'linewidth',0.3);
    m_quiver(rx,ry,VREF,0,'color',[0.2 0.2 0.2],'AutoScaleFactor',0.6,'linewidth',0.5);
    text(rx+0.3,ry,sprintf('%.1f m/s',VREF),'FontSize',7,'FontWeight','bold');
    m_gshhs('i','patch',[0.7 0.7 0.7],'edgecolor',[0.3 0.3 0.3],'linewidth',0.3);
    hold off;
    m_grid('box','on','tickdir','out','fontsize',7,'linestyle',':','linewidth',0.3,'gridcolor',[0.5 0.5 0.5]);
    cb=colorbar; set(cb,'FontSize',7,'LineWidth',0.3); ylabel(cb,'Speed (m/s)','FontSize',7);
    set(cb,'Ticks',0:0.1:smx);
    title(sprintf('Current 50m %s',datestr(time_6h_dt(t))),'FontSize',8,'FontWeight','bold');
    
    fname=sprintf('frame_50m_t%03d.png',t);
    print(gcf,'-dpng','-r300',fullfile(frame_dir,fname));
    close(gcf);
    if mod(t,5)==0, fprintf('  Frame %d/%d\n',t,nt_6h); end
end

fprintf('=== Compositing GIF ===\n');
for t=1:nt_6h
    [idx,cm]=rgb2ind(imread(fullfile(frame_dir,sprintf('frame_50m_t%03d.png',t))),256);
    if t==1
        imwrite(idx,cm,gif_path,'gif','Loopcount',inf,'DelayTime',0.3);
    else
        imwrite(idx,cm,gif_path,'gif','WriteMode','append','DelayTime',0.3);
    end
end
fprintf('  GIF: %s\n',gif_path);
fprintf('All done\n');
