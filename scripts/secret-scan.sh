#!/bin/sh
# Scans the git history for secrets. First gitleaks with .gitleaks.toml. Then a search for the real identifying
# values, which CI gets from secrets. A local run without the SCAN_ variables runs only gitleaks.
set -eu
cd "$(dirname "$0")/.."

version=8.30.1
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) asset=darwin_arm64 sha256=b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 ;;
    Linux-x86_64) asset=linux_x64 sha256=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb ;;
    *)
        echo "No pinned gitleaks binary for $(uname -s)-$(uname -m)." >&2
        exit 1
        ;;
esac
dir=.build/tools/gitleaks-$version
if [ ! -x "$dir/gitleaks" ]; then
    mkdir -p "$dir"
    curl -fsSL --retry 3 -o "$dir/gitleaks.tar.gz" \
        "https://github.com/gitleaks/gitleaks/releases/download/v$version/gitleaks_${version}_$asset.tar.gz"
    echo "$sha256  $dir/gitleaks.tar.gz" | shasum -a 256 -c - >/dev/null
    tar -xzf "$dir/gitleaks.tar.gz" -C "$dir" gitleaks
fi
"$dir/gitleaks" git --config .gitleaks.toml --redact --no-banner .
# The lockfiles are -diff in .gitattributes, so the git scan does not read them.
"$dir/gitleaks" dir --config .gitleaks.toml --redact --no-banner package-lock.json example/package-lock.json

# Each commit message and each patch, also of merges. Without the colons, a fingerprint matches in both of its forms
# (AB:CD:... and abcd...). The message names the secret and never shows its value.
found=0
for name in SCAN_TEAM_ID SCAN_BUNDLE_ID SCAN_APPLICATION_ID SCAN_LINK_DOMAIN SCAN_STAGING_HOST SCAN_CERT_SHA256; do
    value=$(printenv "$name" | tr -d : || true)
    [ -n "$value" ] || continue
    if git log --all -p -m --text --format=%B | tr -d : | grep -i -F -q -e "$value"; then
        echo "The git history contains the value of $name." >&2
        found=1
    fi
done
[ "$found" -eq 0 ]
echo "The secret scan found no secret."
