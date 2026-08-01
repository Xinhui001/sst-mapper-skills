---
name: sst-mapper
description: Generate publication-quality sea surface temperature (SST) maps from NetCDF data using MATLAB + m_map. Triggers on requests involving netcdf, sst, sea surface temperature, ocean data, m_map, interpolation, regional extraction, batch animation.
---

# SST Mapper

Process NetCDF SST data and create publication-quality maps using MATLAB + m_map.

## 关键教训（必须记住）

来自实际项目中的反复踩坑总结：

| 教训 | 说明 |
|------|------|
| **m_map 是默认选择** | 出图默认用 m_map（m_proj/m_pcolor/m_gshhs/m_grid），不要擅自换 imagesc |
| **ncread 可能出错** | 有些 NetCDF4 文件 ncread 返回全 NaN → 用 Python h5py 导出 .mat 再 load |
| **caxis 必须固定** | 多天循环/GIF时，先算全局 min/max，固定色标，否则无法跨天比较 |
| **注释要详细** | 用户可能是新手，每行代码的参数、含义都要解释 |
| **先问再决定** | 拿不准的（工具链、数据格式、方案选择），先问用户 |
| **GSHHS 数据需确认** | m_map 的 m_gshhs 需要 gshhs_*.b 文件，检查 m_map/data/ 是否齐全 |
| **抽取画图逻辑** | 重复的画图代码抽成函数，改样式只改一个文件 |

## 推荐项目结构

```
project/
├── README.md                  # 项目说明（文件用途、使用流程）
├── plot_sst_map.m             # 【函数】画海温图（其他脚本都调它）
├── extract_data.m             # 【提取】从NC切区域 → .mat
├── interp_plot.m              # 【单天】插值+看双图
├── animate_daily_raw.m        # 【批量】原始分辨率出图 + GIF
├── animate_daily_interp.m     # 【批量】插值后出图 + GIF
└── regional_sst_all.mat       # extract_data.m 生成的数据
```

### 各文件职责

| 文件 | 只做什么 | 不改什么 |
|------|---------|---------|
| `plot_sst_map.m` | 画图样式 | 数据逻辑 |
| `extract_data.m` | 切数据 | 画图 |
| `interp_plot.m` | 看单天 | 批量 |
| `animate_*.m` | 批量出图+GIF | 画图样式 |

## 工作流程

### 第一步：确认需求

必问 6 项：

1. **文件路径** — NC 文件在哪？
2. **区域范围** — lat/lon 边界？
3. **时间** — 哪个时间步或日期范围？
4. **深度** — 表层还是指定深度？
5. **用途** — 期刊出图 / 快速预览？
6. **m_map 路径** — m_map 装在哪？

### 第二步：验证文件

```python
import h5py as h5; import numpy as np
f = h5.File('xxx.nc', 'r')
lat = f['latitude'][()]; lon = f['longitude'][()]
depth = f['depth'][()]; time = f['time'][()]
thetao = f['thetao']
print(f'lat: {lat.min():.2f}~{lat.max():.2f}')
print(f'lon: {lon.min():.2f}~{lon.max():.2f}')
print(f'thetao shape: {thetao.shape}')
print(f'SST: {np.nanmin(thetao[0,0]):.2f}~{np.nanmax(thetao[0,0]):.2f}C')
print(f'NaN(land): {np.isnan(thetao[0,0]).mean()*100:.1f}%')
f.close()
```

### 第三步：提取数据

用 `extract_data.m` 模板（或 Python 预处理）：

- 先读坐标 → 用 `min(abs(lat - target))` 找目标区域索引
- 用 `ncread` 或 h5py 只读目标区域（start/count 参数）
- **注意维度顺序**：ncdisp 显示的维度顺序是 ncread 的 start/count 顺序
- 保存为 .mat，含 `lon`, `lat`, `sst`（或 `sst_all` 多天数据）, `time`

### 第四步：画图

调用 `plot_sst_map` 函数：

```matlab
plot_sst_map(lon, lat, sst, 'East China Sea SST', [0 25]);
```

函数签名：

```matlab
plot_sst_map(经度, 纬度, 海温数据, 标题文字, 色标范围, 图窗名(可选))
```

### 第五步：批量出图 + GIF

- `animate_daily_raw.m` — 原始分辨率，循环出图+合成GIF
- `animate_daily_interp.m` — 插值后出图+合成GIF

关键参数：

| 参数 | 所在位置 |
|------|---------|
| 色标范围 | 循环前算全局 min/max，固定 `caxis_range` |
| 每帧时长 | `'DelayTime', 0.6`（秒） |
| 输出目录 | `OUT_DIR` |
| 插值方法 | `interp2(..., 'spline')`，先填 NaN 再插 |

## 顶刊图表标准

| 项目 | 标准 |
|------|------|
| 标题 | 英文 |
| 配色 | parula（SST）/ RdBu（异常场），禁用 jet |
| 色标标签 | `SST (°C)` |
| 色标范围 | 同系列图必须固定 |
| 陆地颜色 | `[0.7 0.7 0.7]` 灰色 |
| 海岸线 | `[0.3 0.3 0.3]` 深灰，线宽 0.4 |
| 网格线 | 浅灰虚线 `':'`，线宽 0.3，不压图 |
| 字体 | 标题 8pt，标签 7pt（单栏 89mm） |

## 常见踩坑

- **ncread 返回值全是 NaN**：换 Python h5py 导出 .mat
- **m_pcolor 报矩阵维度不匹配**：确认 sst 维度是 (lat, lon)，传给 m_pcolor 时三个参数分别是 (lon, lat, sst)
- **scatteredInterpolant 报精度错误**：用 `double()` 转双精度
- **sprintf 里 \circ 报错**：用 `\\circ` 或 `{\circ}`，sprintf 内用 `\\` 转义
- **插值报"有限值不足"**：用 `scatteredInterpolant` 或先 `fillmissing` 填 NaN
- **GSHHS 海岸线数据缺失**：下载 `gshhg-bin-*.zip` 解压到 m_map/data/

## Bundled Resources

- `scripts/plot_sst.m` — MATLAB 绘图模板（需结合 skill 中的函数式架构调整）
- `references/map_style.md` — m_map 样式参考


## 新增功能：垂向插值 + 时间插值 + 异常场动图

基于实际项目（CMEMS GLORYS 东海区域，每日数据到 6h 分辨率）的关键经验。

### 关键教训（新增）

| 教训 | 说明 |
|------|------|
| **垂向插值循环每个点** | interp1(depth, prof, z_target, 'linear') |
| **时间插值先造 datenum 轴** | time_6h = time_dn(1):(6/24):time_dn(end)，再循环每个点 interp1 |
| **异常 = 原始 - 时间均值** | 用发散色标 RdBu 突出变化 |
| **发散色标必须对称** | 确保 0 值在中间（白色） |
| **GIF：逐帧 PNG 合成** | rgb2ind + imwrite append |
| **外扩 2 度防白边** | 读时外扩，画图时裁回 |
| **brewermap 优先回退 jet** | try...catch 包裹 |

### 项目结构（追加）

```
project/
  plot_sst_map.m               # 画图函数（支持 RdBu 发散色标）
  interp_depth_time_anim.m     # 垂向+时间插值到异常场到GIF
  run_50m.bat                  # 一键运行
  output/
    interp_50m_6h.mat          # 插值结果
    frames_50m_6h/             # 每帧 PNG
    sst_50m_6h.gif             # 最终动图
```

### 新增工作流程

**第 6 步：垂向插值到目标深度**

NC 维度顺序 (lon, lat, depth, time)，squeeze 取垂直剖面，跳过陆地点。

```matlab
z_target = 50;
z_query = min(max(z_target, min(depth_all)), max(depth_all));
sst_depth = NaN(nlon, nlat, ntime);
for i = 1:nlon
  for j = 1:nlat
    for t = 1:ntime
      prof = squeeze(thetao(i, j, :, t));
      valid = ~isnan(prof);
      if sum(valid) < 2, continue; end
      sst_depth(i,j,t) = interp1(depth_all(valid), prof(valid), z_query, 'linear');
    end
  end
end
```

**第 7 步：时间插值（每日到 6h）**

先生成目标轴 time_6h = time_dn(1):(6/24):time_dn(end)，每次插一个 (lon,lat) 点。

```matlab
HOUR_STEP = 6;
time_6h = time_dn(1):(HOUR_STEP/24):time_dn(end);
sst_6h = NaN(nlon, nlat, nt_6h);
for i = 1:nlon
  for j = 1:nlat
    ts = squeeze(sst_depth(i, j, :));
    valid = ~isnan(ts);
    if sum(valid) < 2, continue; end
    sst_6h(i,j,:) = interp1(time_dn(valid), double(ts(valid)), time_6h, 'linear');
  end
end
```

**第 8 步：异常场 + GIF 动图**

```matlab
% USE_ANOMALY = true: 使用异常场
if USE_ANOMALY
  sst_mean = mean(sst_6h, 3, 'omitnan');
  plot_data = sst_6h - sst_mean;
  caxis_val = [-ceil(max(abs(plot_data(:)))*2)/2, ceil(max(abs(plot_data(:)))*2)/2];
else
  % 默认：使用绝对温度
  plot_data = sst_6h;
  caxis_val = [floor(min(sst_6h(:))), ceil(max(sst_6h(:)))];
end
for t = 1:nt_6h
  plot_sst_map(lon, lat, plot_data(:,:,t), title_text, caxis_val);
  print(gcf, '-dpng', '-r300', fullfile(dir, fname));
  close(gcf);
end
for t = 1:nt_6h
  [idx, cmap] = rgb2ind(imread(...), 256);
  if t == 1
    imwrite(idx, cmap, gif_path, 'gif', 'Loopcount', inf, 'DelayTime', 0.4);
  else
    imwrite(idx, cmap, gif_path, 'gif', 'WriteMode', 'append', 'DelayTime', 0.4);
  end
end
```

### 新增常见踩坑

| 问题 | 解决 |
|------|------|
| rb 读 + w 写导致 CR 翻倍 | Windows 文本模式把换行转 CRLF，读二进制后写文本会叠加 CR |
| re.subn 的 s* 会匹配回车 | 文本替换时 s 含回车，对括号需转义 |
| brewermap 未安装 | FileExchange #120022 下载 |
| m_pcolor 维度需 (lat, lon) | permute 转置 |
| USE_ANOMALY 开关未设置 | omitnan 参数 |
| GIF 帧文件积累 | 每帧约 500KB |


### ### 流速矢量场 (m_quiver) - 已实现

完整流程：读取 uo/vo → 垂向插值到目标深度 → 时间插值到 6h → m_pcolor+m_quiver 动图 GIF。

#### 数据来源

- CMEMS 产品：GLOBAL_MULTIYEAR_PHY_ENS_001_031
- 变量名：uo_glor (东向流速), o_glor (北向流速)
- 维度顺序（netCDF4）：(time, depth, lat, lon)
- 注意：MATLAB ncread 返回顺序为 (lon, lat, depth, time)，取表层第 t 时次用 uo_all(:,:,1,t)' 转置为 (lat,lon)

#### 垂向插值 (向量化)

`matlab
zq = min(max(Z_TARGET, min(depth)), max(depth));
Yu = reshape(permute(uo_all, [3,1,2,4]), nd, []);
uo_z = reshape(interp1(depth, Yu, zq, 'linear'), [nlon, nlat, nt_orig]);
`

#### 时间插值 (向量化)

`matlab
time_6h = time_dn(1):(HOUR_STEP/24):time_dn(end);
Yu = interp1(time_dn, reshape(permute(uo_z, [3,1,2]), nt_orig, []), time_6h, 'linear');
uo_6h = permute(reshape(Yu, [nt_6h, nlon, nlat]), [2,3,1]);
`

#### 矢量绘图 + GIF

`matlab
% 每帧：颜色=流速大小, 箭头=方向
uo = uo_6h(:,:,t)';  % (lon,lat) -> (lat,lon)
spd = sqrt(uo.^2 + vo.^2);
m_pcolor(lon, lat, spd); shading interp;
colormap(parula(256)); caxis([0 smx]); hold on;
m_quiver(lon_q, lat_q, u_q, v_q, 'color', [0.2 0.2 0.2], 'AutoScaleFactor', 0.6, 'linewidth', 0.3);
% 参考矢量 (顶刊硬性要求)
m_quiver(rx, ry, VREF, 0, 'color', [0.2 0.2 0.2], 'AutoScaleFactor', 0.6, 'linewidth', 0.5);
text(rx+0.3, ry, sprintf('%.1f m/s', VREF), 'FontSize', 7, 'FontWeight', 'bold');
% GIF: rgb2ind + imwrite append
`

#### 矢量场绘图要点

| 要点 | 说明 |
|--------|------|
| 抽稀 | 矢量箭头每隔 4-5 个网格点画一个，防止过密 |
| meshgrid | m_quiver 要求 lon/lat/u/v 四者同尺寸，用 meshgrid 生成 2D 网格 |
| 参考矢量 | 必须有，图下角标注速度值 |
| 色标 | 流速从 0 开始，上限取整到 0.1 的倍数 |
| 配色 | parula (顶刊推荐)，箭头用深灰色 |

完整模板脚本：scripts/vel_interp_anim.m
### New Scripts

- interp_depth_time_anim.m - 完整工作流程 (支持 USE_ANOMALY 切换绝对温度/异常场)
- plot_sst_map.m - 可复用画图函数 (支持 parula/RdBu 配色)
- el_interp_anim.m - 流速矢量场动图模板 (垂直插值+时间插值+m_quiver+GIF)



---

## Roadmap / 开发计划

当前 skill 已实现：NC 读取 → 区域裁剪 → 垂向插值 → 时间插值 → 异常场计算 → 顶刊级出图 → GIF 动图的完整管线。
以下是下一步应该补充的能力，按优先级排列。

### P0: 基础功能补齐（优先做）

| 功能 | 说明 | 涉及文件 |
|------|------|---------|
| **多变量支持** | 推广到盐度 so、海流 uo/vo、海面高度 zos | extract_data.m, interp_depth_time_anim.m |
| **多数据源适配** | 支持 HYCOM / SODA / AVISO / ERA5，不同维度顺序和变量名 | extract_data.m, 新建 adaptor |
| **垂直剖面图** | 沿纬度/经度固定剖面的 depth-lon / depth-lat 图 | 新建 plot_vertical_section.m |
| **单点时间序列** | 提取某个 (lon,lat) 的温度时间序列 + 折线图 | 新建 extract_timeseries.m |
| **空间区域平均** | 对指定子区域做空间平均，画时间序列 | extract_timeseries.m 内实现 |

### P1: 分析能力（有了基础后）

| 功能 | 说明 | 涉及文件 |
|------|------|---------|
| **气候态月平均** | 多年逐月聚合，输出 12 张月气候态图 | 新建 monthly_climatology.m |
| **季节平均** | DJF/MAM/JJA/SON 四季聚合 | monthly_climatology.m 内实现 |
| **等值线叠加** | 在填色图上叠等温线/等高线 (m_contour) | plot_sst_map.m |
| **多面板组合图** | tiledlayout 多面板排版，用于论文 figure | 新建 composite_figure.m |
| **混合层深度** | 温度阈值法计算 MLD，画空间分布 | 新建 calc_mld.m |
| **热含量** | 垂向积分 OHC = rho Cp T dz | 新建 calc_ohc.m |

### P2: 高级分析（可选）

| 功能 | 说明 |
|------|------|
| EOF 分析 | svd/eig 分解时空场，提取主导模态 |
| Hovmoller 图 | time-lon / time-lat 剖面展示信号传播 |
| ~~矢量场图~~ | ~~m_quiver 画海流~~ ✅ 已实现 (见 scripts/vel_interp_anim.m) |
| 锋面检测 | 基于梯度阈值的温度锋面提取 |
| 色盲友好检查 | 确认所有配色通过 CVD 模拟 |

### P3: 工程化改进（长期)

| 功能 | 说明 |
|------|------|
| 配置文件驱动 | YAML/JSON 配置文件，避免每次改 .m 代码 |
| 日志系统 | 记录每步耗时、文件大小、状态 |
| 并行加速 | 垂向插值三重循环改 parfor |
| 命令行接口 | matlab -batch run(config.yaml) |
| 交互式探索 | MATLAB App Designer 或 GUI 浏览数据 |

---

### 如何贡献 / How to Contribute

- 每个新功能建一个独立脚本，放在 scripts/ 目录
- 遵循现有的项目结构：画图逻辑在 plot_sst_map.m，数据分析在独立脚本
- 顶刊标准见上方的出版标准表
