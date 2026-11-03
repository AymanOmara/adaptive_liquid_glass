"""Measure colour-highlight latency from actual UIKit delivery timestamps.

Pass a take folder containing PNG frames and times.json from the component
motion harness. The crop must contain a borderless Button label on white.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
from PIL import Image


def measure(directory):
    metadata = json.loads((directory / 'times.json').read_text())
    times = metadata['frameTimes']
    touches = [t for t in metadata['touches'] if times[0] <= t['received'] <= times[-1]]
    if len(touches) != 1:
        raise ValueError(f'{directory}: expected one recorded touch, got {len(touches)}')
    files = sorted(directory.glob('*.png'))
    if len(files) != len(times):
        raise ValueError('Frame timestamps do not match the images')
    labels = []
    for file in files:
        with Image.open(file) as source:
            crop = source.convert('RGB').crop((45, 39, 195, 111))
        common = Counter(crop.getdata()).most_common(2)
        if len(common) != 2 or common[1][1] < 500:
            raise ValueError(f'{file}: button label missing')
        labels.append(common[1][0])
    baseline = labels[0]
    changed = [max(abs(c - b) for c, b in zip(label, baseline)) >= 20 for label in labels]
    index = next((i for i in range(len(changed) - 1) if changed[i] and changed[i + 1]), None)
    if index is None:
        raise ValueError(f'{directory}: no stable highlight observed')
    delay = times[index] - touches[0]['received']
    if delay < -1 / 60:
        raise ValueError('Highlight precedes touch; reject the take')
    return {'take': directory.name, 'received': touches[0]['received'],
            'frame': index, 'highlightTime': times[index], 'delayMs': delay * 1000}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('takes', nargs='+', type=Path)
    args = parser.parse_args()
    print(json.dumps([measure(path) for path in args.takes], indent=2))
