#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
ODIN=${ODIN:-odin}
CC=${CC:-cc}
AR=${AR:-ar}
CACHE_ROOT=${ACCESSKIT_CACHE_ROOT:-$ROOT/.deps/accesskit}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --odin) ODIN=$2; shift 2 ;;
        --cache-root) CACHE_ROOT=$2; shift 2 ;;
        *) echo 'Usage: check.sh [--odin PATH] [--cache-root DIRECTORY]' >&2; exit 2 ;;
    esac
done
ACCESSKIT_CACHE_ROOT=$CACHE_ROOT
export ACCESSKIT_CACHE_ROOT ODIN
cd "$ROOT"
FLAGS=$(sh tools/bootstrap.sh --cache-root "$CACHE_ROOT")
LIBDIR=$(sh tools/bootstrap.sh --cache-root "$CACHE_ROOT" --library-directory)
python3 tools/generate_constants.py --check
mkdir -p out
HEADER="$CACHE_ROOT/accesskit-c-0.23.1/include"
"$CC" -std=c11 -Wall -Wextra -Werror -Wpedantic -I "$HEADER" tests/abi_contract/accesskit_abi_contract.c -o out/contract
out/contract
"$CC" -std=c11 -Wall -Wextra -Werror -Wpedantic -I "$HEADER" -c tests/abi_contract/accesskit_abi_round_trip.c -o out/round_trip.o
"$AR" rcs out/libodin_accesskit_abi_probe.a out/round_trip.o
"$ODIN" check accesskit -no-entry-point "-collection:accesskit_c=$LIBDIR"
"$ODIN" test accesskit "-collection:accesskit_c=$LIBDIR" "-extra-linker-flags:$FLAGS -L\"$ROOT/out\"" -out:out/accesskit_tests
EXTERNAL=$(mktemp -d "${TMPDIR:-/tmp}/odin-accesskit-consumer.XXXXXX")
trap 'rm -rf "$EXTERNAL"' EXIT HUP INT TERM
cp examples/minimal_tree/main.odin "$EXTERNAL/main.odin"
(cd "$EXTERNAL"; "$ODIN" build . "-collection:accesskit=$ROOT" "-collection:accesskit_c=$LIBDIR" "-extra-linker-flags:$FLAGS" "-out:$EXTERNAL/consumer"; "$EXTERNAL/consumer")
if [ "$(uname -s)" = Darwin ]; then
    sh tools/run_macos.sh --smoke
fi
