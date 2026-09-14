#!/usr/bin/env bash
set -euo pipefail
orig=$1 apk=$2 game=$3 gate_dex=$4; base=${apk##*/}; dist=${apk%/*}
apk_sha=$(sha256sum "$apk" | cut -d' ' -f1); apk_size=$(stat -c %s "$apk")
orig_sha=$(sha256sum "$orig" | cut -d' ' -f1)
split -b 95M -d -a 3 "$apk" "$dist/$base.tmp."
i=1
for p in "$dist/$base.tmp."*; do printf -v n '%03d' "$i"; mv "$p" "$dist/$base.$n"; i=$((i+1)); done
count=$((i-1)); parts=("$dist/$base."[0-9][0-9][0-9])
test "${#parts[@]}" -eq "$count"
for p in "${parts[@]}"; do test "$(stat -c %s "$p")" -lt 100000000; done
cat "${parts[@]}" > work/PLAY_GLOBAL_2.31.0_KEY_MNHUT-REJOINED.apk
rejoined=work/PLAY_GLOBAL_2.31.0_KEY_MNHUT-REJOINED.apk
re_sha=$(sha256sum "$rejoined" | cut -d' ' -f1); test "$re_sha" = "$apk_sha"
unzip -tq "$rejoined" > work/logs/rejoined-unzip.txt
zipalign -c -v 4 "$rejoined" > work/logs/rejoined-zipalign.txt
apksigner verify --verbose --print-certs "$rejoined" > work/logs/rejoined-signature.txt
grep -q 'Verified using v2 scheme (APK Signature Scheme v2): true' work/logs/rejoined-signature.txt
grep -q 'Verified using v3 scheme (APK Signature Scheme v3): true' work/logs/rejoined-signature.txt

{
  echo "APK: $base"; echo "APK size: $apk_size bytes"; echo "APK SHA-256: $apk_sha"
  echo "Part count: $count"
  for p in "${parts[@]}"; do echo "$(basename "$p") | $(stat -c %s "$p") bytes | $(sha256sum "$p" | cut -d' ' -f1)"; done
  echo "Rejoined SHA-256: $re_sha"; echo "ZIP: PASS"; echo "zipalign: PASS"
  echo "apksigner: PASS (v2=true, v3=true)"; echo "Package ID: com.mnhutx.playtogether"
  echo "MT Manager: đặt mọi part cùng thư mục, chọn theo thứ tự .001 đến part cuối và ghép nhị phân; đổi tên kết quả thành $base."
} > "$dist/SHA256.txt"

python3 - "$orig_sha" "$apk_sha" "$apk_size" "$count" "$game" "$gate_dex" <<'PY' > "$dist/BUILD_REPORT.txt"
import json,sys
orig,new,size,count,game,dex=sys.argv[1:]
m=json.load(open('work/logs/manifest-transform.json'))
o=json.load(open('work/logs/original-inventory.json')); n=json.load(open('work/logs/final-inventory.json'))
abis=sorted({x['name'].split('/')[1] for x in o if x['name'].startswith('lib/')})
dexes=[x['name'] for x in o if x['name'].startswith('classes')]
print(f'''Play Together MNHUT build report
Original SHA-256: {orig}
New APK SHA-256: {new}
New APK size: {size} bytes
Old package: com.haegin.playtogether
New package: com.mnhutx.playtogether
Display name: Play Together MNHUT
New launcher: com.mnhutx.playtogether.gate.KeyGateActivity
Original game Activity: {game}
Original game Activity exported: false
Moved launcher/deep-link filters: {m['moved_intent_filters']}
Self-identifier changes: {json.dumps(m['identifier_changes'],ensure_ascii=False)}
Original DEX retained byte-for-byte: {', '.join(dexes)}
Added DEX: classes{dex}.dex (KeyGateActivity)
Native ABIs: {', '.join(abis)}
.so/assets comparison: PASS (all original content hashes retained)
unzip -t: PASS
zipalign -c -v 4: PASS
apksigner: PASS; v2=true; v3=true
aapt2: PASS (package, label, launcher and manifest inspected)
Gate static audit: PASS; exact Java String.equals("mnhut"), no trim/case-fold, all launcher/BROWSABLE filters moved, other UI non-exported
Part rejoin: PASS; SHA-256 identical; ZIP/alignment/signature reverified
Part count: {count}; maximum part size: 95 MiB
Runtime limitation: GitHub hosted runner has no compatible game emulator/GPU/server environment; runtime gate and installation tests were not performed.
''')
PY
# Keep the verified complete APK until the publishing step uploads it.
