# Lanternroot's boots (ADR-0061), the Python side: runs inside the sandbox with the player's movement code, and calls
# their on_key(key, player) once for every key on every tile of the map, so the town can walk on the answers without
# waiting for the sandbox at each step.
#
# Input: {"source": "...", "keys": ["up", ...], "width": 40, "height": 30}
# Output: one line on standard output, "@@boots@@ " and a JSON record:
#   {"status": "ok", "x": [...], "y": [...], "error": [...], "errors": [{kind, message, line}], "remembers": false}
#   x[i], y[i] are where the player stood after the call for key k at (cx, cy), i = (k * height + cy) * width + cx;
#   error[i] is -1 or an index into `errors` (each different error once). `remembers` is true when calling again with
#   the same key and tile lands somewhere else: the code keeps something between steps.
# Or {"status": "broken", "kind", "message", "line"} when the code cannot even be loaded, or has no on_key.
# What the code prints is kept out of the way (it runs thousands of times); the start of it comes back as "printed".
import contextlib
import io
import json
import sys
import traceback

MARK = "@@boots@@ "
FILE = "boots.py"
ENTRY = "on_key"
RECHECK = 12
PRINTED = 600


class Player:
    """What on_key moves. Only x and y are read back; anything else the code sets is its own business."""

    def __init__(self, x, y):
        self.x = x
        self.y = y

    def __repr__(self):
        return "Player(x=%r, y=%r)" % (self.x, self.y)


def line_of(error):
    if isinstance(error, SyntaxError) and error.filename == FILE:
        return error.lineno or 0
    for frame in reversed(traceback.extract_tb(error.__traceback__)):
        if frame.filename == FILE:
            return frame.lineno or 0
    return 0


def emit(record):
    sys.stdout.write(MARK + json.dumps(record) + "\n")
    sys.stdout.flush()


def whole(value):
    # True is a number to Python, but not a place on the map.
    return isinstance(value, int) and not isinstance(value, bool)


class Printed(io.StringIO):
    """Keeps only the start of what was printed: a print in on_key runs once per key per tile."""

    def write(self, text):
        room = PRINTED - self.tell()
        if room > 0:
            super().write(text[:room])
        return len(text)


def main():
    request = json.loads(sys.stdin.read())
    printed = Printed()
    with contextlib.redirect_stdout(printed):
        record = run(request)
    record["printed"] = printed.getvalue()
    emit(record)


def run(request):
    namespace = {"__name__": "boots"}
    try:
        exec(compile(request["source"], FILE, "exec"), namespace)
    except BaseException as error:
        return {"status": "broken", "kind": type(error).__name__, "message": str(error), "line": line_of(error)}
    on_key = namespace.get(ENTRY)
    if not callable(on_key):
        return {"status": "broken", "kind": "missing", "message": "there is no function %s(key, player)" % ENTRY, "line": 0}
    keys, width, height = request["keys"], request["width"], request["height"]
    errors, seen = [], {}
    xs, ys, marks = [], [], []

    def step(key, cx, cy):
        player = Player(cx, cy)
        try:
            on_key(key, player)
            if not whole(player.x) or not whole(player.y):
                raise TypeError("player.x and player.y must be whole numbers, not %r and %r" % (player.x, player.y))
            return player.x, player.y, -1
        except RecursionError:
            problem = ("RecursionError", "the recursion went too deep", 0)
        except BaseException as error:
            problem = (type(error).__name__, str(error), line_of(error))
        if problem not in seen:
            seen[problem] = len(errors)
            errors.append({"kind": problem[0], "message": problem[1], "line": problem[2]})
        return cx, cy, seen[problem]

    for key in keys:
        for cy in range(height):
            for cx in range(width):
                x, y, mark = step(key, cx, cy)
                xs.append(x)
                ys.append(y)
                marks.append(mark)
    # Ask a few again, from the end backwards: a rule that depends only on the key and the tile answers the same.
    remembers = False
    total = len(xs)
    for i in range(total - 1, max(-1, total - 1 - RECHECK), -1):
        k, rest = divmod(i, width * height)
        cy, cx = divmod(rest, width)
        x, y, mark = step(keys[k], cx, cy)
        if (x, y) != (xs[i], ys[i]):
            remembers = True
            break
    return {"status": "ok", "x": xs, "y": ys, "error": marks, "errors": errors, "remembers": remembers}


main()
