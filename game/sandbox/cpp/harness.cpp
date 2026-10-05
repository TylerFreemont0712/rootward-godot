// The Shardrun spell harness for C++ (ADR-0046), the twin of spell_harness.py and spell_harness.js: standard input is
// one JSON object (the shards, the spells as lists of indexes into them, the starting bolts, the battle, the limits),
// and each spell's result is printed as one line starting with the job's marker. SpellHarness (spell_harness.gd)
// builds the input and reads the lines back.
//
// The other two languages load each shard's source at run time. C++ is compiled ahead of time instead
// (scripts/build-cpp.sh): every card, and every mutant the Mutator can make of one, is a function in this module,
// found by id in CARDS. No turn waits for a compiler.
#include <cstdio>
#include <cmath>
#include <cxxabi.h>
#include <fstream>
#include <iostream>
#include <iterator>
#include <typeinfo>

#ifdef ROOTWARD_SPELLFORGE
#include "spellforge.hpp"
#else
#include "program.hpp"
#endif
#include "json.hpp"
#include "registry.hpp"

namespace rootward {

using json::Value;

// What the card running now has done: each loop's rounds by line, and how often its own function was entered.
static std::map<int, int> loops;
static int calls = 0;
static std::string running;

void loop(int line) { loops[line]++; }
void call(const char* name) {
	if (running == name) calls++;
}

static Card find(const std::string& id) {
	for (int i = 0; i < CARD_COUNT; i++)
		if (id == CARDS[i].id) return CARDS[i].run;
	return nullptr;
}

// --- JSON to and from the cards' types --------------------------------------------------------------------------

static std::vector<std::string> strings(const Value& v) {
	std::vector<std::string> out;
	for (const auto& item : v.list()) out.push_back(item.str());
	return out;
}

static Battle battle_of(const Value& v) {
	Battle battle;
	battle.turn = int(v["turn"].num(1));
	const Value& me = v["me"];
	battle.me = {int(me["hp"].num()), int(me["max"].num()), int(me["block"].num()), int(me["mana"].num())};
	for (const auto& f : v["foes"].list()) {
		Foe foe;
		foe.name = f["name"].str();
		foe.hp = int(f["hp"].num());
		foe.max = int(f["max"].num());
		foe.shield = int(f["shield"].num());
		foe.weak = strings(f["weak"]);
		foe.resist = strings(f["resist"]);
#ifndef ROOTWARD_SPELLFORGE
		foe.hits = int(f["hits"].num());
		const Value& intent = f["intent"];
		foe.intent = {intent["kind"].str(), int(intent["damage"].num()),
		              int(intent["hits"].num(1)), int(intent["tempo"].num())};
#endif
		battle.foes.push_back(foe);
	}
	battle.imports = strings(v["imports"]);
	if (v["globals"].is_object())
		for (const auto& [name, value] : *v["globals"].fields) battle.globals[name] = int(value.num());
#ifndef ROOTWARD_SPELLFORGE
	for (const auto& bolt : v["index"].list())
		battle.index.push_back({int(bolt["power"].num()), bolt["element"].str("none")});
	for (const auto& row : v["dp"].list()) battle.dp.push_back(int(row.num()));
	for (const auto& power : v["last_volley"].list()) battle.last_volley.push_back(int(power.num()));
#endif
	return battle;
}

static Bolt bolt_of(const Value& v) {
	Bolt bolt;
	bolt.power = decltype(bolt.power)(v["power"].num());
	bolt.element = v["element"].str("none");
#ifdef ROOTWARD_SPELLFORGE
	if (v.has("target")) bolt.target = v["target"].str();
	if (v.has("pierce")) bolt.pierce = v["pierce"].truthy();
	if (v.has("ward")) bolt.ward = v["ward"].truthy();
	if (v.has("mult")) bolt.mult = v["mult"].num();
#else
	if (v.has("foe")) bolt.foe = int(v["foe"].num());
	bolt.block = v["block"].truthy();
	bolt.stash = v["stash"].truthy();
	bolt.from_index = v["from_index"].truthy();
	bolt.pivot = v["pivot"].truthy();
	bolt.idle = v["idle"].truthy();
#endif
	return bolt;
}

static Value value_of(const Bolt& bolt) {
	Value v = Value::object();
	v.set("power", Value::of(double(bolt.power)));
	v.set("element", Value::of(bolt.element));
#ifdef ROOTWARD_SPELLFORGE
	if (bolt.target) v.set("target", Value::of(*bolt.target));
	if (bolt.pierce) v.set("pierce", Value::of(*bolt.pierce));
	if (bolt.ward) v.set("ward", Value::of(*bolt.ward));
	if (bolt.mult) v.set("mult", Value::of(*bolt.mult));
#else
	if (bolt.foe) v.set("foe", Value::of(double(*bolt.foe)));
	if (bolt.block) v.set("block", Value::of(true));
	if (bolt.stash) v.set("stash", Value::of(true));
	if (bolt.from_index) v.set("from_index", Value::of(true));
	if (bolt.pivot) v.set("pivot", Value::of(true));
	if (bolt.idle) v.set("idle", Value::of(true));
#endif
	return v;
}

static Bolts bolts_of(const Value& v) {
	Bolts out;
	for (const auto& item : v.list()) out.push_back(bolt_of(item));
	return out;
}

static Value value_of(const Bolts& bolts, size_t limit) {
	Value v = Value::array();
	for (size_t i = 0; i < bolts.size() && i < limit; i++) v.push(value_of(bolts[i]));
	return v;
}

// --- Running spells ---------------------------------------------------------------------------------------------

struct Shard {
	std::string id;
	std::string name;
	std::string role;
	Card run = nullptr;
	Value metadata;
};

struct Failure {
	std::string shard;
	std::string error;
};

// "std::out_of_range: vector", the way a C++ programmer would read it.
static std::string describe(const std::exception& error) {
	int status = 0;
	char* readable = abi::__cxa_demangle(typeid(error).name(), nullptr, nullptr, &status);
	std::string type = status == 0 && readable ? readable : typeid(error).name();
	std::free(readable);
	return type + ": " + error.what();
}

static Bolts call_card(const Shard& shard, const Bolts& bolts, const Battle& battle, size_t limit,
                       size_t* returned = nullptr) {
	if (!shard.run) throw Failure{shard.id, "there is no C++ code for " + shard.id + " (run scripts/build-cpp.sh)"};
	loops.clear();
	calls = 0;
	running = shard.name;
	try {
		Bolts result = shard.run(bolts, battle);
		if (returned) *returned = result.size();
		if (result.size() > limit) result.resize(limit);
		return result;
	} catch (const Failure&) {
		throw;
	} catch (const std::exception& error) {
		throw Failure{shard.id, describe(error)};
	} catch (...) {
		throw Failure{shard.id, "it threw something that is not a std::exception"};
	}
}

struct Job {
	std::vector<Shard> shards;
	std::vector<std::tuple<std::string, std::string, int>> hooks;  // when, role, shard
	size_t limit = 64;
	size_t trace_limit = 8;
	bool count = false;
	bool extended = false;
	Value execution;
};

static Bolts hooked(const Job& job, const std::string& when, const std::string& role, Bolts bolts,
                    const Battle& battle) {
	for (const auto& [hook_when, hook_role, index] : job.hooks)
		if (hook_when == when && hook_role == role) bolts = call_card(job.shards[index], bolts, battle, job.limit);
	return bolts;
}

static Value volley_of(const Bolts& bolts) {
	double power = 0;
	Value elements = Value::object();
	std::map<std::string, int> counted;
	std::vector<std::string> order;
	for (const Bolt& bolt : bolts) {
		power += bolt.power;
		if (!counted.count(bolt.element)) order.push_back(bolt.element);
		counted[bolt.element]++;
	}
	for (const auto& element : order) elements.set(element, Value::of(double(counted[element])));
	Value v = Value::object();
	v.set("power", Value::of(power));
	v.set("elements", elements);
	return v;
}

static double work_units(const std::string& complexity, size_t n, int cap, int height) {
	double size = cap > 0 ? std::min(double(n), double(cap)) : double(n);
	constexpr double maximum = double(1 << 30);
	if (complexity == "constant") return 1;
	if (complexity == "logarithmic") return std::ceil(std::log2(size + 1));
	if (complexity == "linearithmic") return std::ceil(size * std::log2(size + 1));
	if (complexity == "quadratic") return std::min(maximum, size * size);
	if (complexity == "exponential") return size >= 30 ? maximum : std::min(maximum, std::pow(2, size));
	if (complexity == "pseudo") return std::min(maximum, size * std::max(1, height));
	return size;
}

static bool is_sorted(const Bolts& bolts) {
	for (size_t i = 1; i < bolts.size(); i++)
		if (bolts[i].power < bolts[i - 1].power) return false;
	return true;
}

// Next-card bodies are part of the interpreter. Each invocation keeps its own input size and measurements.
class Execution {
	const Job& job;
	const std::vector<int>& indexes;
	const Battle& battle;
	Value& trace;
	std::string order = "sorted";
	double work = 0;
	double discount = 1;

	Bolts hooks(const std::string& when, const Shard& shard, Bolts bolts) {
		bolts = hooked(job, when, shard.role, bolts, battle);
		for (const auto& [hook_when, hook_role, index] : job.hooks)
			if (hook_when == when && hook_role == shard.role)
				order = job.shards[index].metadata["makes"].str(order);
		return bolts;
	}

	double bill(const Shard& shard, size_t slot, size_t given, size_t returned,
	            const Value& measured_loops, int measured_calls, bool sorted_input) {
		const Value& metadata = shard.metadata;
		const Value& options = job.execution;
		std::string complexity = metadata["complexity"].str("linear");
		const Value& worst = metadata["worst_case"];
		if (worst["input"].str() == (sorted_input ? "sorted" : "unsorted")) complexity = worst["complexity"].str(complexity);
		complexity = options["role_complexity"][shard.role].str(complexity);
		int height = int(metadata["height"].num(options["height"].num(1)));
		double bill = work_units(complexity, std::max(given, returned), int(metadata["cap_n"].num()), height);
		if (metadata["work_mode"].str() == "measured" && job.count) {
			bill = measured_calls;
			for (const auto& [line, rounds] : *measured_loops.fields) bill += rounds.num();
			bill = std::max(1.0, bill);
		}
		bool remembered = false;
		for (const Value& id : options["ran"].list()) remembered |= id.str() == shard.id;
		if ((slot == 0 && options["free_first_work"].truthy()) || (options["jit"].truthy() && remembered)) bill = 0;
		return std::floor(bill * options["work_factor"].num(1));
	}

	std::pair<Bolts, bool> call(size_t slot, Bolts bolts, int owner = -1, int part = -1) {
		const Shard& shard = job.shards[indexes[slot]];
		Bolts original = bolts;
		std::string original_order = order;
		bolts = hooks("before", shard, bolts);
		size_t given = bolts.size();
		bool sorted_input = is_sorted(bolts);
		size_t returned = 0;
		Bolts result = call_card(shard, bolts, battle, job.limit, &returned);
		Value measured_loops = Value::object();
		for (const auto& [line, rounds] : loops) measured_loops.set(std::to_string(line), Value::of(double(rounds)));
		int measured_calls = calls;
		double stage_work = bill(shard, slot, given, returned, measured_loops, measured_calls, sorted_input);
		double projected = std::min(double(1 << 30), std::floor((work + stage_work) * discount));
		bool pruned = job.execution["prune"].truthy() && projected > job.execution["budget"].num(1 << 30);
		if (pruned) {
			bolts = original;
			order = original_order;
		} else {
			work += stage_work;
			bolts = result;
#ifndef ROOTWARD_SPELLFORGE
			int extra = 0;
			if (shard.role == "source")
				for (const Value& rule : job.execution["source_power"].list())
					if (rule["paradigm"].str().empty() || rule["paradigm"].str() == shard.metadata["paradigm"].str())
						extra += int(rule["add"].num());
			if (shard.role == "strike" && sorted_input) extra += int(job.execution["sorted_strike_power"].num());
			for (Bolt& bolt : bolts)
				if (shard.role == "source" || !bolt.block) bolt.power += extra;
#endif
			order = shard.metadata["makes"].str(order);
			bolts = hooks("after", shard, bolts);
		}
		Value step = Value::object();
		step.set("shard", Value::of(shard.id));
		step.set("given", Value::of(double(given)));
		step.set("returned", Value::of(double(returned)));
		step.set("bolts", value_of(bolts, job.trace_limit));
		step.set("slot", Value::of(double(slot)));
		step.set("input_sorted", Value::of(sorted_input));
		if (owner >= 0) {
			step.set("body", Value::of(double(owner)));
			step.set("part", Value::of(double(part)));
		}
		if (pruned) step.set("pruned", Value::of(true));
		if (job.count) {
			step.set("loops", measured_loops);
			step.set("calls", Value::of(double(measured_calls)));
			Value volley = volley_of(bolts);
			step.set("power", volley["power"]);
			step.set("elements", volley["elements"]);
		}
		trace.push(step);
		return {bolts, !pruned};
	}

	std::pair<Bolts, size_t> body(size_t owner, size_t slot, Bolts bolts, int depth) {
		const Shard& shard = job.shards[indexes[slot]];
		bool nested = depth > 1 && shard.metadata["splits"].truthy() && slot + 1 < indexes.size();
		std::vector<Bolts> pieces{bolts};
		for (int level = 0; level < (nested ? 1 : depth); level++) {
			std::vector<Bolts> halves;
			for (const Bolts& piece : pieces) {
				size_t half = (piece.size() + 1) / 2;
				halves.emplace_back(piece.begin(), piece.begin() + half);
				halves.emplace_back(piece.begin() + half, piece.end());
			}
			pieces = halves;
		}
		Bolts out;
		size_t consumed = slot + 1;
		for (size_t part = 0; part < pieces.size(); part++) {
			auto [result, accepted] = call(slot, pieces[part], int(owner), int(part));
			if (nested && accepted) {
				auto child = body(slot, slot + 1, result, depth - 1);
				result = child.first;
				consumed = child.second;
			}
			out.insert(out.end(), result.begin(), result.end());
		}
		int extra = int(job.execution["rejoin_power"].num());
		for (Bolt& bolt : out) bolt.power += extra;
		if (out.size() > job.limit) out.resize(job.limit);
		Value& last = trace.items->back();
		Value joined = volley_of(out);
		last.set("joined", value_of(out, job.trace_limit));
		last.set("joined_returned", Value::of(double(out.size())));
		last.set("joined_power", joined["power"]);
		last.set("joined_elements", joined["elements"]);
		return {out, consumed};
	}

public:
	Execution(const Job& job, const std::vector<int>& indexes, const Battle& battle, Value& trace)
	    : job(job), indexes(indexes), battle(battle), trace(trace) {
		for (const Value& rule : job.execution["small_program_work"].list())
			if (!indexes.empty() && indexes.size() <= rule["max_cards"].num()) discount *= rule["factor"].num(1);
	}

	Bolts run(Bolts bolts) {
		const Value& body_rule = job.execution["body"];
		int depth = body_rule["kind"].str() == "split" ? std::clamp(int(body_rule["depth"].num()), 0, 2) : 0;
		size_t slot = 0;
		while (slot < indexes.size()) {
			auto [result, accepted] = call(slot, bolts);
			bolts = result;
			const Shard& shard = job.shards[indexes[slot]];
			if (depth > 0 && accepted && shard.metadata["splits"].truthy() && slot + 1 < indexes.size()) {
				auto child = body(slot, slot + 1, bolts, depth);
				bolts = child.first;
				slot = child.second;
			} else slot++;
		}
		return bolts;
	}
};

static Bolts run_spell(const Job& job, const std::vector<int>& indexes, Bolts bolts, const Battle& battle,
                       Value& trace) {
	if (job.extended) return Execution(job, indexes, battle, trace).run(bolts);
	for (int index : indexes) {
		const Shard& shard = job.shards[index];
		bolts = hooked(job, "before", shard.role, bolts, battle);
		size_t given = bolts.size();
		Bolts result = call_card(shard, bolts, battle, job.limit);
		Value measured_loops = Value::object();
		for (const auto& [line, rounds] : loops) measured_loops.set(std::to_string(line), Value::of(double(rounds)));
		int measured_calls = calls;
		size_t returned = result.size();
		bolts = hooked(job, "after", shard.role, result, battle);
		Value step = Value::object();
		step.set("shard", Value::of(shard.id));
		step.set("given", Value::of(double(given)));
		step.set("returned", Value::of(double(returned)));
		step.set("bolts", value_of(bolts, job.trace_limit));
		if (job.count) {
			step.set("loops", measured_loops);
			step.set("calls", Value::of(double(measured_calls)));
			Value volley = volley_of(bolts);
			step.set("power", volley["power"]);
			step.set("elements", volley["elements"]);
		}
		trace.push(step);
	}
	return bolts;
}

static int main_harness() {
	// The sandbox writes a job's standard input beside it (Sandbox._write_job), as the other launchers read it.
	std::ifstream file("/work/.rootward/stdin");
	std::string input((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
	Value data = json::parse(input);
	std::string marker = data["marker"].str();
	Job job;
	for (const auto& s : data["shards"].list()) {
		Shard shard{s["id"].str(), s["name"].str(), s["role"].str()};
		// A Mutator's mutant is its own function, built ahead of time: "<card id>~<operator>".
		std::string id = s.has("mutant") ? shard.id + "~" + std::to_string(int(s["mutant"].num())) : shard.id;
		shard.run = find(id);
		shard.metadata = s;
		job.shards.push_back(shard);
	}
	for (const auto& h : data["hooks"].list())
		job.hooks.emplace_back(h["when"].str(), h["role"].str(), int(h["shard"].num()));
	job.limit = size_t(data["limit"].num(64));
	job.trace_limit = size_t(data["traceLimit"].num(8));
	job.count = data["count"].truthy();
	job.extended = data.has("execution");
	job.execution = data["execution"];
	for (const auto& spell : data["spells"].list()) {
		Battle battle = battle_of(spell.has("battle") ? spell["battle"] : data["battle"]);
		Bolts bolts = bolts_of(spell.has("bolts") ? spell["bolts"] : data["bolts"]);
		std::vector<int> indexes;
		for (const auto& i : spell["shards"].list()) indexes.push_back(int(i.num()));
		Value trace = Value::array();
		Value result = Value::object();
		result.set("spell", spell["id"]);
		try {
			Bolts out = run_spell(job, indexes, bolts, battle, trace);
			result.set("ok", Value::of(true));
			result.set("bolts", value_of(out, out.size()));
			result.set("trace", trace);
		} catch (const Failure& failure) {
			result.set("ok", Value::of(false));
			result.set("error", Value::of(failure.error));
			result.set("shard", Value::of(failure.shard));
			result.set("trace", trace);
		}
		std::cout << marker << json::dump(result) << "\n";
	}
	std::cout.flush();
	return 0;
}

}  // namespace rootward

int main() { return rootward::main_harness(); }
