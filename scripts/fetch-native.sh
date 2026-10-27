#!/bin/sh
# Puts the XCFramework of the native SDK release that package.json pins (codelloyNative) into ios/Frameworks/.
# npm runs it before each pack and publish (prepack). It stops on each error, so npm never packs a wrong binary.
# CODELLOY_NATIVE_URL replaces the release download URL before the version, for a test. The SHA-256 check stays. npm
# pack and npm publish refuse it.
set -eu
cd "$(dirname "$0")/.."

version=$(node -p "require('./package.json').codelloyNative.version")
sha256=$(node -p "require('./package.json').codelloyNative.sha256")
# The version goes into the URL and the file name. curl resolves .. in a URL.
case $version in
    *[!0-9.]* | .* | *. | *..* | *.*.*.*) version= ;;
esac
case $version in
    *.*.*) ;;
    *)
        echo "codelloyNative.version in package.json must be major.minor.patch." >&2
        exit 1
        ;;
esac
case $sha256 in
    *[!0-9a-f]*) sha256= ;;
esac
if [ ${#sha256} -ne 64 ]; then
    echo "codelloyNative.sha256 in package.json must be 64 lowercase hex characters." >&2
    exit 1
fi
case $sha256 in
    *[!0]*) ;;
    *)
        echo "codelloyNative in package.json is the placeholder: no native SDK release is pinned. README.md, Release," \
            "tells how to pin one." >&2
        exit 1
        ;;
esac

if [ "${npm_lifecycle_event:-}" = prepack ] && [ -n "${CODELLOY_NATIVE_URL:-}" ]; then
    echo "CODELLOY_NATIVE_URL is only for a test. npm pack and npm publish download the release." >&2
    exit 1
fi

name=CodelloySDK-$version.xcframework.zip
url=${CODELLOY_NATIVE_URL:-https://github.com/Codelloy/codelloy-ios/releases/download}/$version/$name
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# -f makes an HTTP error, for example a release that does not exist, a failure.
if ! curl -fsSL --retry 3 -o "$tmp/$name" "$url"; then
    echo "Could not download $url." >&2
    exit 1
fi
actual=$(shasum -a 256 "$tmp/$name" | cut -d ' ' -f 1)
if [ "$actual" != "$sha256" ]; then
    echo "The SHA-256 of $url is $actual, but codelloyNative.sha256 is $sha256." >&2
    exit 1
fi
unzip -q "$tmp/$name" -d "$tmp/zip"
if [ ! -d "$tmp/zip/CodelloySDK.xcframework" ]; then
    echo "$name has no CodelloySDK.xcframework at its root." >&2
    exit 1
fi
rm -rf ios/Frameworks
mkdir -p ios/Frameworks
mv "$tmp/zip/CodelloySDK.xcframework" ios/Frameworks/
echo "ios/Frameworks/CodelloySDK.xcframework is the native SDK release $version."
