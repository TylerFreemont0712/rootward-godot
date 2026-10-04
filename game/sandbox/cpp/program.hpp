// What a Shardrun program card sees in C++ (ADR-0046): the bolts it is handed and the battle, read-only. A card is one
// function, `Bolts name(Bolts bolts, const Battle& battle)`, that returns the volley for the next card.
//
//   Bolts amplify(Bolts bolts, const Battle& battle) {
//     for (Bolt& bolt : bolts) bolt.power += 3;
//     return bolts;
//   }
#pragma once

#include "common.hpp"

// One bolt of a volley. `foe` is the foe it flies at (an index into battle.foes); without one it flies at the front.
// A bolt with `block` set becomes your block instead of hitting anyone.
struct Bolt {
	int power = 0;
	std::string element = "none";
	std::optional<int> foe;
	bool block = false;
	bool stash = false;
	bool from_index = false;
	bool pivot = false;
};

using Bolts = std::vector<Bolt>;
