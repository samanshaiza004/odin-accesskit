#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
MODE=linker
while [ "$#" -gt 0 ]; do
    case "$1" in
        --cache-root) ACCESSKIT_CACHE_ROOT=$2; shift 2 ;;
        --library-directory) MODE=directory; shift ;;
        *) echo 'Usage: bootstrap.sh [--cache-root DIRECTORY] [--library-directory]' >&2; exit 2 ;;
    esac
done

# Download and verify the pinned upstream binary distribution.
accesskit_linker_flags() {
	version=0.23.1
	url="https://github.com/AccessKit/accesskit-c/releases/download/$version/accesskit-c-$version.zip"
	sha='35b7ca8a6f1e038b5da35e1e9e5a0adaed9bfcf21e1496d29598fbbadcc7043f'
	cache_root="${ACCESSKIT_CACHE_ROOT:-$REPO_ROOT/.deps/accesskit}"
	archive="$cache_root/accesskit-c-$version.zip"
	distribution="$cache_root/accesskit-c-$version"
	case "$(uname -s)" in
		Linux)
			platform=linux
			case "$(uname -m)" in
				x86_64|amd64) arch=x86_64 ;;
				*) echo "AccessKit $version Linux static library does not support architecture '$(uname -m)'." >&2; return 1 ;;
			esac
			;;
		Darwin)
			platform=macos
			case "$(uname -m)" in
				arm64|aarch64) arch=arm64 ;;
				x86_64) arch=x86_64 ;;
				*) echo "AccessKit $version macOS static library does not support architecture '$(uname -m)'." >&2; return 1 ;;
			esac
			;;
		*) echo "AccessKit $version static bootstrap does not support this OS in this helper (got $(uname -s))." >&2; return 1 ;;
	esac
	mkdir -p "$cache_root"
	if [ ! -f "$archive" ]; then
		command -v curl >/dev/null 2>&1 || { echo 'AccessKit bootstrap requires curl.' >&2; return 127; }
		curl --fail --location --silent --show-error "$url" -o "$archive" || {
			echo "AccessKit $version download failed: $url" >&2
			return 1
		}
	fi
	if command -v shasum >/dev/null 2>&1; then
		actual_sha=$(shasum -a 256 "$archive" | awk '{print $1}') || return 1
	elif command -v sha256sum >/dev/null 2>&1; then
		actual_sha=$(sha256sum "$archive" | awk '{print $1}') || return 1
	else
		echo 'AccessKit bootstrap requires shasum or sha256sum.' >&2
		return 127
	fi
	if [ "$actual_sha" != "$sha" ]; then
		echo "AccessKit $version archive SHA-256 mismatch. Expected $sha; got $actual_sha. Cached archive: $archive" >&2
		return 1
	fi

	relative_library="lib/$platform/$arch/static/libaccesskit.a"
	library="$distribution/$relative_library"
	if [ ! -f "$library" ]; then
		if [ -d "$distribution" ]; then
			echo "AccessKit $version cache exists but required library is missing: $library. Remove only that versioned cache directory and retry." >&2
			return 1
		fi
		command -v unzip >/dev/null 2>&1 || { echo 'AccessKit bootstrap requires unzip.' >&2; return 127; }
		stage=$(mktemp -d "$cache_root/.extract.XXXXXX") || return 1
		if ! unzip -q "$archive" -d "$stage"; then
			rm -r "$stage"
			echo "AccessKit $version archive extraction failed: $archive" >&2
			return 1
		fi
		staged_distribution="$stage/accesskit-c-$version"
		if [ ! -f "$staged_distribution/$relative_library" ]; then
			rm -r "$stage"
			echo "Verified AccessKit archive does not contain expected $platform $arch static library: $relative_library" >&2
			return 1
		fi
		mv "$staged_distribution" "$distribution"
		rm -r "$stage"
	fi
	library_directory="$distribution/lib/$platform/$arch/static"
    if [ "$MODE" = directory ]; then
        printf '%s\n' "$library_directory"
    elif [ "$platform" = linux ]; then
        printf '%s\n' '-ldl -lpthread -lm'
    else
        printf '%s\n' '-framework AppKit -framework Foundation -framework CoreFoundation -lobjc -lc++'
    fi
}

accesskit_linker_flags
