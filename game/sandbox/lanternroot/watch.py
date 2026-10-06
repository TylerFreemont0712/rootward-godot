# Lanternroot's Night Watch (ADR-0055), the Python side: runs inside the sandbox beside the player's modules, reads its
# cases from standard input, and for each one imports the module, calls the function and compares what it returns.
#
# Input: {"modules": ["bakery", ...], "cases": [{"id", "module", "function", "args", "expect"}, ...]}
# Output: one line per case on standard output, "@@lantern@@ " and a JSON record, written as soon as the case ends, so
# a case that never ends still leaves the ones before it reported. Before each case "@case <id>" goes to standard
# error, which is how the game knows which case ran out of time.
#
# What the player's code prints is captured per case and reported with it, never mixed into the records.
import contextlib
import copy
import importlib
import io
import json
import math
import os
import sys
import traceback

MARK = "@@lantern@@ "
SHOWN = 300
PRINTED = 2000
OUT = sys.stdout
ERR = sys.stderr


class Missing(Exception):
    """The module or function a case asks for is not there (not the player's own KeyError or IndexError)."""


def emit(record):
    OUT.write(MARK + json.dumps(record) + "\n")
    OUT.flush()


def plain(value):
    """A returned value as JSON would carry it: tuples are lists, dictionary keys are text."""
    if isinstance(value, (list, tuple)):
        return [plain(item) for item in value]
    if isinstance(value, dict):
        return {key if isinstance(key, str) else str(key): plain(item) for key, item in value.items()}
    return value


def same(actual, expected):
    # True is not 1 here, even though Python says True == 1: a test asking for a number wants a number.
    if isinstance(actual, bool) or isinstance(expected, bool):
        return type(actual) is type(expected) and actual == expected
    if isinstance(actual, (int, float)) and isinstance(expected, (int, float)):
        return math.isclose(actual, expected, rel_tol=1e-9, abs_tol=1e-9)
    if isinstance(actual, list) and isinstance(expected, list):
        return len(actual) == len(expected) and all(same(a, e) for a, e in zip(actual, expected))
    if isinstance(actual, dict) and isinstance(expected, dict):
        return actual.keys() == expected.keys() and all(same(actual[k], expected[k]) for k in actual)
    return type(actual) is type(expected) and actual == expected


def show(value):
    text = repr(value)
    return text if len(text) <= SHOWN else text[: SHOWN - 3] + "..."


def call_text(case):
    return "%s(%s)" % (case["function"], ", ".join(show(arg) for arg in case["args"]))


def where(error, player_files):
    """The player's file and line the error happened on: the innermost frame in one of their modules."""
    if isinstance(error, SyntaxError) and error.filename:
        return os.path.basename(error.filename), error.lineno or 0
    for frame in reversed(traceback.extract_tb(error.__traceback__)):
        name = os.path.basename(frame.filename)
        if name in player_files:
            return name, frame.lineno or 0
    return "", 0


def main():
    request = json.loads(sys.stdin.read())
    player_files = {name + ".py" for name in request["modules"]}
    failed_imports = {}
    for case in request["cases"]:
        ERR.write("@case %s\n" % case["id"])
        ERR.flush()
        record = {"id": case["id"], "call": call_text(case), "expected": show(case["expect"])}
        printed = io.StringIO()
        try:
            with contextlib.redirect_stdout(printed):
                if case["module"] in failed_imports:
                    raise failed_imports[case["module"]]
                try:
                    module = importlib.import_module(case["module"])
                except ModuleNotFoundError as error:
                    if error.name == case["module"]:
                        record.update(status="missing", message="there is no %s.py yet" % case["module"])
                        raise Missing from None
                    failed_imports[case["module"]] = error
                    raise
                except BaseException as error:
                    failed_imports[case["module"]] = error
                    raise
                function = getattr(module, case["function"], None)
                if not callable(function):
                    record.update(
                        status="missing",
                        message="%s.py has no function %s" % (case["module"], case["function"]),
                    )
                    raise Missing
                value = function(*copy.deepcopy(case["args"]))
            record["actual"] = show(value)
            record["status"] = "pass" if same(plain(value), case["expect"]) else "fail"
        except Missing:
            pass
        except RecursionError as error:
            record.update(status="error", kind="RecursionError", message="the recursion went too deep")
            record["file"], record["line"] = where(error, player_files)
        except BaseException as error:
            record.update(status="error", kind=type(error).__name__, message=str(error))
            record["file"], record["line"] = where(error, player_files)
        text = printed.getvalue()
        record["printed"] = text if len(text) <= PRINTED else text[:PRINTED] + "\n..."
        emit(record)


main()
