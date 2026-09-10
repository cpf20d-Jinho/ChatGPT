#!/bin/bash
set -euo pipefail
: "${APPLE_TEAM_ID:?Set the Apple Developer Team ID; signing assets must already be installed.}"
if [[ ! "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo 'Invalid Team ID format.' >&2
  exit 1
fi
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
release_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
release_sha="$(git -C "$repo_root" rev-parse --short HEAD)"
release_dir="${ABA_RELEASE_OUTPUT:-$repo_root/../ABAProgress-releases}/$release_stamp-$release_sha"
mkdir -p "$release_dir"
export ABA_EXPORT_OPTIONS="$release_dir/ExportOptions.plist"
python3 - <<'PY'
import os,plistlib
with open(os.environ['ABA_EXPORT_OPTIONS'],'wb') as f:
 plistlib.dump({'method':'app-store-connect','teamID':os.environ['APPLE_TEAM_ID'],'signingStyle':'automatic','destination':'export','uploadSymbols':True},f)
PY
xcodebuild -project "$repo_root/ABAProgress/XcodeProject/ABAProgress.xcodeproj" \
  -scheme ABAProgress -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$release_dir/ABAProgress.xcarchive" DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$release_dir/ABAProgress.xcarchive" \
  -exportPath "$release_dir/export" -exportOptionsPlist "$ABA_EXPORT_OPTIONS" -allowProvisioningUpdates
printf 'Export created at %s\nValidate in Xcode Organizer before upload.\n' "$release_dir"
