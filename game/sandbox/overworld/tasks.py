# Lanternroot's tasks (Concept/v0.4, the parts of the game the player builds), the Python side: runs inside the
# sandbox with the player's code and calls their function once for each call, in one job. The lessons' harness
# (lessons.py) made general: each call names its own function, so one job checks every stage of a task, and a table
# (every key, every notch, every minute) is one job too.
#
# Input: {"source": "...",
#         "calls": [{"entries": ["add"], "signature": "add(bag, item)", "args": [[], "apple"], "mutates": 0}, ...]}
#   A call's arguments are deep-copied, so one call never sees what another changed. When the function gives back
#   nothing (None) and "mutates" is an argument's index, the answer is that argument as the function left it (a bag
#   changed in place). With "args_after": true the result also carries the arguments as the function left them (a
#   pure function must not change what it is given).
# Output: one line on standard output, "@@task@@ " and a JSON record:
#   {"status": "ok", "results": [{"ok": true, "value": ...} or {"ok": false, "kind", "message", "line"}], "printed"}
#   {"status": "broken", "kind", "message", "line", "printed"} when the code cannot even be loaded.
# A function that is not there is that call's problem ({"ok": false, "kind": "missing"}), not the whole run's: a
# program that has stage 1's function and not yet stage 2's still answers stage 1.
import contextlib
import copy
import io
import json
import math
import sys
import traceback

MARK = "@@task@@ "
FILE = "task.py"
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


class Printed(io.StringIO):
    """Keeps only the start of what was printed."""

    def write(self, text):
        room = PRINTED - self.tell()
        if room > 0:
            super().write(text[:room])
        return len(text)


def problem_of(error):
    if isinstance(error, RecursionError):
        return {"ok": False, "kind": "RecursionError", "message": "the recursion went too deep", "line": line_of(error)}
    return {"ok": False, "kind": type(error).__name__, "message": str(error), "line": line_of(error)}


def call(namespace, request_call):
    function = None
    for name in request_call["entries"]:
        if callable(namespace.get(name)):
            function = namespace[name]
            break
    if function is None:
        return {"ok": False, "kind": "missing", "message": "there is no function " + request_call["signature"], "line": 0}
    args = copy.deepcopy(request_call.get("args", []))
    try:
        value = function(*args)
    except BaseException as error:
        return problem_of(error)
    mutates = request_call.get("mutates", -1)
    if value is None and isinstance(mutates, int) and 0 <= mutates < len(args):
        value = args[mutates]
    result = {"ok": True, "value": plain(value)}
    if request_call.get("args_after"):
        result["args_after"] = plain(args)
    return result


def run(request):
    namespace = {"__name__": "task"}
    try:
        exec(compile(request["source"], FILE, "exec"), namespace)
    except BaseException as error:
        return dict(problem_of(error), status="broken")
    return {"status": "ok", "results": [call(namespace, request_call) for request_call in request["calls"]]}


def main():
    request = json.loads(sys.stdin.read())
    printed = Printed()
    with contextlib.redirect_stdout(printed):
        record = run(request)
    record.pop("ok", None)
    record["printed"] = printed.getvalue()
    emit(record)


main()
