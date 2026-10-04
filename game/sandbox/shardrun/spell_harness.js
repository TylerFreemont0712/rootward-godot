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

function load(shard, counted = COUNT) {
  // Each shard is compiled in its own function scope, fresh for every spell, so shards never collide or keep state.
  // A hook is never counted: its loops are not the card's.
  const source = counted ? instrument(shard.source) : shard.source;
  const fn = new Function("__loop", "__call", source + "\nreturn typeof " + shard.name + " === \"function\" ? " + shard.name + " : undefined;")(loop, call);
  if (typeof fn !== "function") throw new Error(shard.id + " does not define " + shard.name + "(bolts, battle)");
  return fn;
}

// A program run's imports may hook a role (ADR-0018): the import's own function runs on the volley before or after
// every card of that role (heapq hands each strike the strongest bolt first; bisect sorts what each source made).
const HOOKS = DATA.hooks || [];

function hooked(when, role, bolts, battleJson) {
  for (const hook of HOOKS) {
    if (hook.when !== when || hook.role !== role) continue;
    const shard = SHARDS[hook.shard];
    try {
      const result = load(shard, false)(bolts, JSON.parse(battleJson));
      if (!Array.isArray(result)) throw new TypeError(shard.name + " must return an array of bolts, not " + typeof result);
      bolts = JSON.parse(JSON.stringify(result.slice(0, DATA.limit)));
    } catch (error) {
      throw { shard, error };
    }
  }
  return bolts;
}

function workUnits(complexity, size, cap = 0, height = 1) {
  if (cap > 0) size = Math.min(size, cap);
  const maximum = 2 ** 30;
  switch (complexity) {
    case "constant": return 1;
    case "logarithmic": return Math.ceil(Math.log2(size + 1));
    case "linearithmic": return Math.ceil(size * Math.log2(size + 1));
    case "quadratic": return Math.min(maximum, size * size);
    case "exponential": return size >= 30 ? maximum : Math.min(maximum, 2 ** size);
    case "pseudo": return Math.min(maximum, size * Math.max(1, height));
    default: return size;
  }
}

function isSorted(bolts) {
  if (bolts.some(bolt => !bolt || typeof bolt !== "object" || typeof bolt.power !== "number")) return false;
  return bolts.every((bolt, i) => i === 0 || (bolts[i - 1].power || 0) <= (bolt.power || 0));
}

// A body is an interpreter operation: cards continue to be plain algorithms which know nothing about their owner.
class Execution {
  constructor(spell, battleJson, trace) {
    this.indexes = spell.shards;
    this.battleJson = battleJson;
    this.trace = trace;
    this.options = DATA.execution || {};
    this.extended = DATA.execution !== undefined;
    this.order = "sorted";
    this.work = 0;
    this.discount = 1;
    for (const rule of this.options.small_program_work || []) {
      if (this.indexes.length && this.indexes.length <= rule.max_cards) this.discount *= rule.factor;
    }
  }

  hooks(when, shard, bolts) {
    bolts = hooked(when, shard.role, bolts, this.battleJson);
    for (const hook of HOOKS) {
      if (hook.when === when && hook.role === shard.role) this.order = SHARDS[hook.shard].makes || this.order;
    }
    return bolts;
  }

  bill(shard, slot, given, returned, measured, sortedInput) {
    let complexity = shard.complexity || "linear";
    if (shard.worst_case && shard.worst_case.input === (sortedInput ? "sorted" : "unsorted")) complexity = shard.worst_case.complexity;
    complexity = (this.options.role_complexity || {})[shard.role] || complexity;
    const height = shard.height === undefined ? (this.options.height || 1) : shard.height;
    let work = workUnits(complexity, Math.max(given, returned), shard.cap_n || 0, height);
    if (shard.work_mode === "measured" && measured) {
      work = Math.max(1, measured.calls + Object.values(measured.loops).reduce((a, b) => a + b, 0));
    }
    if ((slot === 0 && this.options.free_first_work) || (this.options.jit && (this.options.ran || []).includes(shard.id))) work = 0;
    return Math.floor(work * (this.options.work_factor === undefined ? 1 : this.options.work_factor));
  }

  call(slot, bolts, body, part) {
    const shard = SHARDS[this.indexes[slot]];
    const original = JSON.parse(JSON.stringify(bolts));
    const originalOrder = this.order;
    bolts = this.hooks("before", shard, bolts);
    const given = bolts.length;
    const sortedInput = isSorted(bolts);
    let snapshot;
    let returned;
    let measured;
    try {
      const fn = load(shard);
      counts = { loops: {}, calls: {} };
      const result = fn(bolts, JSON.parse(this.battleJson));
      if (!Array.isArray(result)) throw new TypeError(shard.name + " must return an array of bolts, not " + typeof result);
      returned = result.length;
      snapshot = JSON.stringify(result.slice(0, DATA.limit));
      if (COUNT) measured = { loops: counts.loops, calls: counts.calls[shard.name] || 0 };
    } catch (error) {
      throw { shard, error };
    }
    const work = this.bill(shard, slot, given, returned, measured, sortedInput);
    const projected = Math.min(2 ** 30, Math.floor((this.work + work) * this.discount));
    const pruned = Boolean(this.options.prune) && projected > (this.options.budget === undefined ? 2 ** 30 : this.options.budget);
    if (pruned) {
      bolts = original;
      this.order = originalOrder;
    } else {
      this.work += work;
      bolts = JSON.parse(snapshot);
      let extra = 0;
      if (shard.role === "source") {
        for (const rule of this.options.source_power || []) {
          if (!rule.paradigm || rule.paradigm === shard.paradigm) extra += rule.add;
        }
      }
      if (shard.role === "strike" && sortedInput) extra += this.options.sorted_strike_power || 0;
      if (extra) bolts = bolts.map(bolt => bolt && typeof bolt.power === "number" && (shard.role === "source" || !bolt.block)
        ? { ...bolt, power: bolt.power + extra } : bolt);
      this.order = shard.makes || this.order;
      bolts = this.hooks("after", shard, bolts);
    }
    const step = { shard: shard.id, given, returned, bolts: JSON.parse(JSON.stringify(bolts)).slice(0, DATA.traceLimit) };
    if (measured) {
      Object.assign(step, measured);
      step.power = 0;
      step.elements = {};
      for (const bolt of bolts) {
        if (bolt && typeof bolt.power === "number") step.power += bolt.power;
        if (bolt && typeof bolt.element === "string") step.elements[bolt.element] = (step.elements[bolt.element] || 0) + 1;
      }
    }
    if (this.extended) {
      step.slot = slot;
      step.input_sorted = sortedInput;
      if (body !== undefined) Object.assign(step, { body, part });
      if (pruned) step.pruned = true;
    }
    this.trace.push(step);
    return { bolts, accepted: !pruned };
  }

  body(owner, slot, bolts, depth) {
    const shard = SHARDS[this.indexes[slot]];
    const nested = depth > 1 && shard.splits && slot + 1 < this.indexes.length;
    let pieces = [bolts];
    for (let level = 0; level < (nested ? 1 : depth); level++) {
      pieces = pieces.flatMap(piece => {
        const half = Math.ceil(piece.length / 2);
        return [piece.slice(0, half), piece.slice(half)];
      });
    }
    let out = [];
    let consumed = slot + 1;
    for (let part = 0; part < pieces.length; part++) {
      let result = this.call(slot, pieces[part], owner, part);
      if (nested && result.accepted) {
        const child = this.body(slot, slot + 1, result.bolts, depth - 1);
        result.bolts = child.bolts;
        consumed = child.consumed;
      }
      out = out.concat(result.bolts);
    }
    const extra = this.options.rejoin_power || 0;
    if (extra) out = out.map(bolt => ({ ...bolt, power: bolt.power + extra }));
    out = out.slice(0, DATA.limit);
    const elements = {};
    let power = 0;
    for (const bolt of out) {
      if (bolt && typeof bolt.power === "number") power += bolt.power;
      if (bolt && typeof bolt.element === "string") elements[bolt.element] = (elements[bolt.element] || 0) + 1;
    }
    Object.assign(this.trace[this.trace.length - 1], {
      joined: JSON.parse(JSON.stringify(out)).slice(0, DATA.traceLimit), joined_returned: out.length,
      joined_power: power, joined_elements: elements,
    });
    return { bolts: out, consumed };
  }

  run(bolts) {
    let slot = 0;
    const bodyRule = this.options.body || {};
    const depth = bodyRule.kind === "split" ? Math.max(0, Math.min(2, bodyRule.depth || 0)) : 0;
    while (slot < this.indexes.length) {
      const result = this.call(slot, bolts);
      bolts = result.bolts;
      const shard = SHARDS[this.indexes[slot]];
      if (depth && result.accepted && shard.splits && slot + 1 < this.indexes.length) {
        const child = this.body(slot, slot + 1, bolts, depth);
        bolts = child.bolts;
        slot = child.consumed;
      } else slot++;
    }
    return bolts;
  }
}

function runSpell(spell, battleJson, trace) {
  const bolts = JSON.parse(JSON.stringify(spell.bolts !== undefined ? spell.bolts : DATA.bolts));
  return new Execution(spell, battleJson, trace).run(bolts);
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
