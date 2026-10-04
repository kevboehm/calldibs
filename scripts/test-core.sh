#!/bin/sh
# Runs the DibsCore tests. With full Xcode selected, plain `swift test` is
# enough; with only the Command Line Tools, Swift Testing needs to be pointed at.
set -e
cd "$(dirname "$0")/.."

dev="$(xcode-select -p)"
if [ "$dev" = "/Library/Developer/CommandLineTools" ]; then
  lib="$dev/Library/Developer"
  exec swift test --package-path Packages/DibsCore \
    -Xswiftc -F -Xswiftc "$lib/Frameworks" \
    -Xlinker -F -Xlinker "$lib/Frameworks" \
    -Xlinker -rpath -Xlinker "$lib/Frameworks" \
    -Xlinker -rpath -Xlinker "$lib/usr/lib" "$@"
fi
exec swift test --package-path Packages/DibsCore "$@"
