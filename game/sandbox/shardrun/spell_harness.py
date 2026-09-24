# The Shardrun spell harness for Python (old ADR-0012, ADR-0013). Standard input is one JSON object: the shards'
# sources, the spells (lists of indexes into the shards), the starting bolts, the battle, and the limits. Each spell's
# result is printed as one line starting with the job's marker. SpellHarness (spell_harness.gd) builds the input and
# reads the lines back.
import json
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
        trace.append({"shard": shard["id"], "given": given, "returned": len(result), "bolts": kept})
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
