#!/usr/bin/env bash
set -euo pipefail
orig=$1 apk=$2 game=$3 gate_dex=$4
unzip -tq "$apk" | tee work/logs/final-unzip.txt
zipalign -c -v 4 "$apk" > work/logs/final-zipalign.txt
apksigner verify --verbose --print-certs "$apk" | tee work/logs/final-signature.txt
grep -q 'Verified using v2 scheme (APK Signature Scheme v2): true' work/logs/final-signature.txt
grep -q 'Verified using v3 scheme (APK Signature Scheme v3): true' work/logs/final-signature.txt
aapt2 dump badging "$apk" > work/logs/final-badging.txt
aapt2 dump xmltree "$apk" --file AndroidManifest.xml > work/logs/final-manifest.txt
grep -q "package: name='com.mnhutx.playtogether'" work/logs/final-badging.txt
grep -q "application-label:'Play Together MNHUT'" work/logs/final-badging.txt
grep -q 'com.mnhutx.playtogether.gate.KeyGateActivity' work/logs/final-badging.txt
grep -q "$game" work/logs/final-manifest.txt
python3 scripts/apk/inventory.py "$apk" work/logs/final-inventory.json
python3 scripts/apk/static_audit.py "$game" "$gate_dex"
