#!/usr/bin/env bash
# Copies tool/scenes/scenes.json and measure.json into the example app's assets (Flutter cannot
# bundle files from outside the package). Run after gen_scenes.py.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p example/assets
cp tool/scenes/scenes.json example/assets/scenes.json
cp tool/scenes/measure.json example/assets/measure.json
echo "synced example/assets/scenes.json and measure.json"
