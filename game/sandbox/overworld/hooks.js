// Lanternroot's things (ADR-0061, TownThings), the JavaScript side: the twin of hooks.py. Calls the player's
// on_use(thing, player) (or onUse) once, in one job, and writes one record.
//
// Input: {"entries": ["on_use", "onUse"], "source": "...", "thing": {"id", "fields", "keys", "text", "source"},
//         "player": {"x", "y", "map", "facing", "name"}}. `entries` names the hook's functions (on_step, on_change...);
//         thing.source is what a linked thing changed, for on_change ({id, fields, changed}; {} otherwise).
// Output: one "@@thing@@ <JSON>" line after a newline, the same record as hooks.py's.
"use strict";

var MARK = "@@thing@@ ";
// What a missing hook is called, from the names the request gives.
function missing(entries) {
  return "there is no function " + entries.map(function (name) { return name + "(thing, player)"; }).join(" or ");
}
// QuickJS numbers a `new Function` body from 1 after the two lines of its own wrapper.
var WRAPPER = 2;
var PRINTED = 600;
// Kept before the code runs, so the code cannot change how the record is written.
var stringify = JSON.stringify;
var parse = JSON.parse;

function emit(record) {
  process.stdout.write("\n" + MARK + stringify(record) + "\n");
  process.stdout.flush();
}

function lineOf(error) {
  var found = /<input>:(\d+)/.exec(String(error && error.stack || ""));
  return found ? Math.max(0, Number(found[1]) - WRAPPER) : 0;
}

function kindOf(error) {
  return error && error.name ? String(error.name) : "Error";
}

function messageOf(error) {
  var message = error && error.message !== undefined ? String(error.message) : String(error);
  return kindOf(error) === "RangeError" && /stack/i.test(message) ? "the recursion went too deep" : message;
}

// QuickJS reports running out of memory as an InternalError that the code could catch. It is passed on instead, so the
// run ends as out of memory (the launcher's exit 72), as it does in Python (see hooks.py).
function outOfMemory(error) {
  return kindOf(error) === "InternalError" && /out of memory/.test(messageOf(error));
}

// What the code gave back, as JSON can carry it. Nothing given back (undefined) is null.
function plain(value) {
  if (value === undefined) return null;
  try {
    var text = stringify(value);
    return text === undefined ? String(value) : parse(text);
  } catch (error) {
    return String(value);
  }
}

// What the code prints goes to standard output as it is (Sandbox caps it), and the start of it is kept for the record.
function main() {
  var request = parse(require("fs").readFileSync(0, "utf8"));
  var realConsole = console;
  var printed = "";
  function keep(args) {
    if (printed.length < PRINTED) {
      printed = (printed + Array.prototype.map.call(args, String).join(" ") + "\n").slice(0, PRINTED);
    }
  }
  function through(method) {
    return function () {
      keep(arguments);
      return realConsole[method].apply(realConsole, arguments);
    };
  }
  globalThis.console = {
    log: through("log"),
    info: through("info"),
    debug: through("debug"),
    warn: through("warn"),
    error: through("error")
  };
  var record = run(request);
  globalThis.console = realConsole;
  record.printed = printed;
  emit(record);
}

function run(request) {
  var found;
  try {
    var lookups = request.entries.map(function (name) {
      return "typeof " + name + " === \"function\" ? " + name + " : undefined";
    });
    var factory = new Function(request.source + "\nreturn [" + lookups.join(", ") + "];");
    found = factory();
  } catch (error) {
    if (outOfMemory(error)) throw error;
    var broken = { kind: kindOf(error), message: messageOf(error), line: lineOf(error) };
    return { status: "broken", ok: false, kind: broken.kind, message: broken.message, line: broken.line };
  }
  var fn = null;
  for (var i = 0; i < found.length; i++) {
    if (typeof found[i] === "function") {
      fn = found[i];
      break;
    }
  }
  if (fn === null) {
    return { status: "broken", ok: false, kind: "missing", message: missing(request.entries), line: 0 };
  }
  var thing = request.thing || {};
  var where = request.player || {};
  var player = { x: where.x, y: where.y, map: where.map, facing: where.facing, name: where.name };
  var value;
  try {
    var shown = { id: thing.id, fields: thing.fields || {}, keys: thing.keys || [], text: thing.text || "", source: thing.source || {} };
    value = fn(shown, player);
  } catch (error) {
    if (outOfMemory(error)) throw error;
    return { status: "ok", ok: false, kind: kindOf(error), message: messageOf(error), line: lineOf(error) };
  }
  return { status: "ok", ok: true, value: plain(value) };
}

main();
