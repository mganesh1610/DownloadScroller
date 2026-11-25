#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
CHECK_DIR="$PROJECT_ROOT/.build/core-checks"
mkdir -p "$CHECK_DIR"
swiftc -swift-version 5 -parse-as-library -enable-testing -emit-library -emit-module \
  -module-name DownloadScrollerCore Sources/DownloadScrollerCore/*.swift \
  -emit-module-path "$CHECK_DIR/DownloadScrollerCore.swiftmodule" \
  -o "$CHECK_DIR/libDownloadScrollerCore.dylib"
swiftc -swift-version 5 -parse-as-library -D STANDALONE_CHECKS \
  -I "$CHECK_DIR" -L "$CHECK_DIR" -lDownloadScrollerCore \
  -Xlinker -rpath -Xlinker "$CHECK_DIR" \
  scripts/CLTTestSupport.swift Tests/DownloadScrollerCoreTests/*.swift \
  -o "$CHECK_DIR/CoreChecks"
"$CHECK_DIR/CoreChecks"
