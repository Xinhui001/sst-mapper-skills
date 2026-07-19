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
| 配色 | `parula`（非 jet） |
| 色标标签 | `SST (°C)` |
| 色标范围 | 同系列图必须固定 |
| 陆地颜色 | `[0.7 0.7 0.7]` 灰色 |
| 海岸线 | `[0.3 0.3 0.3]` 深灰，线宽 0.4 |
| 网格线 | 浅灰虚线 `':'`，线宽 0.3，不压图 |
| 字体 | 标题 15，网格 11，色标 12 |

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
