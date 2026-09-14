#!/usr/bin/env bash
set -euo pipefail
ROOT=$PWD; WORK=$ROOT/work; DIST=$ROOT/dist; LOG=$WORK/logs
rm -rf "$WORK" "$DIST"; mkdir -p "$LOG" "$DIST"
ORIG=$WORK/PLAY_GLOBAL_2.31.0_ORIGINAL.apk
scripts/apk/download.sh "$ORIG"
python3 scripts/apk/inventory.py "$ORIG" "$LOG/original-inventory.json"
apksigner verify --verbose --print-certs "$ORIG" > "$LOG/original-signature.txt" || true
aapt2 dump badging "$ORIG" > "$LOG/original-badging.txt"
aapt2 dump xmltree "$ORIG" --file AndroidManifest.xml > "$LOG/original-manifest.txt"

apktool d -f -s "$ORIG" -o "$WORK/decoded"
GAME_ACTIVITY=$(python3 scripts/apk/transform_manifest.py "$WORK/decoded/AndroidManifest.xml" "$LOG/manifest-transform.json")
apktool b "$WORK/decoded" -o "$WORK/base-unsigned.apk"

# Compile an isolated gate and append it as a new highest-numbered DEX.
ANDROID_JAR=$(find "${ANDROID_HOME:-/usr/lib/android-sdk}/platforms" -name android.jar | sort -V | tail -1)
mkdir -p "$WORK/gate-src/com/mnhutx/playtogether/gate" "$WORK/gate-classes" "$WORK/gate-dex"
sed "s|__GAME_ACTIVITY__|$GAME_ACTIVITY|g" scripts/apk/KeyGateActivity.java.in > "$WORK/gate-src/com/mnhutx/playtogether/gate/KeyGateActivity.java"
javac -source 8 -target 8 -classpath "$ANDROID_JAR" -d "$WORK/gate-classes" "$WORK/gate-src/com/mnhutx/playtogether/gate/KeyGateActivity.java"
D8=$(find "${ANDROID_HOME:-/usr/lib/android-sdk}/build-tools" -name d8 | sort -V | tail -1)
(cd "$WORK/gate-classes" && jar cf "$WORK/gate.jar" .)
"$D8" --lib "$ANDROID_JAR" --min-api 23 --output "$WORK/gate-dex" "$WORK/gate.jar"
max=$(zipinfo -1 "$WORK/base-unsigned.apk" | sed -n 's/^classes\([0-9]*\)\.dex$/\1/p' | sed 's/^$/1/' | sort -n | tail -1)
next=$((max+1)); cp "$WORK/gate-dex/classes.dex" "$WORK/classes${next}.dex"
if zipinfo -1 "$ORIG" | grep -E '^classes[0-9]*\.dex$' | while read -r d; do unzip -p "$ORIG" "$d"; done | strings | grep -Fq 'com/mnhutx/playtogether/gate/KeyGateActivity'; then
  echo 'Duplicate KeyGateActivity found in original DEX' >&2; exit 1
fi
(cd "$WORK" && zip -q -0 base-unsigned.apk "classes${next}.dex")

zipalign -p -f 4 "$WORK/base-unsigned.apk" "$WORK/aligned.apk"
keytool -genkeypair -noprompt -keystore "$WORK/mnhut-temporary.jks" -storepass changeit -keypass changeit -alias mnhut -keyalg RSA -keysize 4096 -validity 10000 -dname 'CN=Play Together MNHUT, O=MNHUT, C=VN'
FINAL=$DIST/PLAY_GLOBAL_2.31.0_KEY_MNHUT.apk
apksigner sign --ks "$WORK/mnhut-temporary.jks" --ks-pass pass:changeit --key-pass pass:changeit --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --out "$FINAL" "$WORK/aligned.apk"
scripts/apk/verify.sh "$ORIG" "$FINAL" "$GAME_ACTIVITY" "$next"
scripts/apk/split-and-report.sh "$ORIG" "$FINAL" "$GAME_ACTIVITY" "$next"
