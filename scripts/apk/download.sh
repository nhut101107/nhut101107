#!/usr/bin/env bash
set -euo pipefail
out=$1
id=${APK_FILE_ID:?APK_FILE_ID is required}
url="https://drive.google.com/file/d/${id}/view?usp=drivesdk"

gdown --fuzzy --continue "$url" -O "$out" || true
if ! python3 - "$out" <<'PY'
import os,sys
p=sys.argv[1]
sys.exit(0 if os.path.exists(p) and os.path.getsize(p) > 2_000_000_000 else 1)
PY
then
  if test -f "$out" && test "$(head -c 2 "$out" 2>/dev/null || true)" != "PK"; then rm -f "$out"; fi
  # drive.usercontent handles large-file confirmation; -C resumes a partial file.
  curl -fL -C - --retry 20 --retry-all-errors --retry-delay 5 \
    --connect-timeout 30 --speed-time 60 --speed-limit 1024 \
    -o "$out" "https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t"
fi

size=$(stat -c %s "$out")
test "$size" -ge 2100000000 -a "$size" -le 2250000000 || {
  echo "Unexpected source size: $size" >&2; exit 1;
}
test "$(head -c 2 "$out")" = "PK"
unzip -tq "$out"
sha256sum "$out" | tee work/logs/original-apk.sha256
stat -c '%n %s bytes' "$out" | tee work/logs/original-apk.size
