#!/usr/bin/env python3
"""CMEMS SST Preprocessor: Extract SST from NetCDF, save as .mat for MATLAB."""
import h5py as h5, numpy as np
from scipy.io import savemat
import argparse, os

def main():
    p = argparse.ArgumentParser()
    p.add_argument('-i', '--input', help='Input .nc file')
    p.add_argument('--t', type=int, help='Time index (0-based)')
    p.add_argument('--z', type=int, help='Depth index (0-based)')
    p.add_argument('-o', '--output', default='sst_data.mat')
    args = p.parse_args()

    nc = args.input or input('NC file: ').strip()
    f = h5.File(nc, 'r')
    lat, lon = f['latitude'][()], f['longitude'][()]
    depth, time_raw = f['depth'][()], f['time'][()]
    thetao = f['thetao']

    print(f'Lat: {lat.min():.2f}~{lat.max():.2f}, Lon: {lon.min():.2f}~{lon.max():.2f}')
    print(f'Depth: {depth.min():.1f}~{depth.max():.1f}m, Time: {len(time_raw)} steps')
    print(f'thetao: {thetao.shape}')

    t_idx = args.t if args.t is not None else int(input(f'Time index (0-{len(time_raw)-1}): '))
    z_idx = args.z if args.z is not None else int(input(f'Depth index (0-{len(depth)-1}): '))
    sst = thetao[t_idx, z_idx, :, :]

    print(f'SST: {np.nanmin(sst):.2f}~{np.nanmax(sst):.2f}C, NaN(land): {np.isnan(sst).mean()*100:.1f}%')
    savemat(args.output, {'lon': lon, 'lat': lat, 'sst': sst, 'time_raw': time_raw})
    print(f'Saved: {args.output} ({os.path.getsize(args.output)/1e6:.1f} MB)')
    f.close()

if __name__ == "__main__":
    main()
