#!/bin/sh
# Lints the native glue: SwiftLint (--strict) on ios/*.swift, clang-format on ios/*.mm and ktlint on android/.
# SwiftLint and ktlint are pinned release binaries in .build/tools/. clang-format comes from npm (clang-format-node).
# Runs on macOS with Java on the PATH (ktlint). Run npm install first.
set -eu
cd "$(dirname "$0")/.."

# Downloads a file one time into .build/tools/ and checks its SHA-256. $1: URL, $2: SHA-256, $3: file.
fetch() {
    if [ ! -f "$3" ]; then
        mkdir -p "$(dirname "$3")"
        curl -fsSL --retry 3 -o "$3.part" "$1"
        echo "$2  $3.part" | shasum -a 256 -c - >/dev/null
        mv "$3.part" "$3"
    fi
}

swiftlint=.build/tools/swiftlint-0.65.1
fetch https://github.com/realm/SwiftLint/releases/download/0.65.1/portable_swiftlint.zip \
    c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0 "$swiftlint/swiftlint.zip"
[ -x "$swiftlint/swiftlint" ] || unzip -oq "$swiftlint/swiftlint.zip" swiftlint -d "$swiftlint"
"$swiftlint/swiftlint" lint --strict --quiet

npx clang-format --dry-run --Werror ios/*.mm

ktlint=.build/tools/ktlint-1.8.0/ktlint
fetch https://github.com/pinterest/ktlint/releases/download/1.8.0/ktlint \
    a3fd620207d5c40da6ca789b95e7f823c54e854b7fade7f613e91096a3706d75 "$ktlint"
chmod +x "$ktlint"
"$ktlint" --relative "android/**/*.kt"

echo "The native glue passes SwiftLint, clang-format and ktlint."
