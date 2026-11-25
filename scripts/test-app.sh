#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
# Build the shared core test library and run its existing scenarios first.
bash scripts/test-core.sh
CHECK_DIR="$PROJECT_ROOT/.build/core-checks"
swiftc -swift-version 5 -parse-as-library -D STANDALONE_CHECKS -D APP_CHECKS -D SWIFT_PACKAGE \
  -I "$CHECK_DIR" -L "$CHECK_DIR" -lDownloadScrollerCore \
  -Xlinker -rpath -Xlinker "$CHECK_DIR" \
  Sources/DownloadScroller/LibraryModel.swift Sources/DownloadScroller/FolderWatcher.swift Sources/DownloadScroller/FolderContents.swift \
  Sources/DownloadScroller/FanMetrics.swift Sources/DownloadScroller/FanPlacement.swift \
  Sources/DownloadScroller/FolderBookmark.swift Sources/DownloadScroller/FanCopyPermission.swift \
  Sources/DownloadScroller/DockVisibility.swift Sources/DownloadScroller/DockClick.swift Sources/DownloadScroller/FanFileDrag.swift \
  Sources/DownloadScroller/SampleLibrary.swift scripts/CLTTestSupport.swift \
  Tests/DownloadScrollerTests/*.swift -o "$CHECK_DIR/AppChecks"
"$CHECK_DIR/AppChecks"
