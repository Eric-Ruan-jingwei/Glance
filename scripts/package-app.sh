#!/bin/zsh
set -euo pipefail
exec "$(dirname "$0")/package-macos.sh" "$@"
