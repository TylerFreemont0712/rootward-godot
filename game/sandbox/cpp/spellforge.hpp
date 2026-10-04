// What a Spellforge shard sees in C++ (ADR-0046): the bolts it is handed and the battle, read-only. A shard is one
// function, `Bolts name(Bolts bolts, const Battle& battle)`, that returns the bolts for the next shard.
//
//   Bolts fork(Bolts bolts, const Battle& battle) {
//     Bolts split;
//     for (const Bolt& bolt : bolts) { ... }
//     return split;
//   }
#pragma once

#include "common.hpp"

// One bolt of a spell. Its power can be fractional (Fork makes 60%). The other fields are optional: a bolt that never
// had one keeps not having it, so `bolt.ward.value_or(false)` reads it and `bolt.ward = true` sets it.
struct Bolt {
	double power = 0;
	std::string element = "none";
	std::optional<std::string> target;  // "front", "back", "all", "strongest" or "weakest"
	std::optional<bool> pierce;
	std::optional<bool> ward;
	std::optional<double> mult;
};

using Bolts = std::vector<Bolt>;
