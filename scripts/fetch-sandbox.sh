#!/usr/bin/env bash
# Installs the sandbox runtime into game/sandbox/runtime/ (ignored by git and by Godot's importer):
#   bin/wasmtime            the Wasm engine the game runs player code under (ADR-0002)
#   python/python.cwasm     CPython 3.14 for WASI, precompiled; python/lib/ its standard library, made read-only
#   js/qjs.cwasm            QuickJS-ng for WASI, precompiled
# Every download is pinned by version and SHA-256. Safe to re-run; it only redoes what is missing or stale.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
runtime="$root/game/sandbox/runtime"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/rootward/sandbox"
mkdir -p "$cache" "$runtime"

WASMTIME_VERSION="v49.0.0"
WASMTIME_SHA="a956c279ac6e80109369a285db30fc46f68239fa1bbeb03ccfa8e913bbca85fc"
QJS_VERSION="v0.17.0"
QJS_SHA="42a732a676ec2d93488c19411e0fad283bf72658fdad746f089914b523c783b1"
PYTHON_VERSION="3.14.7"
PYTHON_SHA="2e064d3fb8172471d39d741348efa722349c40b96301f69968dff714999c584b"

fetch() { # url sha file
	local url="$1" sha="$2" file="$cache/$3"
	if [ ! -f "$file" ] || ! echo "$sha  $file" | sha256sum -c --quiet - 2>/dev/null; then
		echo "downloading $3"
		curl -fsSL -o "$file.part" "$url"
		echo "$sha  $file.part" | sha256sum -c --quiet - || { echo "checksum mismatch for $3" >&2; rm -f "$file.part"; exit 1; }
		mv "$file.part" "$file"
	fi
}

fetch "https://github.com/bytecodealliance/wasmtime/releases/download/$WASMTIME_VERSION/wasmtime-$WASMTIME_VERSION-x86_64-linux.tar.xz" \
	"$WASMTIME_SHA" "wasmtime-$WASMTIME_VERSION.tar.xz"
fetch "https://github.com/quickjs-ng/quickjs/releases/download/$QJS_VERSION/qjs-wasi.wasm" "$QJS_SHA" "qjs-wasi-$QJS_VERSION.wasm"
fetch "https://github.com/brettcannon/cpython-wasi-build/releases/download/v$PYTHON_VERSION/python-$PYTHON_VERSION-wasi_sdk-24.zip" \
	"$PYTHON_SHA" "python-$PYTHON_VERSION.zip"

stamp="$runtime/VERSIONS"
want="wasmtime $WASMTIME_VERSION, quickjs-ng $QJS_VERSION, cpython $PYTHON_VERSION"
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$want" ]; then
	echo "sandbox runtime up to date ($want)"
	exit 0
fi

chmod -R u+w "$runtime" 2>/dev/null || true
rm -rf "$runtime"
mkdir -p "$runtime/bin" "$runtime/python" "$runtime/js"
touch "$runtime/.gdignore"
tar -xJf "$cache/wasmtime-$WASMTIME_VERSION.tar.xz" -C "$cache"
cp "$cache/wasmtime-$WASMTIME_VERSION-x86_64-linux/wasmtime" "$runtime/bin/wasmtime"
unzip -qo "$cache/python-$PYTHON_VERSION.zip" -d "$runtime/python"
# LEARN: precompiling once turns every run's startup from compiling 30 MB of Wasm (~0.8 s) into mapping a file
# (~0.03 s). The .cwasm is tied to this wasmtime version and CPU, which is why it is built here and never committed.
# Epoch interruption must be compiled in for `-W timeout` to be able to stop an endless loop.
"$runtime/bin/wasmtime" compile -W epoch-interruption=y "$runtime/python/python.wasm" -o "$runtime/python/python.cwasm"
"$runtime/bin/wasmtime" compile -W epoch-interruption=y "$cache/qjs-wasi-$QJS_VERSION.wasm" -o "$runtime/js/qjs.cwasm"
rm "$runtime/python/python.wasm"
# The standard library ships as source only, so every import would compile it again: `import traceback` alone cost
# about 280 ms per run. Compiling it to bytecode once here brings a run's startup to about 60 ms. (A few test modules
# that need multiprocessing fail to compile; nothing a program in the sandbox can import needs them.)
"$runtime/bin/wasmtime" run --allow-precompiled -W timeout=900s --dir "$runtime/python/lib::/lib" --env PYTHONHOME=/ \
	"$runtime/python/python.cwasm" -m compileall -q /lib/python3.14 >/dev/null 2>&1 || true
# The guest sees the standard library as a directory it could write to (wasmtime has no read-only mount), so the host
# files themselves are made read-only: WASI has no chmod, so no program can undo this.
chmod -R a-w "$runtime/python/lib"
echo "$want" > "$stamp"
echo "installed $want into $runtime"
