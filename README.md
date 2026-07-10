# SST Mapper

A Codex skill for processing NetCDF sea surface temperature (SST) data and creating publication-quality maps using MATLAB + m_map toolbox.

## What It Does

1. **Preprocess**: Extract SST from NetCDF (`.nc`) files using Python + h5py → save as `.mat`
2. **Plot**: Load `.mat` in MATLAB + m_map → produce professional SST maps with:
   - Mercator projection
   - Gray land fill with coastline outlines
   - Customizable color scale and grid
   - Publication-grade formatting

## Workflow

```
NetCDF (.nc)  →  preprocess.py (Python)  →  sst_data.mat  →  plot_sst.m (MATLAB)  →  Figure
```

## Files

| File | Description |
|------|-------------|
| `SKILL.md` | Main skill instructions and workflow |
| `scripts/preprocess.py` | Python: extract SST from NC, save as .mat |
| `scripts/plot_sst.m` | MATLAB: load .mat, draw map with m_map |
| `references/map_style.md` | m_map style reference |
| `agents/openai.yaml` | Skill UI metadata |

## Requirements

### Python
- h5py, numpy, scipy

### MATLAB
- [m_map](https://www.eoas.ubc.ca/~rich/map.html) toolbox
- GSHHS coastline data (`gshhs_*.b` files in m_map/data/)

## Usage

```bash
# Step 1: Preprocess
python scripts/preprocess.py -i data.nc -t 0 -z 0 -o sst_data.mat

# Step 2: Edit plot_sst.m → adjust region/range/title → run in MATLAB
```

## Key Lessons Learned

- **ncread in MATLAB often returns NaN** for NetCDF4 files → always use Python (h5py) for extraction
- **m_pcolor must be called BEFORE m_gshhs** so land gray fills on top of ocean data
- **Land color**: `[0.7 0.7 0.7]`, coastline: `[0.3 0.3 0.3]` — balanced for publication
- **Grid**: dotted gray lines, not solid black
