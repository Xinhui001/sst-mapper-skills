# m_map Style Reference

## Projections
- `mercator`: General mapping, low-latitude regions
- `miller`: Similar to mercator, better for global maps
- `lambert`: Mid-latitude regions

## Land & Coastline
- `m_gshhs('i', ...)`: Intermediate resolution (recommended)
- `m_gshhs('l', ...)`: Low resolution (faster)
- `m_gshhs('h', ...)`: High resolution (slower, more detail)
- Land color: `[0.7 0.7 0.7]` (neutral gray)

## Grid Options
- `linestyle: ':'` dotted, `'-'` solid, `'--'` dashed, `'none'` hidden
- `gridcolor: [0.5 0.5 0.5]` gray grid
- `xtick/ytick`: explicit tick positions
- `fontsize`: tick label size

## Colorbar
- Use `{\circ}C` for degree symbol in labels
- Prefer `parula` (perceptually uniform) over `jet` for data integrity
- `jet` is acceptable in some oceanography journals


## Diverging Colormap for Anomaly / 异常场发散色标

- Use when plotting temperature anomaly (deviation from mean)
- 适用于温度异常场（正值=暖异常，负值=冷异常）

### Recommended: brewermap RdBu
- Download: MATLAB FileExchange #120022
- Usage:
  ```matlab
  cmap = brewermap(256, 'RdBu');
  colormap(flipud(cmap));  % red=warm, blue=cool, white=no anomaly
  ```

### Symmetric caxis is required / 色标必须对称
- Calculate global max absolute anomaly:
  anom_max = max(abs(sst_anom(:)), [], 'omitnan')
- Round to nearest 0.5 for clean ticks:
  caxis_range = [-ceil(anom_max*2)/2, ceil(anom_max*2)/2]
- This ensures 0 (no anomaly) appears as white in the middle

### Fallback to jet
- If brewermap is not installed, use jet(256) as fallback
- try...catch block to handle missing toolbox

### Typical caxis values for anomaly
| Dataset | Typical Range | Unit |
|---------|-------------|------|
| East China Sea SST anomaly | -3 to +3 | deg C |
| Global SST anomaly | -5 to +5 | deg C |


## Font Sizing for Publication

For single-column figures (89mm wide at 300 dpi):

| Element | Size | MATLAB |
|---------|------|--------|
| Title | 8 pt | FontSize 8, FontWeight bold |
| Axis labels | 7 pt | FontSize 7 |
| Colorbar label | 7 pt | ylabel(cb, FontSize 7) |
| Colorbar ticks | 7 pt | set(cb, FontSize 7) |
| Grid numbers | 7 pt | m_grid(fontsize 7) |

## Output Format
- Color: print(gcf, -dtiffn, -r300, file.tif)
- Line art: print(gcf, -depsc, -r600, file.eps)
- GIF: rgb2ind + imwrite with DelayTime 0.4

## NaN Gap Handling / 缺测区处理

### Problem / 问题
- m_pcolor + shading interp 会把 NaN 晕染到相邻有效格点，导致大片白色假缺测。
- m_contourf 遇到 NaN 会自动断开等值线，白色只代表缺测，但边缘仍会留白。

### Recommended / 推荐（平滑底图）
先用 regionfill（Image Processing Toolbox）用周围有效格点预测并填充 NaN，再 shading interp：

```matlab
spd_fill = spd;
nanmask = isnan(spd_fill);
spd_fill(nanmask) = 0;
spd_fill = regionfill(spd_fill, nanmask);
m_pcolor(lon, lat, spd_fill);
shading interp;
```

- regionfill 是拉普拉斯图像修复：以缺测区边界有效格点为约束，逐格平滑填充。
- 只用于画图；粒子追踪/数值计算必须用原始场，不能跨陆地外推。

### Alternatives / 替代方案
- 检查缺测分布：shading flat 最诚实，白色只代表 NaN。
- griddata 线性插值：稀疏散点缺测可用，但 Delaunay 三角形可能跨过海峡/陆地，且凸包外返回 NaN。

## Colormap Decision Guide
| Data type | Recommended | Avoid |
|-----------|-------------|-------|
| Absolute SST | parula(256) | jet |
| SST anomaly | brewermap(256,RdBu) flipped | jet, parula |
| Bathymetry | demcmap or flipud(ocean) | jet |
| Difference fields | brewermap(256,BrBG) | rainbow |
