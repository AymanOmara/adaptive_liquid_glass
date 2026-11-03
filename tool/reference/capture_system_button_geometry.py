"""Collect native SwiftUI layout measurements from the installed example.

Build/install the example first, then pass a booted iPhone 17 Pro/iOS 26.4
simulator UUID. GeometryReader backgrounds observe intrinsic layout without
adding layout constraints. Results are suitable for the reference fixture.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import time

BUNDLE = 'com.aymanomara.adaptiveLiquidGlassExample'
SIZES = ['mini', 'small', 'regular', 'large', 'extraLarge']
SCENES = {'bordered': 'systembuttongeometry', 'borderedProminent': 'systemprominentgeometry',
          'borderless': 'systemborderlessgeometry', 'plain': 'systemplaingeometry'}


def simctl(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True).strip()


def capture(udid):
    devices = json.loads(simctl('list', 'devices', '--json'))['devices']
    match = [(runtime, device) for runtime, items in devices.items()
             for device in items if device['udid'] == udid]
    if not match:
        raise ValueError('Simulator not found')
    runtime, device = match[0]
    if (not runtime.endswith('iOS-26-4') or
            not device['deviceTypeIdentifier'].endswith('iPhone-17-Pro') or
            device['state'] != 'Booted'):
        raise ValueError('Requires a booted iPhone 17 Pro on iOS 26.4')
    container = Path(simctl('get_app_container', udid, BUNDLE, 'data'))
    source = container / 'tmp/system-button-geometry.json'
    result = {'device': 'iPhone 17 Pro', 'ios': '26.4', 'styles': {}}
    for style, scene in SCENES.items():
        source.unlink(missing_ok=True)
        simctl('launch', '--terminate-running-process', udid, BUNDLE, '-controls', scene)
        expected = {f'{scene}/{size}/{kind}/{part}' for size in SIZES
                    for kind in ['text', 'icon'] for part in ['button', 'label']}
        for _ in range(60):
            time.sleep(.2)
            data = json.loads(source.read_text()) if source.exists() else {}
            if data.keys() == expected:
                break
        else:
            raise ValueError(f'{scene}: native geometry did not complete')
        if any(len(v) != 2 or any(not math.isfinite(n) or n <= 0 for n in v)
               for v in data.values()):
            raise ValueError(f'{scene}: invalid layout measurements')
        rows = {}
        for size in SIZES:
            def at(kind, part):
                return data[f'{scene}/{size}/{kind}/{part}']
            button, label = at('text', 'button'), at('text', 'label')
            rows[size] = {'button': button, 'label': label,
                          'padding': (button[0] - label[0]) / 2,
                          'iconButton': at('icon', 'button'), 'iconLabel': at('icon', 'label')}
        result['styles'][style] = rows
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('udid')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    measured = capture(args.udid)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(measured, indent=2) + '\n')
    print(args.output)
