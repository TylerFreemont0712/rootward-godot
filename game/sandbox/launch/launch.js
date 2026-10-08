// Runs one JavaScript program inside the sandbox: `qjs --std --script launch.js <entry>`, with the job's files in /work
// and its standard input in /work/.rootward/stdin. Copied into every job by Sandbox (game/sandbox/sandbox.gd).
//
// It gives the program a small Node-shaped world: console, process (argv, env, exit, stdout/stderr.write),
// require("fs").readFileSync(0) for standard input, and require() of the job's own files by relative path. No
// timers, network, or other modules. The outcome is the exit code: 0 ran to the end, 70 threw or exited non-zero,
// 71 did not compile, 72 ran out of memory.
//
// LEARN: everything is set up inside one function, and the host objects (std, os) are captured in its closure before
// the player's code runs, so replacing globals cannot break the launcher's own reporting.
// LEARN: the built-ins the printing path calls are captured here too, before the player's code runs. A program can replace
// Array.prototype.push, join or String, or a global such as JSON or Map, and the line the launcher prints would then not be
// what the harness printed. Each capture is called through Reflect.apply, captured as well: `call` is looked up on the
// function at call time, so a program that rebinds it could reach the printing that way.
(function (std, os, args) {
  "use strict";
  var RUNTIME_ERROR = 70, COMPILE_ERROR = 71, OUT_OF_MEMORY = 72;
  var WORK = "/work";
  var entry = args[1];
  var out = std.out, err = std.err;
  var reflectApply = Reflect.apply;
  var arrayPush = Array.prototype.push, arrayJoin = Array.prototype.join;
  var stringSplit = String.prototype.split, regexTest = RegExp.prototype.test;
  var stringOf = String, jsonStringify = JSON.stringify;
  var ErrorCtor = Error, MapCtor = Map, SetCtor = Set;
  var mapForEach = Map.prototype.forEach, setForEach = Set.prototype.forEach;
  // LEARN: `value instanceof C` reads C[Symbol.hasInstance] when it runs, and a program can define its own on Error, Map
  // or Set. So each check below calls the built-in that `instanceof` uses by default, with the constructor as receiver.
  var hasInstance = Function.prototype[Symbol.hasInstance];

  function inspect(value) {
    if (typeof value === "string") return value;
    if (value === undefined || value === null || typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") return stringOf(value);
    if (typeof value === "function") return "[Function " + (value.name || "anonymous") + "]";
    if (reflectApply(hasInstance, ErrorCtor, [value])) return value.name + ": " + value.message;
    if (reflectApply(hasInstance, MapCtor, [value])) return listedMap(value);
    if (reflectApply(hasInstance, SetCtor, [value])) return listedSet(value);
    try {
      var json = jsonStringify(value);
      return json === undefined ? stringOf(value) : json;
    } catch (error) {
      return stringOf(value);
    }
  }

  // A Map or a Set is listed by its own forEach: Array.from over its iterator would call the iterator a program can replace.
  function listedMap(map) {
    var pairs = [];
    reflectApply(mapForEach, map, [function (v, k) { reflectApply(arrayPush, pairs, [[k, v]]); }]);
    return "Map(" + pairs.length + ") " + inspect(pairs);
  }

  function listedSet(set) {
    var items = [];
    reflectApply(setForEach, set, [function (v) { reflectApply(arrayPush, items, [v]); }]);
    return "Set(" + items.length + ") " + inspect(items);
  }

  function printTo(stream, list) {
    var parts = [];
    for (var i = 0; i < list.length; i++) reflectApply(arrayPush, parts, [inspect(list[i])]);
    stream.puts(reflectApply(arrayJoin, parts, [" "]) + "\n");
  }

  // LEARN: `instanceof Exit` reads Exit.prototype, which a program reaches through any error's constructor, so a thrown
  // object with that prototype and an exitCode of 0 would exit 0. The exits the launcher makes are kept in a WeakSet of
  // this closure instead, and a thrown object is an exit only if it is one of them. Each exit is frozen, so the program
  // cannot rewrite its exitCode after throwing it.
  var weakSetAdd = WeakSet.prototype.add, weakSetHas = WeakSet.prototype.has, objectFreeze = Object.freeze;
  var exits = new WeakSet();

  function makeExit(code) {
    var exit = objectFreeze({ name: "Exit", message: "process.exit(" + code + ")", exitCode: code });
    reflectApply(weakSetAdd, exits, [exit]);
    return exit;
  }

  var stdinText = null;
  var fsShim = {
    readFileSync: function (path) {
      if (path === 0 || path === "/dev/stdin") {
        if (stdinText === null) stdinText = std.loadFile(WORK + "/.rootward/stdin") || "";
        return stdinText;
      }
      throw new Error("In the sandbox fs.readFileSync can only read standard input: fs.readFileSync(0, \"utf8\")");
    }
  };

  function dirname(path) {
    var slash = path.lastIndexOf("/");
    return slash === -1 ? "" : path.slice(0, slash);
  }

  function resolvePath(fromDir, request) {
    var parts = fromDir === "" ? [] : fromDir.split("/");
    var pieces = request.split("/");
    for (var i = 0; i < pieces.length; i++) {
      var piece = pieces[i];
      if (piece === "" || piece === ".") continue;
      if (piece === "..") {
        if (parts.length === 0) return null;
        parts.pop();
      } else parts.push(piece);
    }
    return parts.join("/");
  }

  var moduleCache = {};
  function makeRequire(fromDir) {
    return function require(request) {
      if (request === "fs" || request === "node:fs") return fsShim;
      if (request.slice(0, 2) === "./" || request.slice(0, 3) === "../") {
        var base = resolvePath(fromDir, request);
        if (base !== null) {
          var candidates = [base, base + ".js", base + "/index.js"];
          for (var i = 0; i < candidates.length; i++) {
            var path = candidates[i];
            if (moduleCache[path]) return moduleCache[path].exports;
            var source = std.loadFile(WORK + "/" + path);
            if (typeof source !== "string") continue;
            var mod = { exports: {} };
            moduleCache[path] = mod;
            var factory = new Function("exports", "require", "module", "__filename", "__dirname", source);
            factory(mod.exports, makeRequire(dirname(path)), mod, path, dirname(path));
            return mod.exports;
          }
        }
      }
      throw new Error("Cannot find module '" + request + "'. The sandbox has no network, no child processes, and no files except your own.");
    };
  }

  var mainModule = { exports: {} };
  globalThis.console = {
    log: function () { printTo(out, arguments); },
    info: function () { printTo(out, arguments); },
    debug: function () { printTo(out, arguments); },
    warn: function () { printTo(err, arguments); },
    error: function () { printTo(err, arguments); }
  };
  globalThis.process = {
    argv: ["node", entry].concat(args.slice(2)),
    env: {},
    platform: "rootward-sandbox",
    // flush() is not Node's: it pushes buffered output out now, for a harness whose run may be stopped mid-way.
    stdout: { write: function (text) { out.puts(stringOf(text)); return true; }, flush: function () { out.flush(); } },
    stderr: { write: function (text) { err.puts(stringOf(text)); return true; }, flush: function () { err.flush(); } },
    exit: function (code) { throw makeExit(code === undefined ? 0 : code); }
  };
  globalThis.require = makeRequire(dirname(entry));
  globalThis.module = mainModule;
  globalThis.exports = mainModule.exports;
  globalThis.__filename = entry;
  globalThis.__dirname = dirname(entry);
  delete globalThis.std;
  delete globalThis.os;
  delete globalThis.bjson;
  delete globalThis.scriptArgs;

  function finish(code) {
    out.flush();
    err.flush();
    std.exit(code);
  }

  function describe(error) {
    // QuickJS names code from evalScript "<evalScript>"; the player knows it by their file's name.
    var text = error && error.stack ? stringOf(error.name) + ": " + error.message + "\n" + error.stack : stringOf(error);
    return reflectApply(arrayJoin, reflectApply(stringSplit, text, ["<evalScript>"]), [entry]);
  }

  var source = std.loadFile(WORK + "/" + entry);
  if (typeof source !== "string") {
    err.puts("cannot read " + entry + "\n");
    finish(RUNTIME_ERROR);
  }
  try {
    std.evalScript(source);
  } catch (error) {
    if (reflectApply(weakSetHas, exits, [error])) finish(error.exitCode === 0 ? 0 : RUNTIME_ERROR);
    if (error && error.name === "InternalError" && reflectApply(regexTest, /out of memory/, [error.message])) {
      err.puts("InternalError: out of memory\n");
      finish(OUT_OF_MEMORY);
    }
    err.puts(describe(error) + "\n");
    finish(error && error.name === "SyntaxError" && reflectApply(regexTest, /<evalScript>:\d+:\d+\s*$/, [reflectApply(stringSplit, stringOf(error.stack), ["\n"])[0]]) ? COMPILE_ERROR : RUNTIME_ERROR);
  }
  finish(0);
})(std, os, scriptArgs.slice(0));
