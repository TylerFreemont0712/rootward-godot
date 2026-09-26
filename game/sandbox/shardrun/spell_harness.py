# The Shardrun spell harness for Python (old ADR-0012, ADR-0013). Standard input is one JSON object: the shards'
# sources, the spells (lists of indexes into the shards), the starting bolts, the battle, and the limits. Each spell's
# result is printed as one line starting with the job's marker. SpellHarness (spell_harness.gd) builds the input and
# reads the lines back.
import json
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


class ShardFailure(Exception):
    def __init__(self, shard, error):
        super().__init__(str(error))
        self.shard = shard
        self.error = error


def run_spell(spell, battle_json, trace):
    # A spell can bring its own starting bolts and battle (content validation runs every worked example in one job).
    bolts = json.loads(json.dumps(spell.get("bolts", DATA["bolts"])))
    for index in spell["shards"]:
        shard = SHARDS[index]
        try:
            function = load(shard)
            given = len(bolts)
            measured = None
            if COUNT:
                result, measured = counted(function, shard, bolts, json.loads(battle_json))
            else:
                result = function(bolts, json.loads(battle_json))
            if not isinstance(result, list):
                raise TypeError(shard["name"] + " must return a list of bolts, not " + type(result).__name__)
            # A JSON round trip copies the bolts, so no shard can change another step's bolts afterwards, and it
            # rejects values that are not plain data (like float("inf")) at the shard that made them.
            snapshot = json.dumps(result[: DATA["limit"]], allow_nan=False)
        except Exception as error:
            raise ShardFailure(shard, error)
        bolts = json.loads(snapshot)
        kept = json.loads(snapshot)[: DATA["traceLimit"]]
        step = {"shard": shard["id"], "given": given, "returned": len(result), "bolts": kept}
        if measured is not None:
            step.update(measured)
        trace.append(step)
    return bolts


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
