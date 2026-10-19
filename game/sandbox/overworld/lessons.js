// Lanternroot's lessons (ADR-0061), the JavaScript side: the twin of lessons.py. Calls the player's save(player) or
// lightAll(lamps) once on each case, in one job.
//
// Input: {"lesson": "memory" | "lamps", "entries": ["lightAll", "light_all"], "signature": "lightAll(lamps)",
//         "source": "...", "cases": [...]}
// Output: one "@@lesson@@ <JSON>" line, the same record as lessons.py's.
"use strict";

var MARK = "@@lesson@@ ";
// QuickJS numbers a `new Function` body from 1 after the two lines of its own wrapper.
var WRAPPER = 2;
var PRINTED = 600;

function emit(record) {
  process.stdout.write(MARK + JSON.stringify(record) + "\n");
  process.stdout.flush();
}

function lineOf(error) {
  var found = /<input>:(\d+)/.exec(String(error && error.stack || ""));
  return found ? Math.max(0, Number(found[1]) - WRAPPER) : 0;
}

function problemOf(error) {
  var kind = error && error.name ? String(error.name) : "Error";
  var message = error && error.message !== undefined ? String(error.message) : String(error);
  if (kind === "RangeError" && /stack/i.test(message)) message = "the recursion went too deep";
  return { ok: false, kind: kind, message: message, line: lineOf(error) };
}

// What the code gave back, as JSON can carry it. Nothing given back (undefined) is null.
function plain(value) {
  if (value === undefined) return null;
  try {
    var text = JSON.stringify(value);
    return text === undefined ? String(value) : JSON.parse(text);
  } catch (error) {
    return String(value);
  }
}

function copy(value) {
  return JSON.parse(JSON.stringify(value));
}

function call(lesson, fn, testCase) {
  if (lesson === "lamps") {
    var lamps = copy(testCase);
    var given = fn(lamps);
    return Array.isArray(given) ? given : lamps;
  }
  return fn(copy(testCase));
}

function main() {
  var request = JSON.parse(require("fs").readFileSync(0, "utf8"));
  var printed = "";
  function keep() {
    if (printed.length >= PRINTED) return;
    printed += Array.prototype.map.call(arguments, String).join(" ") + "\n";
    printed = printed.slice(0, PRINTED);
  }
  var realConsole = console;
  globalThis.console = { log: keep, info: keep, debug: keep, warn: keep, error: keep };
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
    var broken = problemOf(error);
    broken.status = "broken";
    delete broken.ok;
    return broken;
  }
  var fn = found.filter(function (f) { return typeof f === "function"; })[0];
  if (typeof fn !== "function") {
    return { status: "broken", kind: "missing", message: "there is no function " + request.signature, line: 0 };
  }
  var results = request.cases.map(function (testCase) {
    try {
      return { ok: true, value: plain(call(request.lesson, fn, testCase)) };
    } catch (error) {
      return problemOf(error);
    }
  });
  return { status: "ok", results: results };
}

main();
