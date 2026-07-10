---
name: sst-mapper
description: Generate publication-quality sea surface temperature (SST) maps from NetCDF data using Python preprocessing and MATLAB + m_map mapping. Use when handling CMEMS GLOBAL_ANALYSISFORECAST_PHY_001_024 or similar ocean model data (.nc files with thetao variable). Triggers on requests involving netcdf, sst, sea surface temperature, cmems, copernicus, ocean data, m_map mapping.
---

# SST Mapper

Process NetCDF sea surface temperature data and create publication-quality maps using MATLAB + m_map.

## Workflow Overview

`
User request --> [ask: file path, region, time, depth] --> preprocess.py (Python) --> sst_data.mat --> plot_sst.m (MATLAB + m_map) --> figure
`

## Before Starting: Confirm These 5 Items

Always ask the user for these before writing any code:

1. **File path**: where is the .nc file?
2. **Region**: lat/lon bounds (e.g., "25~41N, 117~135E")
3. **Time**: which time step or date range?
4. **Depth**: surface (index 0) or specific depth layer?
5. **Purpose**: journal / report / quick preview?
6. **m_map path**: where is m_map installed? (e.g., E:\matlab_2025b\toolbox\m_map)

## Step 1: Verify File & Data

Run a quick Python check before any processing:

`
python -c "
import h5py as h5; import numpy as np
f = h5.File('path/to/file.nc', 'r')
lat = f['latitude'][()]; lon = f['longitude'][()]
depth = f['depth'][()]; time = f['time'][()]
thetao = f['thetao']
print(f'lat: {lat.min():.2f} ~ {lat.max():.2f}  ({len(lat)} pts)')
print(f'lon: {lon.min():.2f} ~ {lon.max():.2f}  ({len(lon)} pts)')
print(f'depth: {depth.min():.2f} ~ {depth.max():.2f} m  ({len(depth)} layers)')
print(f'time: {len(time)} steps')
print(f'thetao shape: {thetao.shape}')
data = thetao[0, 0, :, :]
print(f'SST range: {np.nanmin(data):.2f} ~ {np.nanmax(data):.2f} C')
print(f'NaN ratio (land): {np.isnan(data).mean()*100:.1f}%')
f.close()
"
`

## Step 2: Preprocess with Python

Use scripts/preprocess.py:

`
cd /path/to/project
python preprocess.py
`

The script will prompt for: input NC file, time index, depth index, output .mat path.
Or call directly with arguments:

`
python preprocess.py --input data.nc --t 0 --z 0 --output sst_data.mat
`

## Step 3: Plot with MATLAB + m_map

Use scripts/plot_sst.m template.

Key settings to adjust per task:

| Parameter | Where to set | Typical value |
|-----------|-------------|---------------|
| Lon range | m_proj('mercator', 'lon', [x1 x2], ...) | e.g. [117 135] |
| Lat range | m_proj(..., 'lat', [y1 y2]) | e.g. [25 41] |
| SST color range | caxis([min max]) | e.g. [18 32] |
| Colormap | colormap(jet) or colormap(parula) | jet for journals, parula for reports |
| Title | 	itle(...) | Use English for journals |
| Land color | m_gshhs('i', 'patch', [0.7 0.7 0.7], ...) | Gray, do not modify |
| Grid style | m_grid(...) | Dotted gray lines |

### Common Gotchas

- **ncread returns NaN in some MATLAB versions**: Always use Python (h5py) to extract data and save as .mat
- **m_map GSHHS data missing**: Verify gshhs_*.b files exist in m_map/data/
- **m_pcolor data orientation**: SST array should be (lat, lon) when passed to m_pcolor; m_pcolor(lon, lat, sst) works correctly when sst is (lat, lon)
- **NaN handling**: Do NOT replace NaN with sentinel values when using m_map. m_gshhs patch fills land automatically
- **Land fills over ocean data**: Always call m_pcolor BEFORE m_gshhs so land gray patches overlay the SST data

## Step 4: Output Check

| Check | Standard |
|-------|----------|
| Colorbar range matches data min/max | Yes |
| Land color uniform gray | [0.7 0.7 0.7] |
| Coastline visible, not overpowering | EdgeColor [0.3 0.3 0.3], width 0.4 |
| Grid lines subtle | Dotted, gray, 0.3 width |
| Title in English for journals | yes |
| Colorbar label with degree symbol | SST ({\circ}C) |
| Font sizes readable | Title 16, grid 13, colorbar 14 |

## Bundled Resources

- scripts/preprocess.py: Python script to extract SST from NC and save as .mat
- scripts/plot_sst.m: MATLAB + m_map plotting template
- eferences/map_style.md: Detailed m_map style options reference

