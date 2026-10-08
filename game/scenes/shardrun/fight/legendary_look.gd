class_name LegendaryLook
extends RefCounted
## The style tables of a legendary look (docs/LEGENDARY_LOOKS.md, "Styles by role and cast"): a constellation bolt's
## star count, spread, prism rule and tint, and a black-hole impact's features. Pure tables and static functions over a
## role, a card and a seed: no nodes, no SpellAnim, and no randomness of its own, so the same inputs give the same look.

## A prism bolt's white-hot core. It is not a key of `bolt_style`, which holds the contract's four keys; the volley
## reads it from here.
const PRISM_CORE := Color("#fff6e0")

## The signature cards. Their bolts hit five star points and are always prismatic.
const SIGNATURE_CARDS: Array[String] = ["radix-sort", "quickselect", "memo-ward"]

## How far a role's stars may stray from the line, as a fraction of its length. A role not listed takes DEFAULT_SPREAD.
const SPREAD_BY_ROLE: Dictionary[String, float] = {
	"strike": 0.24,
	"guard": 0.14,
	"source": 0.30,
	"shape": 0.22,
	"order": 0.12,
	"import": 0.26,
}
const DEFAULT_SPREAD := 0.20

## The tint a role's bolt takes. A bolt whose role has no tint takes its element's colour.
const TINT_BY_ROLE: Dictionary[String, Color] = {
	"strike": Color("#ff9a3c"),
	"guard": Color("#5ff2d0"),
	"source": Color("#9dff5c"),
	"shape": Color("#b98cff"),
	"order": Color("#6fd6ff"),
	"import": Color("#ffe066"),
}

## Every impact starts from these values. Its role, then its signature card, change some of them.
const BASE_IMPACT := {
	"bands": 6,
	"spin": 0.6,
	"tilt": 0.45,
	"jets": true,
	"lens": 0.6,
	"hue": 0.0,
	"photon_sides": 0,
	"arms": 0,
	"scanlines": false,
	"digits": 0,
	"split": false,
	"cells": false,
	"rings": 1,
}

## What a role changes about the impact.
const IMPACT_BY_ROLE: Dictionary[String, Dictionary] = {
	"strike": {"tilt": 0.6, "bands": 4, "lens": 0.9, "hue": 0.04},
	"guard": {"rings": 3, "jets": false, "bands": 3, "lens": 1.0, "hue": 0.5},
	"source": {"arms": 4, "bands": 8, "spin": 1.0, "jets": false, "lens": 0.4, "hue": 0.3},
	"shape": {"photon_sides": 6, "jets": false, "bands": 6, "lens": 0.5, "hue": 0.7},
	"order": {"scanlines": true, "bands": 12, "jets": false, "lens": 0.3, "hue": 0.55},
	"import": {"arms": 2, "rings": 2, "lens": 0.5, "hue": 0.15},
}

## What a signature card adds to the impact.
const IMPACT_BY_SIGNATURE: Dictionary[String, Dictionary] = {
	"radix-sort": {"digits": 10},
	"quickselect": {"split": true, "jets": true},
	"memo-ward": {"cells": true, "rings": 2},
}

## The golden-ratio step that spreads the index `k` across the bits before `unit` mixes it.
const STEP := 0x9e3779b9


## A hash of `seed` and `k`, in [0, 1). The same inputs always give the same value. `k` is first spread by an imul, so
## neighbouring k do not sit on neighbouring hash inputs; the splitmix finaliser then mixes every input bit into the
## output.
static func unit(seed: int, k: int) -> float:
	var mixed := (seed + Rng.imul(k & Rng.MASK, STEP)) & Rng.MASK
	return Rng.mix32(mixed) / Rng.TWO_32


## The seed of one bolt: a 31-bit hash of the cast's serial, the hit's index and the card id. Each bolt of a cast gets
## its own seed, so its own path; the same bolt has the same seed every time.
static func rider_seed(cast_serial: int, index: int, card: String) -> int:
	# LEARN: the FNV-1a of the joined text is finished by Rng.mix32. Plain FNV-1a's lowest bit is the parity of the input's
	# bytes, so consecutive bolts would alternate in any rule that reads that bit, and prism reads two bits. The
	# finaliser makes every output bit depend on every input bit, and the mask keeps the seed non-negative.
	return Rng.mix32(Rng.hash_string("%d:%d:%s" % [cast_serial, index, card])) & 0x7FFFFFFF


## Whether a card is a signature card. The empty card never is.
static func is_signature(card: String) -> bool:
	return SIGNATURE_CARDS.has(card)


## How far a role's stars may stray from the line, as a fraction of its length.
static func spread_of(role: String) -> float:
	if SPREAD_BY_ROLE.has(role):
		return SPREAD_BY_ROLE[role]
	return DEFAULT_SPREAD


## The style of a constellation bolt. `role` and `card` are "" when there is none; `seed` is the bolt's rider seed (see
## `rider_seed`); `element_colour` is used when the role gives no tint. Keys: `count` (the star points it hits: 5 for a
## signature card, else 4 or 5 by bit 2 of the seed), `spread` (see `spread_of`), `prism` (coloured along its length:
## every signature bolt, and one bolt in four), and `colour` (the role's tint, else `element_colour`).
static func bolt_style(role: String, card: String, seed: int, element_colour: Color) -> Dictionary:
	var signature := is_signature(card)
	# LEARN: the count reads bit 2 of the seed. The prism rule reads bits 0 and 1 (seed % 4 == 0), so on a prism
	# bolt both are 0, and a count that read either bit would give every prism bolt four stars. A right shift moves
	# bit 2 down to bit 0 for any sign, so `& 1` is right for a negative seed too.
	var prism := signature or posmod(seed, 4) == 0
	return {
		"count": 5 if signature else 4 + ((seed >> 2) & 1),
		"spread": spread_of(role),
		"prism": prism,
		"colour": TINT_BY_ROLE[role] if TINT_BY_ROLE.has(role) else element_colour,
	}


## The features of a black-hole impact, for a hit by a bolt of `role` cast by `card` ("" for none). A fresh Dictionary
## each call, so a caller may change it without changing the tables.
static func impact_style(role: String, card: String) -> Dictionary:
	# LEARN: merge() keeps the old value unless told to overwrite, so each change is merged with `true`. The card merges
	# last, so a signature card wins a clash with its role: quickselect keeps its jets on under a guard, which turns them
	# off.
	var style: Dictionary = BASE_IMPACT.duplicate()
	if IMPACT_BY_ROLE.has(role):
		style.merge(IMPACT_BY_ROLE[role], true)
	if IMPACT_BY_SIGNATURE.has(card):
		style.merge(IMPACT_BY_SIGNATURE[card], true)
	return style
