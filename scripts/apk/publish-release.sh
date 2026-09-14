#!/usr/bin/env bash
set -euo pipefail
tag=${RELEASE_TAG:?}; title='Play Together MNHUT 2.31.0'
if ! gh release view "$tag" >/dev/null 2>&1; then
  gh release create "$tag" --title "$title" --notes-file dist/BUILD_REPORT.txt
fi
retry() { local n=0; until "$@"; do n=$((n+1)); test "$n" -lt 6 || return 1; sleep $((n*10)); done; }
assets=(dist/PLAY_GLOBAL_2.31.0_KEY_MNHUT.apk.[0-9][0-9][0-9] dist/SHA256.txt dist/BUILD_REPORT.txt)
for asset in "${assets[@]}"; do retry gh release upload "$tag" "$asset" --clobber; done

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
