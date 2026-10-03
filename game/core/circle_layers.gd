class_name CircleLayers
extends RefCounted
## The rules of the stacking magic circle (ADR-0039): which circle a spell of N shards writes, and which layer each
## shard adds to it. Pure data in, plain Dictionaries out, so the same spell always draws the same circle:
##
##   shards      tier  (the circle's size, its stack of smaller circles in front, its sound)
##   1 or 2      0     a simple circle
##   3 or 4      1
##   5           2
##   6           3     the grand circle
##
## Each shard of the spell adds one layer, in the order the shards are played, of a kind chosen from the shard itself
## (its role picks a family of looks, its id picks one from the family). The drawing is MagicCircle's and
## CircleLayerArt's; nothing here knows how a layer looks, only which one it is.

## The most shards each tier holds: a spell never draws more layers than its tier has room for.
const TIER_SHARDS: Array[int] = [2, 4, 5, 6]
## A layer's arrival, as shares of the circle's form time: the first one lands at `FIRST`, the rest follow at `STEP`
## apart (closer together the more there are), and each draws itself in over `DRAW`. The last is whole before the
## circle is complete (1.0), whatever the count, so the strike still lands on the finished circle.
const FIRST := 0.1
const STEP_MOST := 0.2
const STEPS_TOTAL := 0.6
const DRAW := 0.26
## What a layer can look like (CircleLayerArt draws each).
const KINDS: Array[String] = [
	"runes",
	"star",
	"lattice",
	"spiral",
	"satellites",
	"brackets",
	"spokes",
	"wave",
	"pulses",
	"nested",
	"dashes",
	"rosette",
]
## Per card role, the looks that suit it: a source fans out, a shape weaves or ripples, an order turns in lockstep, a
## strike is ruled and pointed, a guard rings round, an import carries the code itself. A card without a role (a
## Spellforge shard) chooses from all of them.
const FAMILIES := {
	"source": ["spokes", "rosette", "satellites", "spiral"],
	"shape": ["lattice", "wave", "nested", "dashes"],
	"order": ["brackets", "dashes", "runes", "wave"],
	"strike": ["star", "spokes", "spiral", "nested"],
	"guard": ["pulses", "nested", "lattice", "brackets"],
	"import": ["runes", "satellites", "rosette", "pulses"],
}
## Six cards of different roles, for a circle shown with no spell behind it (a carousel card, the fitting room).
const DEMO_CARDS: Array[Dictionary] = [
	{"id": "fork", "name": "Fork", "role": "source"},
	{"id": "bubble-sort", "name": "Bubble Sort", "role": "order"},
	{"id": "binary-execute", "name": "Binary Execute", "role": "strike"},
	{"id": "exhaustive-ward", "name": "Exhaustive Ward", "role": "guard"},
	{"id": "kadane", "name": "Kadane", "role": "shape"},
	{"id": "import-math", "name": "import math", "role": "import"},
]


## The circle's tier (0..3) for a spell of `count` shards.
static func tier_for(count: int) -> int:
	if count <= 2:
		return 0
	if count <= 4:
		return 1
	if count == 5:
		return 2
	return 3


## The most layers a circle of `tier` holds.
static func capacity(tier: int) -> int:
	return TIER_SHARDS[clampi(tier, 0, TIER_SHARDS.size() - 1)]


## When layer `index` of `count` lands, as a share of the circle's form time.
static func start_share(index: int, count: int) -> float:
	if count <= 1:
		return FIRST + 0.1
	return FIRST + minf(STEP_MOST, STEPS_TOTAL / float(count - 1)) * float(index)


## A card as its code calls it: `Knapsack Strike` is `knapsackStrike()`.
static func call_name(card: Dictionary) -> String:
	var words := String(card.get("name", "")).split(" ", false)
	if words.is_empty():
		return ""
	var called := words[0].to_lower()
	for word in words.slice(1):
		called += word.capitalize().replace(" ", "")
	return called + "()"


## The names of a spell's cards as the runes of its circle, `knapsackStrike()  charge()  `; "" for no cards.
static func words(cards: Array) -> String:
	var names: PackedStringArray = []
	for card: Dictionary in cards:
		var called := call_name(card)
		if called != "":
			names.append(called)
	return "  ".join(names) + "  " if not names.is_empty() else ""


## A card's own number: the same card is the same number every run (FNV-1a of its id).
static func seed_of(card: Dictionary) -> int:
	var id := String(card.get("id", ""))
	return Rng.hash_string(id if id != "" else String(card.get("name", "")))


## The look a card would take on its own: its role's family, the member its id picks.
static func kind_of(card: Dictionary) -> String:
	var family: Array = FAMILIES.get(String(card.get("role", "")), KINDS)
	return String(family[seed_of(card) % family.size()])


## The layers a spell's cards add, in order: [{id, kind, word, seed, dir, slot, count}], at most one per card and never
## more than the spell's tier holds. Two different cards never share a look (the second is nudged along its family,
## then along all the looks); the same card twice keeps its look. Neighbouring layers always turn against each other.
static func plan(cards: Array) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	var count := mini(cards.size(), capacity(tier_for(cards.size())))
	var kinds := {}
	var taken := {}
	for slot in count:
		var card: Dictionary = cards[slot]
		var id := String(card.get("id", ""))
		var kind := ""
		if kinds.has(id):
			kind = String(kinds[id])
		else:
			kind = _free_kind(card, taken)
			kinds[id] = kind
			taken[kind] = true
		var seed := seed_of(card)
		(
			layers
			. append(
				{
					"id": id,
					"kind": kind,
					"word": call_name(card),
					"seed": seed,
					"dir": 1 if slot % 2 == 0 else -1,
					"slot": slot,
					"count": count,
				}
			)
		)
	return layers


## The layers of the demonstration spell with as many shards as `tier` holds.
static func demo_plan(tier: int) -> Array[Dictionary]:
	return plan(demo_cards(capacity(tier)))


## `count` of the demonstration cards (at most six).
static func demo_cards(count: int) -> Array[Dictionary]:
	return DEMO_CARDS.slice(0, clampi(count, 0, DEMO_CARDS.size()))


static func _free_kind(card: Dictionary, taken: Dictionary) -> String:
	var natural := kind_of(card)
	if not taken.has(natural):
		return natural
	var family: Array = FAMILIES.get(String(card.get("role", "")), KINDS)
	var from := family.find(natural)
	for step in family.size():
		var kind := String(family[(from + step) % family.size()])
		if not taken.has(kind):
			return kind
	for kind in KINDS:
		if not taken.has(kind):
			return kind
	return natural
