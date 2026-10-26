#!/bin/sh
# Tests scripts/secret-scan.sh in a temporary repo: a commit adds an SDK key to a lockfile and a later commit removes it.
set -eu
cd "$(dirname "$0")/.."

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/scripts"
cp scripts/secret-scan.sh "$dir/scripts/"
cp .gitattributes .gitleaks.toml "$dir/"
# The pinned gitleaks binary, downloaded one time.
mkdir -p .build
ln -s "$PWD/.build" "$dir/.build"
cd "$dir"
git init -q
git config user.email test@example.com
git config user.name test
# The key is made here, so this file holds no key.
printf '{ "key": "pk_test_%032d" }\n' 0 >package-lock.json
git add -A
git commit -qm key
echo '{}' >package-lock.json
git commit -qam 'no key'

if scripts/secret-scan.sh 2>&1 | grep -q 'contains a Codelloy SDK key'; then
    echo "The secret scan finds a key in the history of a lockfile."
else
    echo "The secret scan did not find the key in the history of the lockfile." >&2
    exit 1
fi
