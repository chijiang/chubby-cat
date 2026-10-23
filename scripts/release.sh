#!/bin/bash
# Default: self-distributed preview. Apple notarization is an explicit opt-in.
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
    ''|--check) exec bash scripts/package-preview.sh "$@" ;;
    --notarized) shift; exec bash scripts/release-notarized.sh "$@" ;;
    *) printf 'Usage: bash scripts/release.sh [--check | --notarized [--check]]\n' >&2; exit 1 ;;
esac
