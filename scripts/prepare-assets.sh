#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
ASSET_DIR="Sources/DownloadScroller/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$ASSET_DIR" .build/AppIcon.iconset
swift scripts/generate-icon.swift .build/AppIcon.iconset
cp .build/AppIcon.iconset/*.png "$ASSET_DIR/"
python3 - <<'PY'
from pathlib import Path
import json
root = Path('Sources/DownloadScroller/Resources/Assets.xcassets')
images = []
for points in [16, 32, 128, 256, 512]:
    for scale in [1, 2]:
        images.append({'idiom': 'mac', 'size': f'{points}x{points}', 'scale': f'{scale}x',
                       'filename': f'icon_{points}x{points}{"@2x" if scale == 2 else ""}.png'})
(root / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
(root / 'AppIcon.appiconset/Contents.json').write_text(json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
PY
