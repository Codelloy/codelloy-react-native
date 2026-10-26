#!/bin/sh
# Makes the native SDK artifacts of a development build from a local checkout of the native SDK source.
# Usage: CODELLOY_NATIVE_DIR=<checkout> scripts/native-dev.sh [ios|android]. Without an argument, both.
# iOS: the release XCFramework goes to ios/Frameworks/. Android: the AAR goes to Maven Local.
# The Android part needs JDK 17 or 21.
set -eu
cd "$(dirname "$0")/.."

native=${CODELLOY_NATIVE_DIR:-}
if [ -z "$native" ]; then
    echo "Set CODELLOY_NATIVE_DIR to a local checkout of the native SDK source." >&2
    exit 1
fi
platform=${1:-all}
case $platform in
    ios | android | all) ;;
    *)
        echo "Usage: scripts/native-dev.sh [ios|android]" >&2
        exit 1
        ;;
esac

if [ "$platform" != android ]; then
    script=$native/ios/scripts/build-xcframework.sh
    if [ ! -f "$script" ]; then
        echo "$script is missing. The checkout needs the release XCFramework script of the native SDK." >&2
        exit 1
    fi
    sh "$script"
    rm -rf ios/Frameworks/CodelloySDK.xcframework
    mkdir -p ios/Frameworks
    cp -R "$native/ios/.build/release/CodelloySDK.xcframework" ios/Frameworks/
    echo "ios/Frameworks/CodelloySDK.xcframework is ready."
fi

if [ "$platform" != ios ]; then
    (cd "$native/android" && ./gradlew --quiet publishToMavenLocal)
    echo "com.codelloy:codelloy-android is in Maven Local."
fi
