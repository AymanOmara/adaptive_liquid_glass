"""Extract held colours and a plain-label release from system-button dumps.

Usage: python measure_system_button_press.py build/motion/system-buttons-v2
Capture commands and scene coordinates are documented in README.md.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
from PIL import Image


def colors(path):
    with Image.open(path) as source:
        if source.size != (240, 150):
            raise ValueError(f'{path}: expected a 240x150 button crop')
        image = source.convert('RGB').crop((45, 39, 195, 111))
    return tuple(color for color, _ in Counter(image.getdata()).most_common(2))


def measure(directory):
    samples = []
    names = ['neutral', 'tinted', 'destructive', 'prominent',
             'destructive-prominent', 'borderless', 'plain', 'destructive-borderless']
    release = None
    for mode in ['light', 'dark']:
        for name in names:
            path = directory / f'{name}-{mode}.ref'
            frames = [colors(f) for f in sorted(path.glob('*.png'))]
            if not frames:
                raise ValueError(f'{path}: missing frames')
            idle = frames[0]
            held, count = Counter(f for f in frames if f != idle).most_common(1)[0]
            if count < 20 or frames[-1] != idle:
                raise ValueError(f'{path}: held plateau or completed release missing')
            samples.append({'style': name, 'mode': mode, 'idle': idle, 'held': held})
            if name == 'plain' and mode == 'light':
                start = max(i for i, f in enumerate(frames) if f == held)
                end = next(i for i in range(start, len(frames)) if frames[i] == idle)
                release = [f[1][0] for f in frames[start:end + 1]]
    return {'ios': '26.4', 'device': 'iPhone 17 Pro', 'fps': 60,
            'samples': samples, 'plain_light_release': release}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    print(json.dumps(measure(args.directory), indent=2))
