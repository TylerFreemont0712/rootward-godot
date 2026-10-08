# The Shardrun spell harness for Python (old ADR-0012, ADR-0013). Standard input is one JSON object: the shards'
# sources, the spells (lists of indexes into the shards), the starting bolts, the battle, and the limits. Each spell's
# result is printed as one line starting with the job's marker. SpellHarness (spell_harness.gd) builds the input and
# reads the lines back.
import json
import math
import re
import sys
import traceback

# Every built-in or library function the harness calls after a card returns is bound here, before any card code runs
# (docs/LEGENDARY_LOOKS.md, Program tags). Captured built-ins are safe: a card that rebinds one of them changes nothing
# the harness stamps, serialises, prints or bills. A card that rebinds a global name of the harness can change only its
# own run's output; closing that fully is open.
# LEARN: a bare name is looked up in the module's globals, then in builtins, at each call. Binding `dict = dict` here
# gives the module a global of its own, so the harness's dict(...) is the builtin as it was at import, whatever a card
# later does to builtins.dict. The module functions below are bound the same way.
# LEARN: a capture holds the function, not what the function reads. json.dumps still looks up its own module's globals
# when it runs, and a card that reaches them can change its own run's output. The guarantee is about the names the
# harness calls.
all = all
any = any
bool = bool
callable = callable
compile = compile
dict = dict
enumerate = enumerate
exec = exec
float = float
int = int
isinstance = isinstance
len = len
list = list
max = max
min = min
range = range
str = str
sum = sum
type = type
Exception = Exception
NameError = NameError
SyntaxError = SyntaxError
TypeError = TypeError
ceil = math.ceil
floor = math.floor
log2 = math.log2
dumps = json.dumps
loads = json.loads
settrace = sys.settrace
extract_tb = traceback.extract_tb
write_stdout = sys.stdout.write
flush_stdout = sys.stdout.flush

# Capture at start (docs/LEGENDARY_LOOKS.md, Program tags). Every record the harness reads after a card has run is copied
# here, before any card code runs, and each later read uses the copy. A card reaches the harness's globals through
# sys._getframe, so the copies are values a card cannot change: numbers, strings, tuples, and JSON text that each use
# parses afresh. DATA itself is read only in this block.
# LEARN: a dict the harness keeps can be changed by any card that reaches it, and then every later read sees the change.
# So the harness keeps text for what it reads again (a fresh parse each time) and plain values for what it only compares.
DATA = loads(sys.stdin.read())
MARKER = DATA["marker"]
COUNT = bool(DATA.get("count"))
TAGS = bool(DATA.get("tags"))
LIMIT = DATA["limit"]
TRACE_LIMIT = DATA["traceLimit"]
SHARD_TEXT = tuple(dumps(shard) for shard in DATA["shards"])
# A shard's id and role as the stamp writes them (the role is None when the shard has none).
STAMPS = tuple((shard["id"], shard.get("role")) for shard in DATA["shards"])
HOOKS = tuple((hook["when"], hook["role"], hook["shard"]) for hook in DATA.get("hooks", []))
SPELL_TEXT = tuple(dumps(spell) for spell in DATA["spells"])
DEFAULT_BOLTS = dumps(DATA["bolts"])
DEFAULT_BATTLE = dumps(DATA["battle"])
# The execution rules: each spell parses its own copy of the text, and the relic arithmetic reads the values below.
EXECUTION = dumps(DATA.get("execution", {}))
EXTENDED = "execution" in DATA
RULES = DATA.get("execution", {})
SOURCE_POWER = tuple((rule.get("paradigm"), rule["add"]) for rule in RULES.get("source_power", []))
REJOIN_POWER = RULES.get("rejoin_power", 0)
SORTED_STRIKE_POWER = RULES.get("sorted_strike_power", 0)
del RULES


def shard_at(index):
    """A fresh copy of the shard at `index`, parsed from the text captured at start."""
    return loads(SHARD_TEXT[index])


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

    settrace(tracer)
    try:
        result = function(bolts, battle)
    finally:
        settrace(None)
    # The measured copy is a JSON copy made inside the card's try, as in spell_harness.js: its failure is the card's.
    return result, loads(dumps({"loops": loops_of(shard["source"], counts), "calls": calls[0]}))


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
        Exception.__init__(self, str(error))
        self.shard = shard
        self.error = error


# A program run's bolts carry the card that returned them and that card's role (docs/LEGENDARY_LOOKS.md, Program tags):
# the job's `tags`. The card that returns a bolt is the one that cast it, even when it hands the bolt back unchanged.
# A card cannot choose its look through its returned values: the stamp overwrites any card or role key the card's code
# put on a bolt. The stamp calls the captures above, so a card that rebinds a built-in cannot change a bolt's tags.
def tagged(bolts, stamp):
    """The bolts, each with the card's id and role in place of any card or role key they carry."""
    return [
        dict(bolt, card=stamp[0], role=stamp[1] or "") if isinstance(bolt, dict) else bolt
        for bolt in bolts
    ]


# A program run's imports may hook a role (ADR-0018): the import's own function runs on the volley before or after
# every card of that role (heapq hands each strike the strongest bolt first; bisect sorts what each source made).
# LEARN: a hook is a function called around other functions without them knowing (a decorator's idea): the cards stay
# as they are, and what an import changes is the data they are handed.
# LEARN: an import is not a step of the program (ProgramDeck.steps leaves it out), so after a card the bolts it hands
# back are still that card's. Each import's bolts are stamped before the next import runs: whatever an import wrote on
# a bolt is replaced, and a second import sees the card's tags, as the C++ harness does. Before a card the bolts are not
# yet its, so the card is handed them as they came.
def hooked(when, stamp, bolts, battle_json):
    for hook_when, hook_role, index in HOOKS:
        if hook_when != when or hook_role != stamp[1]:
            continue
        shard = shard_at(index)
        try:
            result = load(shard)(bolts, loads(battle_json))
            if not isinstance(result, list):
                raise TypeError(shard["name"] + " must return a list of bolts, not " + type(result).__name__)
            bolts = loads(dumps(result[:LIMIT], allow_nan=False))
            if TAGS and when == "after":
                bolts = tagged(bolts, stamp)
        except Exception as error:
            raise ShardFailure(shard, error)
    return bolts


def work_units(complexity, size, cap=0, height=1):
    size = min(size, cap) if cap > 0 else size
    maximum = 1 << 30
    if complexity == "constant":
        return 1
    if complexity == "logarithmic":
        return ceil(log2(size + 1))
    if complexity == "linearithmic":
        return ceil(size * log2(size + 1))
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
        self.options = loads(EXECUTION)
        self.extended = EXTENDED
        self.order = "sorted"
        self.work = 0
        self.discount = 1.0
        for rule in self.options.get("small_program_work", []):
            if self.indexes and len(self.indexes) <= rule["max_cards"]:
                self.discount *= rule["factor"]

    def hooks(self, when, index, bolts):
        stamp = STAMPS[index]
        bolts = hooked(when, stamp, bolts, self.battle_json)
        for hook_when, hook_role, hook_index in HOOKS:
            if hook_when == when and hook_role == stamp[1]:
                self.order = shard_at(hook_index).get("makes", self.order)
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
        return floor(work * self.options.get("work_factor", 1.0))

    def call(self, slot, bolts, body=None, part=None):
        index = self.indexes[slot]
        shard = shard_at(index)
        stamp = STAMPS[index]
        original = loads(dumps(bolts))
        original_order = self.order
        bolts = self.hooks("before", index, bolts)
        given = len(bolts)
        sorted_input = is_sorted(bolts)
        try:
            function = load(shard)
            measured = None
            if COUNT:
                result, measured = counted(function, shard, bolts, loads(self.battle_json))
            else:
                result = function(bolts, loads(self.battle_json))
            if not isinstance(result, list):
                raise TypeError(shard["name"] + " must return a list of bolts, not " + type(result).__name__)
            # One JSON copy of what the card returned, made once: the bill and the output both come from this copy, so
            # a list whose length reads differently cannot change what is billed (docs/LEGENDARY_LOOKS.md). The stamp
            # runs on the copy inside the card's try, so its errors are the card's.
            copy = loads(dumps(result, allow_nan=False))
            if TAGS:
                copy = tagged(copy, stamp)
        except Exception as error:
            raise ShardFailure(shard, error)
        returned = len(copy)
        work = self.bill(shard, slot, given, returned, measured, sorted_input)
        projected = min(1 << 30, floor((self.work + work) * self.discount))
        pruned = self.options.get("prune", False) and projected > self.options.get("budget", 1 << 30)
        if pruned:
            bolts = original
            self.order = original_order
        else:
            self.work += work
            bolts = copy[:LIMIT]
            extra = 0
            if shard.get("role") == "source":
                extra += sum(add for paradigm, add in SOURCE_POWER
                             if not paradigm or paradigm == shard.get("paradigm"))
            if shard.get("role") == "strike" and sorted_input:
                extra += SORTED_STRIKE_POWER
            if extra:
                bolts = [dict(bolt, power=bolt["power"] + extra)
                         if isinstance(bolt, dict) and isinstance(bolt.get("power"), (int, float))
                         and (shard.get("role") == "source" or not bolt.get("block")) else bolt for bolt in bolts]
            self.order = shard.get("makes", self.order)
            bolts = self.hooks("after", index, bolts)
        step = {"shard": stamp[0], "given": given, "returned": returned,
                "bolts": loads(dumps(bolts))[:TRACE_LIMIT]}
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
        shard = shard_at(self.indexes[slot])
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
        if REJOIN_POWER:
            out = [dict(bolt, power=bolt["power"] + REJOIN_POWER) for bolt in out]
        out = out[:LIMIT]
        joined = volley_of(out)
        self.trace[-1].update(joined=loads(dumps(out))[:TRACE_LIMIT], joined_returned=len(out),
                              joined_power=joined["power"], joined_elements=joined["elements"])
        return out, consumed

    def run(self, bolts):
        slot = 0
        body_rule = self.options.get("body", {})
        depth = max(0, min(2, body_rule.get("depth", 0))) if body_rule.get("kind") == "split" else 0
        while slot < len(self.indexes):
            bolts, accepted = self.call(slot, bolts)
            shard = shard_at(self.indexes[slot])
            if depth and accepted and shard.get("splits") and slot + 1 < len(self.indexes):
                bolts, slot = self.body(slot, slot + 1, bolts, depth)
            else:
                slot += 1
        return bolts


def run_spell(spell, battle_json, trace):
    bolts = loads(dumps(spell["bolts"]) if "bolts" in spell else DEFAULT_BOLTS)
    return Execution(spell, battle_json, trace).run(bolts)


def locate(failure):
    error = failure.error
    filename = failure.shard["id"] + ".py"
    line = None
    if isinstance(error, SyntaxError) and error.filename == filename:
        line = error.lineno
    for frame in extract_tb(error.__traceback__):
        if frame.filename == filename:
            line = frame.lineno
    return line


def main():
    for spell_text in SPELL_TEXT:
        spell = loads(spell_text)
        battle_json = dumps(spell["battle"]) if "battle" in spell else DEFAULT_BATTLE
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
        # The line goes out through the captured stream and is flushed there, so a card that rebinds print or sys.stdout
        # cannot change it, and the launcher's own flush cannot lose it.
        write_stdout(MARKER + dumps(result) + "\n")
        flush_stdout()


main()
