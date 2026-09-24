class_name Rng
extends RefCounted
## Seeded randomness. The rules never call randf(): every random choice is a pure function of the run's seed, so the
## same seed replays the same run, and tests can pin outcomes.
##
## LEARN: two styles live here. `random_for(seed, stream, index)` is counter-based: the n-th draw of a stream is
## computed directly, with no state to store, which suits one-off choices ("which move after cast 3"). `Rng.create`
## is a stateful generator (sfc32) for code that draws many numbers in a row, such as laying out a map. Named streams
## keep subsystems apart: adding a draw to loot never changes which move a foe picks.
##
## LEARN: GDScript ints are 64-bit and signed, while these algorithms are defined on unsigned 32-bit words. Every value
## here is kept in [0, 2^32) by masking with MASK after each step, and multiplication goes through `imul`, which splits
## one factor in halves so no product exceeds 2^48 (a plain 32x32 product could overflow 63 bits).

const MASK := 0xFFFFFFFF
const TWO_32 := 4294967296.0
const FNV_OFFSET := 0x811c9dc5
const FNV_PRIME := 0x01000193

var _a: int
var _b: int
var _c: int
var _d: int


## FNV-1a over the string's UTF-16 code units (what JavaScript's charCodeAt reads), so seeds hash as they always did.
static func hash_string(text: String) -> int:
	return _fnv(FNV_OFFSET, text)


static func _fnv(start: int, text: String) -> int:
	var h := start
	var units := text.to_utf16_buffer()
	for i in range(0, units.size(), 2):
		h ^= units[i] | (units[i + 1] << 8)
		h = imul(h, FNV_PRIME)
	return h


## (a * b) mod 2^32, for a and b in [0, 2^32).
static func imul(a: int, b: int) -> int:
	var low := a * (b & 0xFFFF)
	var high := ((a * (b >> 16)) & 0xFFFF) << 16
	return (low + high) & MASK


## The splitmix32 finalizer: nearby inputs give unrelated outputs.
static func mix32(value: int) -> int:
	var z := (value + 0x9e3779b9) & MASK
	z = imul(z ^ (z >> 16), 0x85ebca6b)
	z = imul(z ^ (z >> 13), 0xc2b2ae35)
	return (z ^ (z >> 16)) & MASK


## The `index`-th number in [0, 1) of a named stream of a seed.
static func random_for(seed: String, stream: String, index: int) -> float:
	# The TypeScript engine hashed `${seed}\0${stream}`: a NUL separator, which no seed or stream name contains. A Godot
	# String cannot hold a NUL, so the three parts are hashed in sequence, which is the same FNV-1a computation.
	var h := _fnv(FNV_OFFSET, seed)
	h = imul(h, FNV_PRIME)  # the NUL unit: h ^= 0 changes nothing, then one multiply
	h = _fnv(h, stream)
	var base := mix32(h)
	return mix32((base + index) & MASK) / TWO_32


## A seeded generator of numbers in [0, 1) (sfc32). Call `next()` for each draw.
static func create(seed: String, stream: String = "default") -> Rng:
	var rng := Rng.new()
	rng._a = mix32(hash_string(seed))
	rng._b = mix32(hash_string(stream))
	rng._c = mix32(rng._a ^ rng._b)
	rng._d = 1
	# The first outputs of a freshly seeded sfc32 are weakly mixed; discard a few.
	for i in 12:
		rng.next()
	return rng


func next() -> float:
	var t := (((_a + _b) & MASK) + _d) & MASK
	_d = (_d + 1) & MASK
	_a = _b ^ (_b >> 9)
	_b = (_c + (_c << 3)) & MASK
	_c = ((_c << 21) & MASK) | (_c >> 11)
	_c = (_c + t) & MASK
	return t / TWO_32


## A shuffled copy of `items` (Fisher-Yates), drawing from this generator.
func shuffled(items: Array) -> Array:
	var result := items.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := floori(next() * (i + 1))
		var swap: Variant = result[i]
		result[i] = result[j]
		result[j] = swap
	return result


## The index of an item picked with probability proportional to its weight, using `roll` in [0, 1); -1 when every
## weight is zero or less.
static func pick_weighted(weights: Array[float], roll: float) -> int:
	var total := 0.0
	for weight in weights:
		total += maxf(0.0, weight)
	if total <= 0.0:
		return -1
	var remaining := roll * total
	for i in weights.size():
		remaining -= maxf(0.0, weights[i])
		if remaining < 0.0:
			return i
	return weights.size() - 1
