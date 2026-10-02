#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
echo "Building Glance (debug)…"
swift build --product Glance
echo "Build complete."
