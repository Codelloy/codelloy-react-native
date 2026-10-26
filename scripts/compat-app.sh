#!/bin/sh
# Makes a temporary React Native app, installs the packed wrapper, type-checks a file that calls each function and
# builds the app.
# Usage: scripts/compat-app.sh <react-native version|latest> <old|new> <ios|android> [folder]
# Run scripts/native-dev.sh for the platform first. CI uses the pinned release (scripts/fetch-native.sh and Maven
# Central). iOS needs Ruby with Bundler. Android needs JDK 17.
set -eu
cd "$(dirname "$0")/.."

[ $# -ge 3 ] || {
    echo "Usage: scripts/compat-app.sh <react-native version|latest> <old|new> <ios|android> [folder]" >&2
    exit 1
}
version=$1 arch=$2 platform=$3
dir=${4:-$(mktemp -d)}
[ "$version" != latest ] || version=$(npm view react-native version)
case $arch in
    old) new_arch=false ;;
    new) new_arch=true ;;
    *) echo "The architecture is old or new." >&2 && exit 1 ;;
esac
# The CLI of React Native 0.74 is version 13.
case $version in
    0.74.*) cli=13.6.9 ;;
    *) cli=latest ;;
esac

mkdir -p "$dir"
# The files that npm publishes. Without scripts, prepack does not replace ios/Frameworks with the release, and lib/ is
# the build of npm install.
npm pack --ignore-scripts --pack-destination "$dir" >/dev/null
tarball=$(ls "$dir"/codelloy-react-native-*.tgz)
cd "$dir"
rm -rf CompatApp
# Without --pm npm, the CLI can select Yarn with Plug'n'Play, and the template files are not copied.
npx --yes "@react-native-community/cli@$cli" init CompatApp --version "$version" --pm npm --skip-install \
    --skip-git-init --install-pods false
cd CompatApp
npm install --no-audit --no-fund "$tarball"

cat >Codelloy.ts <<'EOF'
import * as Codelloy from '@codelloy/react-native';

Codelloy.init({
  key: 'pk_test_x',
  clipboard: true,
  signalMatching: true,
  autoMatch: false,
  minConfidence: 'medium',
  debug: true,
  baseUrl: 'http://localhost:8080/link',
});
const remove: () => void = Codelloy.onLink((link: Codelloy.CodelloyLink) => {
  console.log(link.id, link.url, link.shortUrl, link.isDeferred, link.matchType, link.confidence);
});
remove();
void Codelloy.match().then((link: Codelloy.CodelloyLink | null) => link?.url);
const handled: boolean = Codelloy.handleLink('https://links.example.com/abc');
const id: string | null = Codelloy.installId();
const reset: boolean = Codelloy.resetForTesting();
console.log(handled, id, reset);
EOF
npx tsc --noEmit

if [ "$platform" = ios ]; then
    # The native SDK needs iOS 15.0. React Native 0.74 supports iOS 13.4.
    sed -i.bak 's/^platform :ios, min_ios_version_supported$/platform :ios, [min_ios_version_supported.to_f, 15.0].max.to_s/' \
        ios/Podfile
    # The Gemfile of React Native 0.74 allows json 2.10, which breaks its pod install (unknown keyword: quirks_mode).
    [ "$cli" != 13.6.9 ] || echo "gem 'json', '< 2.10'" >>Gemfile
    bundle install --quiet
    if [ "$new_arch" = true ]; then flag=1; else flag=0; fi
    (cd ios && RCT_NEW_ARCH_ENABLED=$flag bundle exec pod install)
    xcodebuild -quiet -workspace ios/CompatApp.xcworkspace -scheme CompatApp -configuration Debug -sdk iphonesimulator \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/build CODE_SIGNING_ALLOWED=NO build
else
    sed -i.bak "s/^newArchEnabled=.*/newArchEnabled=$new_arch/" android/gradle.properties
    # shortcut: the native SDK comes from Maven Local (scripts/native-dev.sh), remove at the Maven Central release.
    printf '\nallprojects {\n  repositories {\n    mavenLocal { content { includeGroup "com.codelloy" } }\n  }\n}\n' \
        >>android/build.gradle
    (cd android && ./gradlew assembleDebug -PreactNativeArchitectures=arm64-v8a --console=plain)
fi
echo "React Native $version ($arch architecture) builds with the wrapper on $platform."
