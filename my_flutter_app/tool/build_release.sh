#!/usr/bin/env bash
# Build the signed Android App Bundle for Google Play.
#   tool/build_release.sh https://api.<your-domain>/api/v1
#
# Refuses a missing or non-https API URL: without --dart-define=API_URL the app
# silently builds in demo mode (mock data, no backend). The app ID guard lives
# in android/app/build.gradle.kts.
set -euo pipefail
cd "$(dirname "$0")/.."

API_URL="${1:-}"
case "$API_URL" in
  https://*/api/v1) ;;
  *)
    echo "usage: tool/build_release.sh https://api.<your-domain>/api/v1" >&2
    exit 1
    ;;
esac

if [ ! -f android/key.properties ]; then
  echo "build_release: android/key.properties is missing — a Play upload must be signed" \
       "with your upload key (Job-backend/deploy/README.md §5)" >&2
  exit 1
fi
if [ ! -f android/app/google-services.json ]; then
  echo "build_release: warning — no android/app/google-services.json: push notifications" \
       "will be disabled in this build" >&2
fi

flutter build appbundle --release --dart-define=API_URL="$API_URL"
echo "build_release: build/app/outputs/bundle/release/app-release.aab"
