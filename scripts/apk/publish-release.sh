#!/usr/bin/env bash
set -euo pipefail
tag=${RELEASE_TAG:?}; title='Play Together MNHUT 2.31.0'
if ! gh release view "$tag" >/dev/null 2>&1; then
  gh release create "$tag" --title "$title" --notes-file dist/BUILD_REPORT.txt
fi
retry() { local n=0; until "$@"; do n=$((n+1)); test "$n" -lt 6 || return 1; sleep $((n*10)); done; }
assets=(dist/PLAY_GLOBAL_2.31.0_KEY_MNHUT.apk.[0-9][0-9][0-9] dist/SHA256.txt dist/BUILD_REPORT.txt)
for asset in "${assets[@]}"; do retry gh release upload "$tag" "$asset" --clobber; done

# Upload the verified complete APK to GoFile because it is larger than GitHub's
# 2 GiB per-release-asset limit. Preserve the split assets as a durable fallback.
final_apk=dist/PLAY_GLOBAL_2.31.0_KEY_MNHUT.apk
gofile_response=work/logs/gofile-upload.json
upload_complete_apk() {
  curl --fail --location     --retry 5 --retry-all-errors --retry-delay 10     --connect-timeout 30 --speed-time 120 --speed-limit 1024     -F "file=@${final_apk}"     https://upload.gofile.io/uploadfile     -o "${gofile_response}"
}
retry upload_complete_apk
python3 - "${gofile_response}" > dist/FULL_APK_DOWNLOAD.txt <<'PY'
import json,sys
data=json.load(open(sys.argv[1]))
assert data.get("status") == "ok", data
page=(data.get("data") or {}).get("downloadPage")
assert page and page.startswith("https://"), data
print("Complete APK download (no merging required):")
print(page)
print()
print("Filename: PLAY_GLOBAL_2.31.0_KEY_MNHUT.apk")
print("SHA-256: d8fe0cbf44e555d322168e0cf3cc55603c7d09c0af3341e4ff81890dacd2e227")
PY
retry gh release upload "$tag" dist/FULL_APK_DOWNLOAD.txt --clobber
assets+=(dist/FULL_APK_DOWNLOAD.txt)

# Require an exact remote name/size match for every local release asset.
gh api --paginate "repos/${GITHUB_REPOSITORY}/releases/tags/${tag}" > work/logs/release.json
python3 - "${assets[@]}" <<'PY'
import json,os,sys
r=json.load(open('work/logs/release.json')); remote={x['name']:x['size'] for x in r['assets']}
for p in sys.argv[1:]:
    name=os.path.basename(p); size=os.path.getsize(p)
    assert remote.get(name)==size, f'release mismatch: {name} local={size} remote={remote.get(name)}'
expected={os.path.basename(x) for x in sys.argv[1:]}
assert expected <= set(remote), 'release is missing assets'
print(r['html_url'])
PY
