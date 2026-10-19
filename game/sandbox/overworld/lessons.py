# Lanternroot's lessons (ADR-0061), the Python side: runs inside the sandbox with the player's lesson code and calls
# their function once on each case, in one job.
#
#   memory: save(player) gets a dictionary {"x", "y", "map", "facing", "name"} and gives back what to remember.
#   lamps:  light_all(lamps) gets a list of {"name", "lit"} dictionaries and lights them; what it gives back is used
#           when it is a list, else the list it was given, as the function left it.
#
# Input: {"lesson": "memory" | "lamps", "entries": ["save"], "signature": "save(player)", "source": "...",
#         "cases": [...]}
# Output: one line on standard output, "@@lesson@@ " and a JSON record:
#   {"status": "ok", "results": [{"ok": true, "value": ...} or {"ok": false, "kind", "message", "line"}], "printed"}
# Or {"status": "broken", "kind", "message", "line"} when the code cannot even be loaded, or has no such function.
import contextlib
import io
import json
import math
import sys
import traceback

MARK = "@@lesson@@ "
FILE = "lesson.py"
PRINTED = 600
DEPTH = 20


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


class Printed(io.StringIO):
    """Keeps only the start of what was printed."""

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


def problem_of(error):
    if isinstance(error, RecursionError):
        return {"ok": False, "kind": "RecursionError", "message": "the recursion went too deep", "line": line_of(error)}
    return {"ok": False, "kind": type(error).__name__, "message": str(error), "line": line_of(error)}


def call(lesson, function, case):
    if lesson == "lamps":
        lamps = [dict(lamp) for lamp in case]
        given = function(lamps)
        return given if isinstance(given, list) else lamps
    return function(dict(case))


def run(request):
    namespace = {"__name__": "lesson"}
    try:
        exec(compile(request["source"], FILE, "exec"), namespace)
    except BaseException as error:
        return dict(problem_of(error), status="broken")
    function = None
    for name in request["entries"]:
        if callable(namespace.get(name)):
            function = namespace[name]
            break
    if function is None:
        message = "there is no function %s" % request["signature"]
        return {"status": "broken", "kind": "missing", "message": message, "line": 0}
    results = []
    for case in request["cases"]:
        try:
            results.append({"ok": True, "value": plain(call(request["lesson"], function, case))})
        except BaseException as error:
            results.append(problem_of(error))
    return {"status": "ok", "results": results}


main()
