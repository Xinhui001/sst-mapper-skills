function plot_sst_map(lon, lat, sst, title_text, caxis_val, fig_name, cb_label)
%% plot_sst_map.m - m_map publication-grade SST / anomaly map
%
%  Usage:
%    plot_sst_map(lon, lat, sst, 'Title', [cmin cmax])
%    plot_sst_map(lon, lat, sst, 'Title', [cmin cmax], 'FigName')
%    plot_sst_map(lon, lat, sst, 'Title', [cmin cmax], 'FigName', 'CBLabels')
%
%  Top-journal standards applied:
%    - Figure in cm, fits single column (89 mm)
%    - Colormap: brewermap RdBu (diverging) / parula (sequential), never jet
%    - Font sizes: title 8pt, everything else 7pt
%    - Colorbar ticks explicitly set, aligned to 0.5 or integer
%    - Land: [0.7 0.7 0.7], coastline: dark gray thin

if nargin < 6
    fig_name = 'SST Map';
end
if nargin < 7
    if caxis_val(1) < 0 && caxis_val(2) > 0 && ...
       abs(caxis_val(1) + caxis_val(2)) < 0.1 * (caxis_val(2) - caxis_val(1))
        cb_label = 'SST Anomaly ({\circ}C)';
    else
        cb_label = 'SST ({\circ}C)';
    end
end

%% Figure (cm, single-column 89 mm, 300 dpi)
figure('Visible', 'off', 'Name', fig_name, 'NumberTitle', 'off', ...
       'Units', 'centimeters', 'Position', [2, 2, 8.9, 6.5]);

%% Projection
m_proj('mercator', 'lon', [min(lon) max(lon)], 'lat', [min(lat) max(lat)]);

%% Fill
m_pcolor(lon, lat, sst);
shading interp;

%% Colormap (never jet; parula or RdBu only)
try
    cmap = brewermap(256, 'RdBu');
    colormap(flipud(cmap));
catch
    colormap(parula(256));
end
caxis(caxis_val);

%% Land
hold on;
m_gshhs('i', 'patch', [0.7 0.7 0.7], 'edgecolor', [0.3 0.3 0.3], 'linewidth', 0.3);
hold off;

%% Grid (font 7pt for single-column)
m_grid('box', 'on', 'tickdir', 'out', 'fontsize', 7, ...
       'linestyle', ':', 'linewidth', 0.3, 'gridcolor', [0.5 0.5 0.5]);

%% Colorbar (font 7pt, explicit ticks)
cb = colorbar;
ylabel(cb, cb_label, 'FontSize', 7, 'FontWeight', 'bold');
set(cb, 'FontSize', 7, 'LineWidth', 0.3);
cmin = caxis_val(1); cmax = caxis_val(2);
step = 0.5;
if cmax - cmin > 10
    step = 2;
end
cb.Ticks = ceil(cmin/step)*step:step:floor(cmax/step)*step;

%% Title (font 8pt)
title(title_text, 'FontSize', 8, 'FontWeight', 'bold');

end

