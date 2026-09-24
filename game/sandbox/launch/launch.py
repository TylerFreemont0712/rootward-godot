# Runs one Python program inside the sandbox: `python launch.py <entry>`, with the job's files in /work and its standard
# input in /work/.rootward/stdin. Copied into every job by Sandbox (game/sandbox/sandbox.gd).
#
# The outcome is the exit code, which Sandbox reads: 0 ran to the end, 70 raised or exited non-zero, 71 did not compile,
# 72 ran out of memory. The program's own output goes straight to stdout and stderr; Sandbox caps how much it keeps.
import io
import linecache
import os
import sys
import traceback

RUNTIME_ERROR, COMPILE_ERROR, OUT_OF_MEMORY = 70, 71, 72
WORK = "/work"
LAUNCHER = __file__


def report(error):
    """The traceback as Python prints it, minus this launcher's own frames."""
    info = traceback.TracebackException.from_exception(error)
    info.stack = traceback.StackSummary.from_list([f for f in info.stack if f.filename != LAUNCHER])
    sys.stderr.write("".join(info.format()))


def main():
    entry = sys.argv[1]
    with open(os.path.join(WORK, ".rootward", "stdin"), encoding="utf-8") as handle:
        sys.stdin = io.StringIO(handle.read())
    with open(os.path.join(WORK, entry), encoding="utf-8") as handle:
        source = handle.read()
    os.chdir(WORK)
    sys.path.insert(0, WORK)
    sys.argv = [entry] + sys.argv[2:]
    # So tracebacks can quote the player's lines.
    linecache.cache[entry] = (len(source), None, source.splitlines(True), entry)
    try:
        code = compile(source, entry, "exec")
    except SyntaxError as error:
        report(error)
        return COMPILE_ERROR
    try:
        exec(code, {"__name__": "__main__", "__file__": entry, "__builtins__": __builtins__})
    except SystemExit as error:
        if isinstance(error.code, str):
            sys.stderr.write(error.code + "\n")
            return RUNTIME_ERROR
        return 0 if error.code in (None, 0) else RUNTIME_ERROR
    except MemoryError:
        sys.stderr.write("MemoryError: out of memory\n")
        return OUT_OF_MEMORY
    except RecursionError as error:
        sys.stderr.write("RecursionError: the recursion went too deep (is a base case missing?)\n")
        return RUNTIME_ERROR
    except BaseException as error:
        report(error)
        return RUNTIME_ERROR
    return 0


if __name__ == "__main__":
    status = main()
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(status)
