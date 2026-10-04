// What every C++ card and shard can use without an include of its own (ADR-0046): the standard containers and
// algorithms, and the battle as it stands when the program runs. The harness counts loops and calls through the two
// macros below; the build puts them into each card's code on the line they measure, so a card never writes them.
#pragma once

#include <algorithm>
#include <cmath>
#include <functional>
#include <map>
#include <numeric>
#include <optional>
#include <queue>
#include <set>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace rootward {
void loop(int line);
void call(const char* name);
}  // namespace rootward

#define ROOTWARD_LOOP() ::rootward::loop(__LINE__)
#define ROOTWARD_CALL(name) ::rootward::call(name)

// A foe as a program sees it: what it has left and what it is weak to.
struct Foe {
	std::string name;
	int hp = 0;
	int max = 0;
	int shield = 0;
	std::vector<std::string> weak;
	std::vector<std::string> resist;
};

// You, the Maintainer.
struct Me {
	int hp = 0;
	int max = 0;
	int block = 0;
	int mana = 0;
};

struct Battle {
	int turn = 1;
	Me me;
	std::vector<Foe> foes;                 // the living foes, front first
	std::vector<std::string> imports;      // a program run's imports in force (`import math` is "math")
	std::map<std::string, int> globals;    // a program run's globals (`global total`)
};
