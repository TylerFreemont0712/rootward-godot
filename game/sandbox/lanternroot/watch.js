// Lanternroot's Night Watch (ADR-0055), the JavaScript side: the twin of watch.py. Runs inside the sandbox beside the
// player's modules, reads its cases from standard input, and for each one requires the module, calls the exported
// function and compares what it returns.
//
// Input: {"modules": ["bakery", ...], "sources": {"bakery": "..."}, "cases": [{"id", "module", "function", "args", "expect"}, ...]}
// Output: one "@@lantern@@ <JSON>" line per case on standard output as soon as it ends; "@case <id>" on standard error
// before each case, so the game knows which case ran out of time. What the player's code logs is captured per case.
"use strict";

var MARK = "@@lantern@@ ";
var SHOWN = 300;
var PRINTED = 2000;
var stdout = process.stdout;
var stderr = process.stderr;
var realConsole = console;

function emit(record) {
  stdout.write(MARK + JSON.stringify(record) + "\n");
  stdout.flush();
}

// A value written the way the player would type it in JavaScript: "text" quoted, { key: value }, [1, 2].
function literal(value, depth) {
  if (typeof value === "string") return JSON.stringify(value);
  if (value === undefined) return "undefined";
  if (value === null || typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") return String(value);
  if (typeof value === "function") return "[Function " + (value.name || "anonymous") + "]";
  if (depth > 4) return "...";
  if (Array.isArray(value)) return "[" + value.map(function (item) { return literal(item, depth + 1); }).join(", ") + "]";
  if (value instanceof Map) return "Map(" + literal(Array.from(value.entries()), depth + 1) + ")";
  if (value instanceof Set) return "Set(" + literal(Array.from(value.values()), depth + 1) + ")";
  var keys = Object.keys(value);
  if (keys.length === 0) return "{}";
  return "{ " + keys.map(function (key) {
    var name = /^[A-Za-z_$][\w$]*$/.test(key) ? key : JSON.stringify(key);
    return name + ": " + literal(value[key], depth + 1);
  }).join(", ") + " }";
}

function show(value) {
  var text = literal(value, 0);
  return text.length <= SHOWN ? text : text.slice(0, SHOWN - 3) + "...";
}

function same(actual, expected) {
  if (typeof actual === "number" && typeof expected === "number") {
    return Math.abs(actual - expected) <= 1e-9 * Math.max(1, Math.abs(expected));
  }
  if (Array.isArray(actual) && Array.isArray(expected)) {
    if (actual.length !== expected.length) return false;
    for (var i = 0; i < actual.length; i++) if (!same(actual[i], expected[i])) return false;
    return true;
  }
  if (actual && expected && typeof actual === "object" && typeof expected === "object" && !Array.isArray(actual) && !Array.isArray(expected)) {
    var a = Object.keys(actual).sort(), e = Object.keys(expected).sort();
    if (!same(a, e)) return false;
    for (var k = 0; k < a.length; k++) if (!same(actual[a[k]], expected[a[k]])) return false;
    return true;
  }
  return actual === expected;
}

// LEARN: QuickJS names every function made by `new Function` "<input>" in a stack trace, so a trace alone cannot say
// which of the player's files an error came from. Each module is therefore loaded here with SPAN blank lines per place
// in the module list put before it: module 2's line 7 is reported as line 2 * SPAN + 7 (plus the two lines QuickJS's
// wrapper adds), and dividing by SPAN gives the file back. Blank lines cost the parser almost nothing.
var SPAN = 10000;
var WRAPPER = 2;

function where(error, modules) {
  var stack = String(error && error.stack || "");
  var found = /<input>:(\d+)/.exec(stack);
  if (!found) return ["", 0];
  var padded = Number(found[1]) - WRAPPER - 1;
  var index = Math.floor(padded / SPAN);
  if (index < 0 || index >= modules.length) return ["", 0];
  return [modules[index] + ".js", padded - index * SPAN + 1];
}

function loader(modules, sources) {
  var cache = {};
  function load(name) {
    if (cache[name]) return cache[name].exports;
    var mod = { exports: {} };
    cache[name] = mod;
    var padding = new Array(modules.indexOf(name) * SPAN + 1).join("\n");
    try {
      var factory = new Function("exports", "require", "module", "__filename", "__dirname", padding + sources[name]);
      factory(mod.exports, playerRequire, mod, name + ".js", "");
    } catch (error) {
      delete cache[name];
      throw error;
    }
    return mod.exports;
  }
  function playerRequire(request) {
    var local = /^\.\/([A-Za-z_]\w*)(?:\.js)?$/.exec(request);
    if (local && Object.prototype.hasOwnProperty.call(sources, local[1])) return load(local[1]);
    return require(request);
  }
  return load;
}

function capture(lines) {
  function into() {
    var parts = [];
    for (var i = 0; i < arguments.length; i++) parts.push(typeof arguments[i] === "string" ? arguments[i] : literal(arguments[i], 0));
    lines.push(parts.join(" "));
  }
  return { log: into, info: into, debug: into, warn: into, error: into };
}

function main() {
  var request = JSON.parse(require("fs").readFileSync(0, "utf8"));
  var modules = request.modules;
  var load = loader(modules, request.sources);
  var failedImports = {};
  request.cases.forEach(function (testCase) {
    stderr.write("@case " + testCase.id + "\n");
    stderr.flush();
    var record = {
      id: testCase.id,
      call: testCase["function"] + "(" + testCase.args.map(show).join(", ") + ")",
      expected: show(testCase.expect)
    };
    var lines = [];
    globalThis.console = capture(lines);
    try {
      if (modules.indexOf(testCase.module) === -1) {
        record.status = "missing";
        record.message = "there is no " + testCase.module + ".js yet";
      } else {
        if (failedImports[testCase.module]) throw failedImports[testCase.module];
        var exported;
        try {
          exported = load(testCase.module);
        } catch (error) {
          failedImports[testCase.module] = error;
          throw error;
        }
        var fn = exported && exported[testCase["function"]];
        if (typeof fn !== "function") {
          record.status = "missing";
          record.message = testCase.module + ".js does not export a function " + testCase["function"] +
            " (module.exports." + testCase["function"] + " = " + testCase["function"] + ";)";
        } else {
          var value = fn.apply(null, JSON.parse(JSON.stringify(testCase.args)));
          record.actual = show(value);
          record.status = same(value, testCase.expect) ? "pass" : "fail";
        }
      }
    } catch (error) {
      record.status = "error";
      record.kind = error && error.name ? String(error.name) : "Error";
      record.message = error && error.message !== undefined ? String(error.message) : String(error);
      if (record.kind === "RangeError" && /stack/i.test(record.message)) record.message = "the recursion went too deep";
      var place = where(error, modules);
      record.file = place[0];
      record.line = place[1];
    }
    globalThis.console = realConsole;
    var text = lines.length ? lines.join("\n") + "\n" : "";
    record.printed = text.length <= PRINTED ? text : text.slice(0, PRINTED) + "\n...";
    emit(record);
  });
}

main();
