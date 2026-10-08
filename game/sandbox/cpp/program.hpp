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
	bool idle = false;  // A scheduler-created spacer, so Handoff Ward need not guess from power or element.
	// The program tag (docs/LEGENDARY_LOOKS.md): the card that returned this bolt last, and that card's role. The harness
	// sets both after each card, whatever the card wrote; a bolt no card returned has neither.
	// LEARN: an unset std::optional means "no tag", which a plain "" cannot say: a card with no role still stamps "".
	std::optional<std::string> card;
	std::optional<std::string> role;
};

using Bolts = std::vector<Bolt>;
