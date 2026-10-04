// The table the build generates (tools/build_cpp.gd): every card's id and its function, after the mode's header.
#pragma once

namespace rootward {

using Card = Bolts (*)(Bolts, const Battle&);

struct Entry {
	const char* id;
	Card run;
};

extern const Entry CARDS[];
extern const int CARD_COUNT;

}  // namespace rootward
