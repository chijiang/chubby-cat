#!/bin/bash
# Shared release checks. Source this file; it performs no signing or uploads.
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
validate_version() {
    [[ "${APP_VERSION:-0.2.0}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'APP_VERSION must contain three numeric components, for example 0.2.0.'
    [[ "${BUILD_NUMBER:-2}" =~ ^[0-9]+$ ]] || fail 'BUILD_NUMBER must be a nonnegative integer.'
}
require_identity_name() {
    [ -n "${SIGNING_IDENTITY:-}" ] || fail 'SIGNING_IDENTITY is required for the optional Developer ID/notarized channel. Self-distributed previews do not require it.'
    case "$SIGNING_IDENTITY" in
        'Developer ID Application: '*) ;;
        *) fail 'The notarized channel requires a Developer ID Application identity; use the preview channel for ad-hoc signing.' ;;
    esac
}
verify_identity_available() {
    security find-identity -v -p codesigning | grep -F -- "\"$SIGNING_IDENTITY\"" >/dev/null || fail 'The requested Developer ID Application signing identity/private key is not available in the keychain.'
}
