# Lanternroot's things (ADR-0061, TownThings), the Python side: runs inside the sandbox with the player's code for one
# use of a thing, and calls their on_use(thing, player) (or onUse) once. One job, one call, one record.
#
# Input: {"entries": ["on_use", "onUse"], "source": "...",
#         "thing": {"id": "root-gate", "fields": {"open": false}, "keys": ["right", "up"], "text": ""},
#         "player": {"x": 28, "y": 19, "map": "lanternroot", "facing": "up", "name": "Tinker"}}
# Output: one line on standard output, "@@thing@@ " and a JSON record. The line starts after a newline, since the code
# may have printed without one; it is the last marked line, because the code has finished before it is written:
#   {"status": "ok", "ok": true, "value": ..., "printed": "..."}              the code gave back `value`
#   {"status": "ok", "ok": false, "kind", "message", "line", "printed"}       the code raised an error
#   {"status": "broken", "ok": false, "kind", "message", "line", "printed"}   it cannot be loaded, or has no such function
# What the code prints goes to standard output as it is. Sandbox keeps 16 KB of output and stops a run that prints more,
# so a print in a loop is cut off rather than kept short. The start of it comes back as "printed".
# Only `value` is read back: what the code sets on thing or player reaches nothing.
#
# LEARN: a memory error is not caught here. It is raised out of the harness to the launcher, which exits 72, and Sandbox
# reports the run as out of memory. Caught, it would look like an error in the player's code.
import json
import math
import sys
import traceback

MARK = "@@thing@@ "
FILE = "hook.py"
PRINTED = 600
DEPTH = 20
def missing(entries):
    """What a missing hook is called, from the names the request gives (on_use, on_step, on_change and their twins)."""
    return "there is no function " + " or ".join(name + "(thing, player)" for name in entries)


class Thing:
    """What the code sees as its thing: its id, its declared fields, the keys the boots know, its default words, and for
    on_change what the linked thing changed (source: {id, fields, changed}; {} otherwise)."""

    def __init__(self, thing_id, fields, keys, text, source=None):
        self.id = thing_id
        self.fields = fields
        self.keys = keys
        self.text = text
        self.source = source if source is not None else {}


class Player:
    """Where the player stands, by attribute: player.x, player.y, player.map, player.facing and player.name."""

    def __init__(self, x, y, map_id, facing, name):
        self.x = x
        self.y = y
        self.map = map_id
        self.facing = facing
        self.name = name


class Tee:
    """Passes what the code prints on to standard output unchanged, and keeps the start of it for the record."""

    def __init__(self, out):
        self.out = out
        self.kept = ""

    def write(self, text):
        room = PRINTED - len(self.kept)
        if room > 0:
            self.kept += text[:room]
        return self.out.write(text)

    def flush(self):
        self.out.flush()


def line_of(error):
    if isinstance(error, SyntaxError) and error.filename == FILE:
        return error.lineno or 0
    for frame in reversed(traceback.extract_tb(error.__traceback__)):
        if frame.filename == FILE:
            return frame.lineno or 0
    return 0


def problem_of(error):
    if isinstance(error, RecursionError):
        return {"ok": False, "kind": "RecursionError", "message": "the recursion went too deep", "line": line_of(error)}
    return {"ok": False, "kind": type(error).__name__, "message": str(error), "line": line_of(error)}


def emit(record):
    sys.stdout.write("\n" + MARK + json.dumps(record) + "\n")
    sys.stdout.flush()


def plain(value, depth=0):
    """What the code gave back, as JSON can carry it: anything else becomes its repr."""
    if depth > DEPTH:
        return repr(value)
    if value is None or isinstance(value, (bool, str, int)):
        return value
    if isinstance(value, float):
        return value if math.isfinite(value) else repr(value)
    if isinstance(value, dict):
        return {str(key): plain(item, depth + 1) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [plain(item, depth + 1) for item in value]
    return repr(value)


def main():
    request = json.loads(sys.stdin.read())
    real = sys.stdout
    tee = Tee(real)
    sys.stdout = tee
    try:
        record = run(request)
    finally:
        sys.stdout = real
    record["printed"] = tee.kept
    emit(record)


def run(request):
    namespace = {"__name__": "thing"}
    try:
        exec(compile(request["source"], FILE, "exec"), namespace)
    except MemoryError:
        raise
    except BaseException as error:
        return dict(problem_of(error), status="broken")
    function = None
    for name in request["entries"]:
        if callable(namespace.get(name)):
            function = namespace[name]
            break
    if function is None:
        return {"status": "broken", "ok": False, "kind": "missing", "message": missing(request["entries"]), "line": 0}
    thing = request.get("thing", {})
    where = request.get("player", {})
    player = Player(where.get("x", 0), where.get("y", 0), where.get("map", ""), where.get("facing", ""), where.get("name", ""))
    fields = dict(thing.get("fields", {}))
    keys = list(thing.get("keys", []))
    try:
        source = dict(thing.get("source", {}))
        value = function(Thing(thing.get("id", ""), fields, keys, thing.get("text", ""), source), player)
    except MemoryError:
        raise
    except BaseException as error:
        return dict(problem_of(error), status="ok")
    return {"status": "ok", "ok": True, "value": plain(value)}


main()
