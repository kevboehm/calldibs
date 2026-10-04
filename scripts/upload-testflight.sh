#!/bin/sh
# Archives a Release build and uploads it to App Store Connect for TestFlight.
# Needs the developer account signed in to Xcode. The build number defaults
# to a timestamp, so every upload is higher than the last.
# Usage: scripts/upload-testflight.sh [build-number]
set -e
cd "$(dirname "$0")/.."

build="${1:-$(date +%Y%m%d%H%M)}"
archive="build/Dibs.xcarchive"

xcodebuild -project Dibs.xcodeproj -scheme Dibs -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  CURRENT_PROJECT_VERSION="$build" -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath "$archive" \
  -exportOptionsPlist AppStore/ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates
