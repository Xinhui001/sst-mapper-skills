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
