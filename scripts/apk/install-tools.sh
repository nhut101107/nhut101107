#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y android-sdk-build-tools android-sdk-platform-tools unzip zip curl python3-pip jq
python3 -m pip install --break-system-packages gdown

mkdir -p tools
APKTOOL_VERSION=2.11.1
curl -fL --retry 10 --retry-all-errors -o tools/apktool.jar \
  "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar"
printf '#!/bin/sh\nexec java -Xmx6g -jar "%s/tools/apktool.jar" "$@"\n' "$PWD" > tools/apktool
chmod +x tools/apktool scripts/apk/*.sh scripts/apk/*.py

BUILD_TOOLS="$(find "${ANDROID_HOME:-/usr/lib/android-sdk}/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
test -x "$BUILD_TOOLS/apksigner"
test -x "$BUILD_TOOLS/zipalign"
echo "$BUILD_TOOLS" >> "$GITHUB_PATH"
echo "$PWD/tools" >> "$GITHUB_PATH"

