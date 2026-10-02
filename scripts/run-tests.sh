#!/bin/zsh
set -euo pipefail
exec "$(dirname "$0")/test-macos.sh" "$@"
