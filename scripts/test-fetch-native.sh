#!/bin/sh
# Tests scripts/fetch-native.sh in a temporary package against fixture zips: a good release, a wrong SHA-256, a missing
# release, a network error, a zip with a wrong layout, the placeholder pin, a bad version and CODELLOY_NATIVE_URL in
# prepack.
set -eu
cd "$(dirname "$0")/.."

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/pkg/scripts" "$dir/good/CodelloySDK.xcframework" "$dir/bad/Other.xcframework" "$dir/releases/9.8.7" \
    "$dir/releases/9.8.8"
cp scripts/fetch-native.sh "$dir/pkg/scripts/"
echo fixture >"$dir/good/CodelloySDK.xcframework/Info.plist"
echo fixture >"$dir/bad/Other.xcframework/Info.plist"
(cd "$dir/good" && zip -qr "$dir/releases/9.8.7/CodelloySDK-9.8.7.xcframework.zip" CodelloySDK.xcframework)
(cd "$dir/bad" && zip -qr "$dir/releases/9.8.8/CodelloySDK-9.8.8.xcframework.zip" Other.xcframework)
sha() { shasum -a 256 "$dir/releases/$1/CodelloySDK-$1.xcframework.zip" | cut -d ' ' -f 1; }
releases=file://$dir/releases

fail() {
    echo "$1" >&2
    exit 1
}
# Runs the script with the pin $1 (version) and $2 (sha256) and the release URL $3. Prints its output.
fetch() {
    printf '{ "codelloyNative": { "version": "%s", "sha256": "%s" } }\n' "$1" "$2" >"$dir/pkg/package.json"
    CODELLOY_NATIVE_URL=$3 "$dir/pkg/scripts/fetch-native.sh" 2>&1
}
# $1: a part of the expected error, then the arguments of fetch.
refused() {
    expected=$1
    shift
    if output=$(fetch "$@"); then
        fail "fetch-native.sh did not stop for $*."
    fi
    case $output in
        *"$expected"*) ;;
        *) fail "fetch-native.sh stopped for $* without \"$expected\": $output" ;;
    esac
    # A stop keeps the XCFramework of the last good fetch.
    [ -f "$dir/pkg/ios/Frameworks/CodelloySDK.xcframework/Info.plist" ] || fail "A stop for $* removed the XCFramework."
}

fetch 9.8.7 "$(sha 9.8.7)" "$releases" >/dev/null || fail "fetch-native.sh did not fetch a good release."
[ -f "$dir/pkg/ios/Frameworks/CodelloySDK.xcframework/Info.plist" ] || fail "ios/Frameworks has no XCFramework."
echo "fetch-native.sh unzips a good release into ios/Frameworks."

refused 'but codelloyNative.sha256 is' 9.8.7 "$(printf '%064d' 1)" "$releases"
refused 'Could not download' 9.9.9 "$(sha 9.8.7)" "$releases"
# Nothing listens on port 9 of the local host.
refused 'Could not download' 9.8.7 "$(sha 9.8.7)" http://127.0.0.1:9
refused 'has no CodelloySDK.xcframework' 9.8.8 "$(sha 9.8.8)" "$releases"
refused 'placeholder' 9.8.7 "$(printf '%064d' 0)" "$releases"
refused 'major.minor.patch' 9.8.7/.. "$(sha 9.8.7)" "$releases"
# curl resolves .. in the URL, so the download would leave the release.
refused 'major.minor.patch' .. "$(sha 9.8.7)" "$releases"
refused 'major.minor.patch' 9.8 "$(sha 9.8.7)" "$releases"
# npm pack and npm publish (prepack) download only from the release.
(
    export npm_lifecycle_event=prepack
    refused 'CODELLOY_NATIVE_URL' 9.8.7 "$(sha 9.8.7)" "$releases"
)
echo "fetch-native.sh stops for a wrong SHA-256, a missing release, a network error, a wrong layout, the placeholder" \
    "pin, a bad version and CODELLOY_NATIVE_URL in prepack."
