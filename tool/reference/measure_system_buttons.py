"""Extract non-glass SwiftUI button colours from four reference screenshots.

Input names: systembuttons-{light,dark}[-gray].png, captured on iPhone 17 Pro
at 3x using -controls systembuttons/systembuttonsdark [-buttonBackground gray].
"""
import argparse
from collections import Counter
import json
from pathlib import Path
from PIL import Image


def measure(directory):
    result = {'device': 'iPhone 17 Pro', 'ios': '26.4', 'date': '2026-10-30',
              'rows': ['bordered', 'tinted', 'destructive', 'prominent', 'destructiveProminent'],
              'samples': []}
    for mode in ['light', 'dark']:
        for gray in [False, True]:
            name = f'systembuttons-{mode}' + ('-gray' if gray else '') + '.png'
            with Image.open(directory / name) as source:
                if source.size != (1206, 2622):
                    raise ValueError(f'{name}: expected iPhone 17 Pro at 3x')
                image = source.convert('RGB')
            rows = []
            for y in range(100, 501, 100):
                columns = []
                for x in [100, 300]:
                    crop = image.crop(((x-25)*3, (y-12)*3, (x+25)*3, (y+12)*3))
                    # Solid fill and fully covered label ink dominate the crop.
                    colors = Counter(crop.getdata()).most_common(2)
                    if len(colors) != 2 or colors[1][1] < 1000:
                        raise ValueError(f'{name}: incomplete button at {x}, {y}')
                    columns.append({'fill': colors[0][0], 'label': colors[1][0]})
                rows.append(columns)
            result['samples'].append({'mode': mode, 'background': image.getpixel((10, 10)), 'rows': rows})
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    print(json.dumps(measure(args.directory), indent=2))
