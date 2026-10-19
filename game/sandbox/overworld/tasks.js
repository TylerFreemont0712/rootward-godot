// Lanternroot's tasks (Concept/v0.4), the JavaScript side: the twin of tasks.py. Calls the player's function once for
// each call, in one job; each call names its function (a JavaScript call may also find the Python name).
//
// Input: {"source": "...", "calls": [{"entries": ["menuItems", "menu_items"], "signature": "menuItems(built)",
//         "args": [[...]], "mutates": -1}, ...]}
// Output: one "@@task@@ <JSON>" line, the same record as tasks.py's.
"use strict";

var MARK = "@@task@@ ";
// QuickJS numbers a `new Function` body from 1 after the two lines of its own wrapper.
var WRAPPER = 2;
var PRINTED = 600;

function emit(record) {
  process.stdout.write("\n" + MARK + JSON.stringify(record) + "\n");
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
  return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
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
  // Every name any call may use, looked up once after the player's code has run.
  var names = [];
  request.calls.forEach(function (c) {
    c.entries.forEach(function (name) {
      if (names.indexOf(name) < 0 && /^[A-Za-z_$][A-Za-z0-9_$]*$/.test(name)) names.push(name);
    });
  });
  var found;
  try {
    var lookups = names.map(function (name) {
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
  var functions = {};
  names.forEach(function (name, i) { functions[name] = found[i]; });
  var results = request.calls.map(function (c) {
    var fn;
    for (var i = 0; i < c.entries.length; i++) {
      if (typeof functions[c.entries[i]] === "function") { fn = functions[c.entries[i]]; break; }
    }
    if (typeof fn !== "function") {
      return { ok: false, kind: "missing", message: "there is no function " + c.signature, line: 0 };
    }
    var args = copy(c.args || []);
    try {
      var value = fn.apply(null, args);
      var mutates = typeof c.mutates === "number" ? c.mutates : -1;
      if (value === undefined && mutates >= 0 && mutates < args.length) value = args[mutates];
      var result = { ok: true, value: plain(value) };
      if (c.args_after) result.args_after = plain(args);
      return result;
    } catch (error) {
      return problemOf(error);
    }
  });
  return { status: "ok", results: results };
}

main();
