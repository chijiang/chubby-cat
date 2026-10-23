#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing-preflight.sh
validate_version
require_identity_name
[ -n "${NOTARY_PROFILE:-}" ] || fail 'NOTARY_PROFILE is required; store notarization credentials locally with notarytool store-credentials.'
verify_identity_available
for tool in codesign security ditto shasum python3 spctl; do command -v "$tool" >/dev/null || fail "Missing tool: $tool"; done
xcrun --find notarytool >/dev/null
xcrun --find stapler >/dev/null
case "${1:-}" in
    --check) printf 'Local release prerequisites ready. Notarization credentials are verified with Apple during release.\n'; exit 0 ;;
    '') ;;
    *) fail 'Usage: bash scripts/release.sh --notarized [--check]' ;;
esac

export APP_VERSION="${APP_VERSION:-0.2.0}"
export BUILD_NUMBER="${BUILD_NUMBER:-2}"
work="$PWD/dist/release-staging"
app="$work/chubby-cat.app"
final_dir="$PWD/dist/releases"
final_name="chubby-cat-${APP_VERSION}-macos-arm64.zip"
[ ! -e "$final_dir/$final_name" ] || fail 'This release already exists. Increment APP_VERSION before publishing another build.'
# Verify the stored profile before building. Passwords/private keys never enter this script.
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null
bash scripts/test.sh
python3 -m unittest discover -s Tests -p test_release_pipeline.py
bash scripts/build-app.sh release
[ "$(lipo -archs "$app/Contents/MacOS/chubby-cat")" = arm64 ] || fail 'This release script currently supports the arm64 build only.'
ditto -c -k --sequesterRsrc --keepParent "$app" "$work/notary-submission.zip"
printf 'Submitting signed app to Apple notarization…\n'
xcrun notarytool submit "$work/notary-submission.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$work/notary-result.json"
python3 scripts/notary-status.py "$work/notary-result.json"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --deep --strict "$app"
spctl --assess --type execute --verbose=2 "$app"
# Only this explicitly notarized channel requires all Apple checks before packaging.
mkdir -p "$final_dir"
ditto -c -k --sequesterRsrc --keepParent "$app" "$final_dir/$final_name.partial"
mv "$final_dir/$final_name.partial" "$final_dir/$final_name"
(cd "$final_dir" && shasum -a 256 "$final_name" > "$final_name.sha256")
cp "$work/notary-result.json" "$final_dir/$final_name.notary.json"
printf 'Notarized release ready: %s/%s\n' "$final_dir" "$final_name"
