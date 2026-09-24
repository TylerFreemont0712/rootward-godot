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
(function (std, os, args) {
  "use strict";
  var RUNTIME_ERROR = 70, COMPILE_ERROR = 71, OUT_OF_MEMORY = 72;
  var WORK = "/work";
  var entry = args[1];
  var out = std.out, err = std.err;

  function inspect(value) {
    if (typeof value === "string") return value;
    if (value === undefined || value === null || typeof value === "number" || typeof value === "boolean" || typeof value === "bigint") return String(value);
    if (typeof value === "function") return "[Function " + (value.name || "anonymous") + "]";
    if (value instanceof Error) return value.name + ": " + value.message;
    if (value instanceof Map) return "Map(" + value.size + ") " + inspect(Array.from(value.entries()));
    if (value instanceof Set) return "Set(" + value.size + ") " + inspect(Array.from(value.values()));
    try {
      var json = JSON.stringify(value);
      return json === undefined ? String(value) : json;
    } catch (error) {
      return String(value);
    }
  }

  function printTo(stream, list) {
    var parts = [];
    for (var i = 0; i < list.length; i++) parts.push(inspect(list[i]));
    stream.puts(parts.join(" ") + "\n");
  }

  function Exit(code) {
    this.name = "Exit";
    this.message = "process.exit(" + code + ")";
    this.exitCode = code;
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
    stdout: { write: function (text) { out.puts(String(text)); return true; } },
    stderr: { write: function (text) { err.puts(String(text)); return true; } },
    exit: function (code) { throw new Exit(code === undefined ? 0 : code); }
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
    var text = error && error.stack ? String(error.name) + ": " + error.message + "\n" + error.stack : String(error);
    return text.split("<evalScript>").join(entry);
  }

  var source = std.loadFile(WORK + "/" + entry);
  if (typeof source !== "string") {
    err.puts("cannot read " + entry + "\n");
    finish(RUNTIME_ERROR);
  }
  try {
    std.evalScript(source);
  } catch (error) {
    if (error instanceof Exit) finish(error.exitCode === 0 ? 0 : RUNTIME_ERROR);
    if (error && error.name === "InternalError" && /out of memory/.test(error.message)) {
      err.puts("InternalError: out of memory\n");
      finish(OUT_OF_MEMORY);
    }
    err.puts(describe(error) + "\n");
    finish(error && error.name === "SyntaxError" && /<evalScript>:\d+:\d+\s*$/.test(String(error.stack).split("\n")[0]) ? COMPILE_ERROR : RUNTIME_ERROR);
  }
  finish(0);
})(std, os, scriptArgs.slice(0));
