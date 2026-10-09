// Lanternroot's boots (ADR-0061), the JavaScript side: the twin of boots.py. Calls the player's onKey(key, player)
// once for every key on every tile, so the town walks on the answers without waiting for the sandbox at each step.
//
// Input: {"source": "...", "keys": ["up", ...], "width": 40, "height": 30}
// Output: one "@@boots@@ <JSON>" line, the same record as boots.py's.
"use strict";

var MARK = "@@boots@@ ";
var ENTRY = "onKey";
var RECHECK = 12;
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

function kindOf(error) {
  return error && error.name ? String(error.name) : "Error";
}

function messageOf(error) {
  var message = error && error.message !== undefined ? String(error.message) : String(error);
  return kindOf(error) === "RangeError" && /stack/i.test(message) ? "the recursion went too deep" : message;
}

// What the code logs is kept out of the way (it runs thousands of times); the start of it comes back as "printed".
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
  var onKey;
  try {
    var factory = new Function(request.source + "\nreturn typeof " + ENTRY + " === \"function\" ? " + ENTRY + " : undefined;");
    onKey = factory();
  } catch (error) {
    return { status: "broken", kind: kindOf(error), message: messageOf(error), line: lineOf(error) };
  }
  if (typeof onKey !== "function") {
    return { status: "broken", kind: "missing", message: "there is no function " + ENTRY + "(key, player)", line: 0 };
  }
  var keys = request.keys, width = request.width, height = request.height;
  var errors = [], seen = {};
  var xs = [], ys = [], marks = [];

  function step(key, cx, cy) {
    var player = { x: cx, y: cy };
    var problem;
    try {
      onKey(key, player);
      if (!Number.isInteger(player.x) || !Number.isInteger(player.y)) {
        throw new TypeError("player.x and player.y must be whole numbers, not " + String(player.x) + " and " + String(player.y));
      }
      return [player.x, player.y, -1];
    } catch (error) {
      problem = [kindOf(error), messageOf(error), lineOf(error)];
    }
    var id = problem.join("\u0000");
    if (!Object.prototype.hasOwnProperty.call(seen, id)) {
      seen[id] = errors.length;
      errors.push({ kind: problem[0], message: problem[1], line: problem[2] });
    }
    return [cx, cy, seen[id]];
  }

  keys.forEach(function (key) {
    for (var cy = 0; cy < height; cy++) {
      for (var cx = 0; cx < width; cx++) {
        var result = step(key, cx, cy);
        xs.push(result[0]);
        ys.push(result[1]);
        marks.push(result[2]);
      }
    }
  });
  var remembers = false;
  var total = xs.length;
  for (var i = total - 1; i > Math.max(-1, total - 1 - RECHECK); i--) {
    var k = Math.floor(i / (width * height));
    var rest = i - k * width * height;
    var again = step(keys[k], rest % width, Math.floor(rest / width));
    if (again[0] !== xs[i] || again[1] !== ys[i]) {
      remembers = true;
      break;
    }
  }
  return { status: "ok", x: xs, y: ys, error: marks, errors: errors, remembers: remembers };
}

main();
