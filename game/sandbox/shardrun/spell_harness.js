// The Shardrun spell harness for JavaScript (old ADR-0012, ADR-0013). Standard input is one JSON object: the shards'
// sources, the spells (lists of indexes into the shards), the starting bolts, the battle, and the limits. Each spell's
// result is printed as one line starting with the job's marker. SpellHarness (spell_harness.gd) builds the input and
// reads the lines back.
const DATA = JSON.parse(require("fs").readFileSync(0, "utf8"));
const SHARDS = DATA.shards;
const MARKER = DATA.marker;

// A program run (ADR-0012) asks for counts: how many times each loop in a card went round and how many times its
// functions were entered (recursion). A counted card is instrumented line by line, on the same lines, so a line number in
// an error is still the card's own: a counter after each loop's opening brace, one at the top of each named function,
// and array methods that take a callback (map, filter, ...) counted per call of the callback.
const COUNT = Boolean(DATA.count);
const METHODS = /\.(map|forEach|filter|reduce|some|every|find|findIndex|flatMap)\(/g;
let counts = { loops: {}, calls: {} };

// Where a loop's header ends: the index of the parenthesis closing `for (` or `while (`, or -1.
function headerEnd(text) {
  const start = /^\s*(for|while)\s*\(/.exec(text);
  if (!start) return -1;
  let depth = 0;
  for (let i = start[0].length - 1; i < text.length; i++) {
    if (text[i] === "(") depth++;
    else if (text[i] === ")" && --depth === 0) return i;
  }
  return -1;
}

// LEARN: every counter goes on the line it measures, never a line of its own, so error line numbers do not move.
function instrument(source) {
  return source.split("\n").map((text, index) => {
    const line = index + 1;
    let out = text;
    const end = headerEnd(text);
    const rest = end >= 0 ? text.slice(end + 1).trim() : "";
    if (end >= 0 && rest.startsWith("{")) {
      // for (...) { ...: count on entering the body.
      out = text.slice(0, end + 1) + text.slice(end + 1).replace("{", "{ __loop(" + line + ");");
    } else if (end >= 0 && rest !== "" && !rest.includes("//")) {
      // for (...) statement;  becomes  for (...) { __loop(n); statement; }  on the same line.
      out = text.slice(0, end + 1) + " { __loop(" + line + "); " + rest + " }";
    } else {
      const named = /^\s*function\s+([A-Za-z_$][\w$]*)\s*\(.*\)\s*\{\s*$/.exec(text);
      if (named) out = out.replace(/\{\s*$/, "{ __call(\"" + named[1] + "\");");
    }
    return out.replace(METHODS, (match, method) => ".__each(" + line + ", \"" + method + "\", ");
  }).join("\n");
}

function loop(line) {
  counts.loops[line] = (counts.loops[line] || 0) + 1;
}

function call(name) {
  counts.calls[name] = (counts.calls[name] || 0) + 1;
}

Object.defineProperty(Array.prototype, "__each", {
  value: function (line, method, fn, ...rest) {
    const counted = typeof fn === "function" ? (...args) => { loop(line); return fn(...args); } : fn;
    return this[method](counted, ...rest);
  },
  enumerable: false,
});

function load(shard) {
  // Each shard is compiled in its own function scope, fresh for every spell, so shards never collide or keep state.
  const source = COUNT ? instrument(shard.source) : shard.source;
  const fn = new Function("__loop", "__call", source + "\nreturn typeof " + shard.name + " === \"function\" ? " + shard.name + " : undefined;")(loop, call);
  if (typeof fn !== "function") throw new Error(shard.id + " does not define " + shard.name + "(bolts, battle)");
  return fn;
}

function runSpell(spell, battleJson, trace) {
  // A spell can bring its own starting bolts and battle (content validation runs every worked example in one job).
  let bolts = JSON.parse(JSON.stringify(spell.bolts !== undefined ? spell.bolts : DATA.bolts));
  for (const index of spell.shards) {
    const shard = SHARDS[index];
    let snapshot;
    let given;
    let returned;
    try {
      const fn = load(shard);
      given = bolts.length;
      counts = { loops: {}, calls: {} };
      const result = fn(bolts, JSON.parse(battleJson));
      if (!Array.isArray(result)) throw new TypeError(shard.name + " must return an array of bolts, not " + typeof result);
      returned = result.length;
      snapshot = JSON.stringify(result.slice(0, DATA.limit));
    } catch (error) {
      throw { shard, error };
    }
    bolts = JSON.parse(snapshot);
    const step = { shard: shard.id, given, returned, bolts: JSON.parse(snapshot).slice(0, DATA.traceLimit) };
    if (COUNT) {
      step.loops = counts.loops;
      step.calls = counts.calls[shard.name] || 0;
      // The whole volley the stage returned, summed (the trace keeps only its first bolts).
      step.power = 0;
      step.elements = {};
      for (const bolt of bolts) {
        if (bolt && typeof bolt.power === "number") step.power += bolt.power;
        if (bolt && typeof bolt.element === "string") step.elements[bolt.element] = (step.elements[bolt.element] || 0) + 1;
      }
    }
    trace.push(step);
  }
  return bolts;
}

const defaultBattle = JSON.stringify(DATA.battle);
for (const spell of DATA.spells) {
  const battleJson = spell.battle !== undefined ? JSON.stringify(spell.battle) : defaultBattle;
  const trace = [];
  let result;
  try {
    result = { spell: spell.id, ok: true, bolts: runSpell(spell, battleJson, trace), trace };
  } catch (failure) {
    const error = failure && failure.error;
    const name = error && error.name ? error.name : "Error";
    const message = error && error.message !== undefined ? error.message : String(error);
    result = { spell: spell.id, ok: false, error: name + ": " + message, shard: failure && failure.shard ? failure.shard.id : undefined, trace };
  }
  console.log(MARKER + JSON.stringify(result));
}
