#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
mkdir -p .build
swiftc -swift-version 5 Sources/DownloadScroller/AppLogo.swift scripts/generate-icon.swift -o .build/GenerateIcon
.build/GenerateIcon "${1:-.build/AppIcon.iconset}"
