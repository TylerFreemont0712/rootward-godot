#!/usr/bin/env bash
# Builds the C++ modules the sandbox runs (ADR-0046): every program card and Spellforge shard with C++ code, and every
# mutant the Mutator can make of a card, compiled ahead of time with wasi-sdk into
#   game/sandbox/runtime/cpp/program.cwasm      program cards and their mutants
#   game/sandbox/runtime/cpp/spellforge.cwasm   Spellforge's shards
# Re-run it after changing any card's C++ (validation warns when the build is stale). scripts/fetch-sandbox.sh
# installs wasi-sdk and runs this once. Objects are cached by their source, so a rebuild compiles only what changed.
# ROOTWARD_CPP_OUT builds somewhere else than the game's runtime, and ROOTWARD_CPP_ONLY (ids, comma separated) builds
# only those cards: scripts/try-cpp.sh uses both, so ports can be checked side by side without touching the game's.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
runtime="$root/game/sandbox/runtime"
out="${ROOTWARD_CPP_OUT:-$runtime/cpp}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/rootward/sandbox"
sdk="${WASI_SDK:-$cache/wasi-sdk-34.0-x86_64-linux}"
build="$out/build"
objects="$cache/cpp-objects"
wasmtime="$runtime/bin/wasmtime"
[ -x "$sdk/bin/clang++" ] || { echo "no wasi-sdk at $sdk (run scripts/fetch-sandbox.sh)" >&2; exit 1; }
[ -x "$wasmtime" ] || { echo "no wasmtime (run scripts/fetch-sandbox.sh)" >&2; exit 1; }
mkdir -p "$build" "$objects"

rm -f "$build"/*/units.txt
"$GODOT" --headless --path "$root/game" -s res://tools/build_cpp.gd -- "$build" < /dev/null > "$build/generate.log" 2>&1 || true
grep -E "units|ERROR" "$build/generate.log" || true
[ -f "$build/program/units.txt" ] && [ -f "$build/spellforge/units.txt" ] || { echo "generating the sources failed" >&2; exit 1; }

# LEARN: -fwasm-exceptions with the new encoding (-wasm-use-legacy-eh=false) is what wasmtime's `-W exceptions` runs;
# the eh sysroot's libc++ is built for it, and libunwind supplies _Unwind_RaiseException. Wasm's stack for C++
# recursion lives in linear memory and defaults to 64 KB, so it is raised to 8 MB to allow deep recursion.
common=(--target=wasm32-wasip1 -std=c++20 -O2 -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false
	-I"$root/game/sandbox/cpp" -Wall -Wno-unused-parameter -Wno-unused-variable -Wno-sign-compare)

compile_module() { # module extra-flag
	local module="$1" extra="$2" dir="$build/$1"
	local flags=("${common[@]}")
	[ -n "$extra" ] && flags+=("$extra")
	export SDK="$sdk" OBJECTS="$objects" DIR="$dir" FLAGS="${flags[*]}" HEADERS="$root/game/sandbox/cpp"
	# One unit a line: compile it unless its object is cached; print "FAILED <unit>" when it does not compile.
	xargs -P "$(nproc)" -I{} bash -c '
		unit=$(echo "{}" | cut -d" " -f1)
		key=$( (cat "$DIR/$unit"; echo "$FLAGS"; cat "$HEADERS/"*.hpp) | sha256sum | cut -c1-32 )
		obj="$OBJECTS/$key.o"
		if [ ! -f "$obj" ]; then
			if ! "$SDK/bin/clang++" $FLAGS -c "$DIR/$unit" -o "$obj.part" 2> "$DIR/$unit.log"; then
				echo "FAILED $unit"; exit 0
			fi
			mv "$obj.part" "$obj"
		fi
		echo "$obj" > "$DIR/$unit.obj"
	' < "$dir/units.txt" > "$dir/failed.txt"
	local broken=0
	while read -r _ unit; do
		[ -z "$unit" ] && continue
		local name="${unit%.cpp}" id
		id=$(grep "^$unit " "$dir/units.txt" | cut -d" " -f2)
		if [[ "$id" == *"~"* ]]; then
			# A mutant that does not compile is never drawn: it leaves the registry.
			sed -i "/namespace $name {/d; /{\"$id\", /d" "$dir/registry.cpp"
			local count
			count=$(grep -c '^	{"' "$dir/registry.cpp" || true)
			sed -i "s/^const int rootward::CARD_COUNT = .*/const int rootward::CARD_COUNT = $count;/" "$dir/registry.cpp"
		else
			echo "error: $unit does not compile:" >&2
			sed 's/^/  /' "$dir/$unit.log" >&2
			broken=1
		fi
	done < "$dir/failed.txt"
	[ "$broken" = 0 ] || exit 1
	"$sdk/bin/clang++" "${flags[@]}" -c "$root/game/sandbox/cpp/harness.cpp" -o "$dir/harness.o"
	"$sdk/bin/clang++" "${flags[@]}" -c "$dir/registry.cpp" -o "$dir/registry.o"
	local linked=("$dir/harness.o" "$dir/registry.o")
	while read -r unit _; do
		[ -f "$dir/$unit.obj" ] && linked+=("$(cat "$dir/$unit.obj")")
	done < "$dir/units.txt"
	"$sdk/bin/clang++" "${flags[@]}" -Wno-unused-command-line-argument "${linked[@]}" -o "$dir/$module.wasm" -lunwind \
		-Wl,-z,stack-size=8388608
	"$wasmtime" compile -W epoch-interruption=y,exceptions=y "$dir/$module.wasm" -o "$out/$module.cwasm"
	cp "$dir/STAMP" "$out/$module.stamp"
	echo "$module: $(grep -c '^	{"' "$dir/registry.cpp") functions, $(wc -l < "$dir/failed.txt") mutants left out"
}

compile_module program ""
compile_module spellforge "-DROOTWARD_SPELLFORGE"
