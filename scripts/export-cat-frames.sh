#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
if [ "$#" -eq 0 ] && [ -f assets/cat/walk-cycle-v4.png ]; then
    set -- assets/cat/walk-cycle-v4.png
fi
swift run --disable-sandbox --cache-path .build/cache --manifest-cache local ChubbyCatArtExporter "$@"
