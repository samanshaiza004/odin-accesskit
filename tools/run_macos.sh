#!/bin/sh
set -eu

# An exact gate: Linux, MSYS, and other Unix systems cannot build AppKit hosts.
if [ "$(uname -s)" != Darwin ]; then
    echo 'The native macOS example requires macOS (Darwin).' >&2
    exit 1
fi
case "${1-}" in
    '') [ "$#" -eq 0 ] || { echo 'Usage: sh tools/run_macos.sh [--smoke]' >&2; exit 2; } ;;
    --smoke) [ "$#" -eq 1 ] || { echo 'Usage: sh tools/run_macos.sh [--smoke]' >&2; exit 2; } ;;
    *) echo 'Usage: sh tools/run_macos.sh [--smoke]' >&2; exit 2 ;;
esac

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
EXAMPLE_DIR="$REPO_ROOT/examples/macos"
BUILD_DIR="$EXAMPLE_DIR/build"
ODIN=${ODIN:-odin}
case "$(uname -m)" in
    arm64|aarch64) CLANG_ARCH=arm64; ODIN_TARGET=darwin_arm64 ;;
    x86_64) CLANG_ARCH=x86_64; ODIN_TARGET=darwin_amd64 ;;
    *) echo "Unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
esac
cd "$REPO_ROOT"
# bootstrap.sh verifies AccessKit C 0.23.1 and honors ACCESSKIT_CACHE_ROOT.
ACCESSKIT_FLAGS=$(sh "$SCRIPT_DIR/bootstrap.sh")
mkdir -p "$BUILD_DIR"
xcrun clang -arch "$CLANG_ARCH" -fobjc-arc -fmodules -Wall -Wextra -Werror \
    -mmacosx-version-min=11.0 -c "$EXAMPLE_DIR/host.m" -o "$BUILD_DIR/host.o"
xcrun libtool -static -o "$BUILD_DIR/libodin_accesskit_example_host.a" "$BUILD_DIR/host.o"
"$ODIN" build examples/macos -collection:accesskit=. -target:"$ODIN_TARGET" \
    "-collection:accesskit_c=$(sh "$SCRIPT_DIR/bootstrap.sh" --library-directory)" \
    "-collection:accesskit_example_host=$BUILD_DIR" \
    -out:"$BUILD_DIR/macos-example" \
    "-extra-linker-flags:$ACCESSKIT_FLAGS"
exec "$BUILD_DIR/macos-example" "$@"
