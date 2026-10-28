# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["h5py==3.15.1"]
# ///
"""Inspect a local DWD RV archive. Research tool, not an application parser."""
import argparse
import hashlib
import io
import json
import resource
import tarfile
import time
from datetime import datetime, timezone
from pathlib import Path

import h5py


def decode(value):
    return value.decode('utf-8') if isinstance(value, bytes) else value


def instant(attrs, prefix=''):
    value = decode(attrs[prefix + 'date']) + decode(attrs[prefix + 'time'])
    return datetime.strptime(value, '%Y%m%d%H%M%S').replace(tzinfo=timezone.utc)


def inspect(path):
    started = time.monotonic()
    archive = path.read_bytes()
    frames = []
    total_bytes = 0
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        members = [member for member in tar.getmembers() if member.isfile()]
        if not members or len(members) > 100:
            raise ValueError('Unexpected number of archive files')
        for member in members:
            if member.size > 32 * 1024 * 1024:
                raise ValueError('Unexpectedly large HDF5 member')
            total_bytes += member.size
            with h5py.File(io.BytesIO(tar.extractfile(member).read())) as file:
                what = file['what'].attrs
                period = file['dataset1/what'].attrs
                scale = file['dataset1/data1/what'].attrs
                if decode(scale['quantity']) != 'ACRR':
                    raise ValueError('Expected ACRR accumulation, no other quantity supported')
                data = file['dataset1/data1/data']
                where = file['where'].attrs
                start, end = instant(period, 'start'), instant(period, 'end')
                duration = (end - start).total_seconds()
                if duration <= 0:
                    raise ValueError('Invalid accumulation interval')
                samples = []
                for row, column in ((0, 0), (600, 550), (1199, 1099), (297, 320)):
                    raw = int(data[row, column])
                    # ODIM special values must be handled before gain/offset.
                    if raw == scale['nodata']:
                        state, amount = 'missing', None
                    elif raw == scale['undetect']:
                        state, amount = 'undetect', 0.0
                    else:
                        state = 'value'
                        amount = float(raw * scale['gain'] + scale['offset'])
                    samples.append({'row': row, 'column': column, 'raw': raw,
                                    'state': state, 'amount_mm': amount,
                                    'period_average_mm_per_hour': None if amount is None else amount * 3600 / duration})
                frames.append({'file': member.name, 'reference_time': instant(what).isoformat(),
                               'period_start': start.isoformat(), 'period_end': end.isoformat(),
                               'lead_minutes': int(member.name.rsplit('_', 1)[1].split('-')[0]),
                               'quantity': decode(scale['quantity']), 'shape': list(data.shape),
                               'dtype': str(data.dtype), 'gain': float(scale['gain']),
                               'offset': float(scale['offset']), 'nodata': int(scale['nodata']),
                               'undetect': int(scale['undetect']),
                               'projection': decode(where['projdef']),
                               'xscale': float(where['xscale']), 'yscale': float(where['yscale']),
                               'samples': samples})
    return {'archive_sha256': hashlib.sha256(archive).hexdigest(),
            'archive_bytes': len(archive), 'hdf5_member_bytes': total_bytes,
            'elapsed_seconds': round(time.monotonic() - started, 3),
            'process_peak_rss_bytes_macos': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            'note': 'Pixel indices only; no geographic cell assignment verified. Timing is on development Mac, not iPhone.',
            'frames': sorted(frames, key=lambda frame: frame['lead_minutes'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = inspect(args.archive)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'frames'}, indent=2))
    print('Frames:', len(result['frames']))


if __name__ == '__main__':
    main()
