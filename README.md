# SST Mapper / 海温制图技能

A Codex skill for processing NetCDF sea surface temperature (SST) data and creating publication-quality maps using MATLAB + m_map toolbox.
一个 Codex 技能，用于处理 NetCDF 海温数据，并用 MATLAB + m_map 绘制顶刊级别的海温图。

---

## Key Lessons / 关键教训

| Lesson / 教训 | Detail / 说明 |
|------|------|
| **Always use m_map / 默认用 m_map** | Not imagesc. m_proj/m_pcolor/m_gshhs/m_grid by default |
| **ncread can fail / ncread 可能出错** | Some NetCDF4 files return NaN → use Python h5py → export .mat |
| **Fixed caxis / 固定色标** | Multi-day comparison requires global min/max |
| **Ask first / 先问再做** | When unsure about tools, ask the user |
| **Extract drawing logic / 抽取画图逻辑** | Repeated code → one function, all scripts call it |
| **Detailed comments / 注释写细** | User may be beginner; explain every parameter |

## Files / 文件说明

| File / 文件 | Purpose / 作用 |
|-------------|----------------|
| `SKILL.md` | Full workflow / 完整工作流程 |
| `README.md` | This file / 本说明文件 |
| `scripts/preprocess.py` | Python: extract SST from NC, save as .mat |
| `scripts/plot_sst.m` | MATLAB: m_map plotting template |
| `references/map_style.md` | m_map style reference |

## Recommended Project Structure / 推荐的项目结构

For actual data work, structure your project like this:
实际数据处理时，建议这样组织项目：

```
project/
├── README.md                  # Project documentation / 项目说明
├── plot_sst_map.m             # [Function] Plot SST map / 画图函数（核心）
├── extract_data.m             # [Extract] Subset from NC / 从NC切区域
├── interp_plot.m              # [Single] Interpolate + view / 单天插值+看图
├── animate_daily_raw.m        # [Batch] Raw resolution → PNG + GIF
├── animate_daily_interp.m     # [Batch] Interpolated → PNG + GIF
└── regional_sst_all.mat       # Generated data / 生成的数据
```

## Publication Standards / 顶刊出图标准

| Item / 项目 | Standard / 标准 |
|-------------|-----------------|
| Title / 标题 | English |
| Colormap / 配色 | parula (SST) / RdBu (anomaly); never jet |
| Colorbar label / 色标标签 | SST (°C) |
| Colorbar range / 色标范围 | Fixed across all frames |
| Land color / 陆地颜色 | [0.7 0.7 0.7] gray |
| Coastline / 海岸线 | [0.3 0.3 0.3], linewidth 0.3 |
| Grid / 网格 | Light gray dotted / 浅灰虚线 |
| Font / 字体 | Title 8pt, labels 7pt (single-col 89mm) |

## Common Pitfalls / 常见踩坑

| Pitfall / 问题 | Solution / 解决 |
|----------------|-----------------|
| ncread returns all NaN | Use Python h5py to export .mat |
| m_pcolor dimension mismatch | sst must be (lat, lon) |
| scatteredInterpolant precision | Use double() conversion |
| sprintf \circ escape | Use \\\\circ inside sprintf |
| GSHHS data missing | Extract gshhg-bin-*.zip to m_map/data/ |
| Interpolation fails with NaN | Use fillmissing first, or scatteredInterpolant |


## New Capabilities (追加功能)

Based on the "vertical interpolation + temporal interpolation + anomaly animation" workflow (test3 project).

### New Scripts

| File / 文件 | Purpose / 作用 |
|-------------|----------------|
| scripts/interp_depth_time_anim.m | Full workflow: vertical interp to time interp to anomaly to GIF |
| scripts/plot_sst_map.m | Reusable plotting function with RdBu diverging colormap support |

### New Workflow Capabilities

| Capability / 功能 | Description / 说明 |
|-------------------|-------------------|
| Vertical interpolation | Loop each (lon,lat,time) point, interp1 to target depth |
| Temporal interpolation | Generate high-res datenum axis, loop each (lon,lat), interp1 |
| Anomaly computation | Subtract time-mean, use diverging colormap (RdBu) |
| Animated GIF | Per-frame PNG to rgb2ind to imwrite append, looped playback |
| Batch runners | .bat files for one-click execution at different depths |
| Brewermap fallback | try/catch brewermap, fallback to jet if unavailable |

### File Naming Convention

```
output/
  interp_50m_6h.mat              # Interpolated data
  frames_50m_6h/                 # Per-frame PNGs
    frame_50m_t001.png
    ...
  sst_50m_6h.gif                 # Final animation
```


## Roadmap / 开发计划

See SKILL.md for full roadmap.
Priority order: P0 (basic) > P1 (analysis) > P2 (advanced) > P3 (engineering)


## Capability Status / 能力状态

| 层次 | 能力 | 当前状态 |
|------|------|---------|
| 基础 | 单变量读/裁/画/动图 | ✅ 已有 |
| 基础 | 多数据源适配 | ❌ 需加 |
| 基础 | 垂向/时间插值 | ✅ 已有 |
| 基础 | 垂直剖面图 | ❌ 需加 |
| 进阶 | 时间序列 + 空间平均 | ❌ 需加 |
| 进阶 | 气候态/季节平均 | ❌ 需加 |
| 进阶 | EOF / 混合层深度 | ❌ 需加 |
| 出图 | 多面板组合 / 等值线 / 矢量 | ❌ 需加 |
| 工程 | 配置文件 / 日志 / 并行 | ❌ 需加 |

