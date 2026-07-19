# SST Mapper

A Codex skill for processing NetCDF sea surface temperature (SST) data and creating publication-quality maps using MATLAB + m_map toolbox.

## Key Lessons (updated)

| Lesson | Detail |
|--------|--------|
| **Always use m_map** | Not imagesc. m_proj/m_pcolor/m_gshhs/m_grid by default |
| **ncread can fail** | Some NetCDF4 files return NaN → use Python h5py → export .mat |
| **Fixed caxis** | Multi-day comparison requires global min/max, not per-day auto-scale |
| **Ask first** | When unsure about tools, ask the user |
| **Extract drawing logic** | Repeated plot code → one function, all scripts call it |

## Project Structure

```
sst-mapper/
├── SKILL.md                  # Core skill instructions
├── README.md                 # This file
├── agents/
│   └── openai.yaml           # UI metadata
├── scripts/
│   ├── preprocess.py          # Python: extract SST from NC → .mat
│   └── plot_sst.m            # MATLAB: m_map plotting template
└── references/
    └── map_style.md           # m_map style reference
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Full workflow documentation + common pitfalls |
| `scripts/preprocess.py` | Python: extract SST from NC, save as .mat |
| `scripts/plot_sst.m` | MATLAB: load .mat, draw map with m_map |
| `references/map_style.md` | m_map style options |

## Recommended User Project Structure

For actual data work, structure your project like this:

```
project/
├── README.md                  # Project documentation
├── plot_sst_map.m             # [Function] Plot SST map (all scripts call this)
├── extract_data.m             # [Extract] Subset from NC → .mat
├── interp_plot.m              # [Single] Interpolate + view
├── animate_daily_raw.m        # [Batch] All days raw 0.25° → PNG + GIF
├── animate_daily_interp.m     # [Batch] All days interp 0.1° → PNG + GIF
└── regional_sst_all.mat       # Generated data from extract_data.m
```

## Publication Standards

| Item | Standard |
|------|----------|
| Title | English |
| Colormap | parula (not jet) |
| Colorbar label | SST (°C) |
| Colorbar range | Fixed across all frames |
| Land color | [0.7 0.7 0.7] gray |
| Coastline | [0.3 0.3 0.3], linewidth 0.4 |
| Grid | Light gray dotted |
| Font | Title 15, grid 11, colorbar 12 |

## Common Pitfalls

- **ncread returns all NaN**: Use Python h5py instead
- **m_pcolor dimension mismatch**: sst must be (lat, lon)
- **scatteredInterpolant precision error**: Use double() conversion
- **sprintf \circ escape**: Use \\circ inside sprintf
- **GSHHS data missing**: Extract gshhg-bin-*.zip to m_map/data/
