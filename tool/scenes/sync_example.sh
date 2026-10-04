#!/usr/bin/env bash
# Copies tool/scenes/scenes.json into the example app's assets (Flutter cannot
# bundle files from outside the package). Run after gen_scenes.py.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p example/assets
cp tool/scenes/scenes.json example/assets/scenes.json
echo "synced example/assets/scenes.json"
