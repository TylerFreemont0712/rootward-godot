# The Shardrun spell harness for Python (old ADR-0012, ADR-0013). Standard input is one JSON object: the shards'
# sources, the spells (lists of indexes into the shards), the starting bolts, the battle, and the limits. Each spell's
# result is printed as one line starting with the job's marker. SpellHarness (spell_harness.gd) builds the input and
# reads the lines back.
import json
import math
import re
import sys
import traceback

DATA = json.loads(sys.stdin.read())
SHARDS = DATA["shards"]
MARKER = DATA["marker"]


def load(shard):
    # Each shard gets its own namespace, loaded fresh for every spell, so shards cannot collide or keep state.
    namespace = {"__name__": "shard_" + shard["name"]}
    exec(compile(shard["source"], shard["id"] + ".py", "exec"), namespace)
    function = namespace.get(shard["name"])
    if not callable(function):
        raise NameError(shard["id"] + " does not define " + shard["name"] + "(bolts, battle)")
    return function


# A program run (ADR-0012) asks for counts: how many times each loop in a card went round and how many times its
# function was entered (recursion), measured by a line tracer on the card's own file only. Other runs never trace.
COUNT = bool(DATA.get("count"))
LOOP_HEAD = re.compile(r"^\s*(for|while)\b")
INLINE_FOR = re.compile(r"[\[({].*\bfor\b.+\bin\b")


# LEARN: sys.settrace calls a function on every line run; a loop's first body line counts its rounds (see the log).
def counted(function, shard, bolts, battle):
    """Calls the card's function under a line tracer. Returns its result and {loops: {line: iterations}, calls}."""
    filename = shard["id"] + ".py"
    counts = {}
    calls = [0]

    def local(frame, event, arg):
        if event == "line":
            counts[frame.f_lineno] = counts.get(frame.f_lineno, 0) + 1
        return local

    def tracer(frame, event, arg):
        if frame.f_code.co_filename != filename:
            return None
        if frame.f_code.co_name == shard["name"]:
            calls[0] += 1
        return local

    sys.settrace(tracer)
    try:
        result = function(bolts, battle)
    finally:
        sys.settrace(None)
    return result, {"loops": loops_of(shard["source"], counts), "calls": calls[0]}


def loops_of(source, counts):
    """Each loop's iterations from the line counts. A loop's header runs once more than its body (the last check), so a
    header's count less one is its rounds; a one-line comprehension counts the same way. When a loop's first body line is
    not itself a loop, its count is the rounds exactly: right for a loop left by break, and for one entered many times
    (in a recursive function), where the header's extra checks add up."""
    lines = source.split("\n")
    loops = {}
    for index, text in enumerate(lines):
        seen = counts.get(index + 1, 0)
        if seen == 0:
            continue
        if LOOP_HEAD.match(text):
            indent = len(text) - len(text.lstrip())
            rounds = max(0, seen - 1)
            for after in range(index + 1, len(lines)):
                body = lines[after]
                if not body.strip() or body.strip().startswith("#"):
                    continue
                if len(body) - len(body.lstrip()) > indent and not LOOP_HEAD.match(body):
                    rounds = counts.get(after + 1, rounds)
                break
            loops[str(index + 1)] = rounds
        elif INLINE_FOR.search(text):
            loops[str(index + 1)] = max(0, seen - 1)
    return loops


def volley_of(bolts):
    """The whole volley a stage returned, summed (the trace keeps only its first bolts): its power and its elements."""
    power = 0
    elements = {}
    for bolt in bolts:
        if isinstance(bolt, dict):
            value = bolt.get("power")
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                power += value
            element = bolt.get("element")
            if isinstance(element, str):
                elements[element] = elements.get(element, 0) + 1
    return {"power": power, "elements": elements}


class ShardFailure(Exception):
    def __init__(self, shard, error):
        super().__init__(str(error))
        self.shard = shard
        self.error = error


# A program run's imports may hook a role (ADR-0018): the import's own function runs on the volley before or after
# every card of that role (heapq hands each strike the strongest bolt first; bisect sorts what each source made).
# LEARN: a hook is a function called around other functions without them knowing (a decorator's idea): the cards stay
# as they are, and what an import changes is the data they are handed.
HOOKS = DATA.get("hooks", [])


def hooked(when, role, bolts, battle_json):
    for hook in HOOKS:
        if hook["when"] != when or hook["role"] != role:
            continue
        shard = SHARDS[hook["shard"]]
        try:
            result = load(shard)(bolts, json.loads(battle_json))
            if not isinstance(result, list):
                raise TypeError(shard["name"] + " must return a list of bolts, not " + type(result).__name__)
            bolts = json.loads(json.dumps(result[: DATA["limit"]], allow_nan=False))
        except Exception as error:
            raise ShardFailure(shard, error)
    return bolts


def work_units(complexity, size, cap=0, height=1):
    size = min(size, cap) if cap > 0 else size
    maximum = 1 << 30
    if complexity == "constant":
        return 1
    if complexity == "logarithmic":
        return math.ceil(math.log2(size + 1))
    if complexity == "linearithmic":
        return math.ceil(size * math.log2(size + 1))
    if complexity == "quadratic":
        return min(maximum, size * size)
    if complexity == "exponential":
        return maximum if size >= 30 else min(maximum, 1 << size)
    if complexity == "pseudo":
        return min(maximum, size * max(1, height))
    return size


def is_sorted(bolts):
    if any(not isinstance(bolt, dict) or not isinstance(bolt.get("power"), (int, float)) for bolt in bolts):
        return False
    return all(bolts[i - 1].get("power", 0) <= bolts[i].get("power", 0) for i in range(1, len(bolts)))


class Execution:
    """A card taking the next card as a body is an interpreter primitive, independent of either card's code."""

    def __init__(self, spell, battle_json, trace):
        self.indexes = spell["shards"]
        self.battle_json = battle_json
        self.trace = trace
        self.options = DATA.get("execution", {})
        self.extended = "execution" in DATA
        self.order = "sorted"
        self.work = 0
        self.discount = 1.0
        for rule in self.options.get("small_program_work", []):
            if self.indexes and len(self.indexes) <= rule["max_cards"]:
                self.discount *= rule["factor"]

    def hooks(self, when, shard, bolts):
        bolts = hooked(when, shard.get("role"), bolts, self.battle_json)
        for hook in HOOKS:
            if hook["when"] == when and hook["role"] == shard.get("role"):
                self.order = SHARDS[hook["shard"]].get("makes", self.order)
        return bolts

    def bill(self, shard, slot, given, returned, measured, sorted_input):
        complexity = shard.get("complexity", "linear")
        worst = shard.get("worst_case", {})
        if worst.get("input") == ("sorted" if sorted_input else "unsorted"):
            complexity = worst["complexity"]
        complexity = self.options.get("role_complexity", {}).get(shard.get("role"), complexity)
        height = shard.get("height", self.options.get("height", 1))
        work = work_units(complexity, max(given, returned), shard.get("cap_n", 0), height)
        if shard.get("work_mode") == "measured" and measured is not None:
            work = max(1, measured["calls"] + sum(measured["loops"].values()))
        if (slot == 0 and self.options.get("free_first_work")) or (
            self.options.get("jit") and shard["id"] in self.options.get("ran", [])
        ):
            work = 0
        return math.floor(work * self.options.get("work_factor", 1.0))

    def call(self, slot, bolts, body=None, part=None):
        shard = SHARDS[self.indexes[slot]]
        original = json.loads(json.dumps(bolts))
        original_order = self.order
        bolts = self.hooks("before", shard, bolts)
        given = len(bolts)
        sorted_input = is_sorted(bolts)
        try:
            function = load(shard)
            measured = None
            if COUNT:
                result, measured = counted(function, shard, bolts, json.loads(self.battle_json))
            else:
                result = function(bolts, json.loads(self.battle_json))
            if not isinstance(result, list):
                raise TypeError(shard["name"] + " must return a list of bolts, not " + type(result).__name__)
            # A JSON round trip isolates results and rejects non-data values at the card which produced them.
            snapshot = json.dumps(result[: DATA["limit"]], allow_nan=False)
        except Exception as error:
            raise ShardFailure(shard, error)
        work = self.bill(shard, slot, given, len(result), measured, sorted_input)
        projected = min(1 << 30, math.floor((self.work + work) * self.discount))
        pruned = self.options.get("prune", False) and projected > self.options.get("budget", 1 << 30)
        if pruned:
            bolts = original
            self.order = original_order
        else:
            self.work += work
            bolts = json.loads(snapshot)
            extra = 0
            if shard.get("role") == "source":
                extra += sum(rule["add"] for rule in self.options.get("source_power", [])
                             if not rule.get("paradigm") or rule["paradigm"] == shard.get("paradigm"))
            if shard.get("role") == "strike" and sorted_input:
                extra += self.options.get("sorted_strike_power", 0)
            if extra:
                bolts = [dict(bolt, power=bolt["power"] + extra)
                         if isinstance(bolt, dict) and isinstance(bolt.get("power"), (int, float))
                         and (shard.get("role") == "source" or not bolt.get("block")) else bolt for bolt in bolts]
            self.order = shard.get("makes", self.order)
            bolts = self.hooks("after", shard, bolts)
        step = {"shard": shard["id"], "given": given, "returned": len(result),
                "bolts": json.loads(json.dumps(bolts))[: DATA["traceLimit"]]}
        if measured is not None:
            step.update(measured)
            step.update(volley_of(bolts))
        if self.extended:
            step.update(slot=slot, input_sorted=sorted_input)
            if body is not None:
                step.update(body=body, part=part)
            if pruned:
                step["pruned"] = True
        self.trace.append(step)
        return bolts, not pruned

    def body(self, owner, slot, bolts, depth):
        shard = SHARDS[self.indexes[slot]]
        nested = depth > 1 and shard.get("splits") and slot + 1 < len(self.indexes)
        pieces = [bolts]
        for _ in range(1 if nested else depth):
            pieces = [half for piece in pieces for half in (piece[: (len(piece) + 1) // 2], piece[(len(piece) + 1) // 2 :])]
        out = []
        consumed = slot + 1
        for part, piece in enumerate(pieces):
            result, accepted = self.call(slot, piece, owner, part)
            if nested and accepted:
                result, consumed = self.body(slot, slot + 1, result, depth - 1)
            out.extend(result)
        extra = self.options.get("rejoin_power", 0)
        if extra:
            out = [dict(bolt, power=bolt["power"] + extra) for bolt in out]
        out = out[: DATA["limit"]]
        joined = volley_of(out)
        self.trace[-1].update(joined=json.loads(json.dumps(out))[: DATA["traceLimit"]], joined_returned=len(out),
                              joined_power=joined["power"], joined_elements=joined["elements"])
        return out, consumed

    def run(self, bolts):
        slot = 0
        body_rule = self.options.get("body", {})
        depth = max(0, min(2, body_rule.get("depth", 0))) if body_rule.get("kind") == "split" else 0
        while slot < len(self.indexes):
            bolts, accepted = self.call(slot, bolts)
            shard = SHARDS[self.indexes[slot]]
            if depth and accepted and shard.get("splits") and slot + 1 < len(self.indexes):
                bolts, slot = self.body(slot, slot + 1, bolts, depth)
            else:
                slot += 1
        return bolts


def run_spell(spell, battle_json, trace):
    bolts = json.loads(json.dumps(spell.get("bolts", DATA["bolts"])))
    return Execution(spell, battle_json, trace).run(bolts)


def locate(failure):
    error = failure.error
    filename = failure.shard["id"] + ".py"
    line = None
    if isinstance(error, SyntaxError) and error.filename == filename:
        line = error.lineno
    for frame in traceback.extract_tb(error.__traceback__):
        if frame.filename == filename:
            line = frame.lineno
    return line


def main():
    default_battle = json.dumps(DATA["battle"])
    for spell in DATA["spells"]:
        battle_json = json.dumps(spell["battle"]) if "battle" in spell else default_battle
        trace = []
        try:
            bolts = run_spell(spell, battle_json, trace)
            result = {"spell": spell["id"], "ok": True, "bolts": bolts, "trace": trace}
        except ShardFailure as failure:
            error = failure.error
            result = {
                "spell": spell["id"],
                "ok": False,
                "error": type(error).__name__ + ": " + str(error),
                "shard": failure.shard["id"],
                "trace": trace,
            }
            line = locate(failure)
            if line is not None:
                result["line"] = line
        print(MARKER + json.dumps(result))


main()
