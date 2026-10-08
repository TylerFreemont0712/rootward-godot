// The Shardrun spell harness for JavaScript (old ADR-0012, ADR-0013). Standard input is one JSON object: the shards'
// sources, the spells (lists of indexes into the shards), the starting bolts, the battle, and the limits. Each spell's
// result is printed as one line starting with the job's marker. SpellHarness (spell_harness.gd) builds the input and
// reads the lines back.

// Every built-in or library function the harness calls after a card returns is captured here, before any card code runs
// (docs/LEGENDARY_LOOKS.md, Program tags). Captured built-ins are safe: a card that rebinds one of them changes nothing
// the harness stamps, serialises or bills. A card that rebinds a global name of the harness can change only its own
// run's output; closing that fully is open.
// LEARN: a capture is called through Reflect.apply, not as map.call(...): `call` is looked up on the function at call
// time, so a card that rebinds Function.prototype.call could reach the stamp that way.
// LEARN: a capture holds the function, not what the function reads. A built-in still looks up its receiver's prototype
// while it runs (toJSON, Symbol.species), so a card that sets those on Object.prototype or Array.prototype changes the
// output. Closing that means freezing the prototypes, which is not done here. The launcher (game/sandbox/launch/launch.js)
// captures the built-ins it prints with in its own closure, so a card cannot change the printed line that way.
// LEARN: for...of calls the array's iterator (Array.prototype[Symbol.iterator], then the iterator's next), and a card can
// replace either. So the loops below are indexed, with the length read once before each loop: the replacement is never
// called, and a list that grows during a loop cannot lengthen it.
const reflectApply = Reflect.apply;
const captured = fn => (self, ...args) => reflectApply(fn, self, args);
const isArray = Array.isArray;
const parseJson = JSON.parse;
const stringifyJson = JSON.stringify;
const objectAssign = Object.assign;
const objectValues = Object.values;
const ceil = Math.ceil;
const floor = Math.floor;
const log2 = Math.log2;
const min = Math.min;
const max = Math.max;
const arrayMap = captured(Array.prototype.map);
const arraySlice = captured(Array.prototype.slice);
const arrayConcat = captured(Array.prototype.concat);
const arrayFlatMap = captured(Array.prototype.flatMap);
const arraySome = captured(Array.prototype.some);
const arrayEvery = captured(Array.prototype.every);
const arrayPush = captured(Array.prototype.push);
const arrayIncludes = captured(Array.prototype.includes);
const arrayReduce = captured(Array.prototype.reduce);
const arrayJoin = captured(Array.prototype.join);
const stringSplit = captured(String.prototype.split);
const stringSlice = captured(String.prototype.slice);
const stringReplace = captured(String.prototype.replace);
const stringTrim = captured(String.prototype.trim);
const stringStartsWith = captured(String.prototype.startsWith);
const stringIncludes = captured(String.prototype.includes);
const regexExec = captured(RegExp.prototype.exec);
const FunctionCtor = Function;
const ErrorCtor = Error;
const TypeErrorCtor = TypeError;
const stringOf = String;
const printLine = console.log;

// Capture at start (docs/LEGENDARY_LOOKS.md, Program tags): the job's input is frozen before any card runs, so every read
// after a card sees the job as it was given. A card's write to DATA, SHARDS, the hooks or the rules fails (silently, in a
// sloppy card), and the harness never holds a copy that a card can reach and change.
// LEARN: a frozen object needs no copy to be a capture: nothing can change it, so the harness reads it as it always was.
function deepFreeze(value) {
  if (value !== null && typeof value === "object") {
    Object.freeze(value);
    const keys = Object.keys(value);
    for (let index = 0; index < keys.length; index++) deepFreeze(value[keys[index]]);
  }
  return value;
}
const DATA = deepFreeze(parseJson(require("fs").readFileSync(0, "utf8")));
const SHARDS = DATA.shards;
const MARKER = DATA.marker;

// A program run (ADR-0012) asks for counts: how many times each loop in a card went round and how many times its
// functions were entered (recursion). A counted card is instrumented line by line, on the same lines, so a line number in
// an error is still the card's own: a counter after each loop's opening brace, one at the top of each named function,
// and array methods that take a callback (map, filter, ...) counted per call of the callback.
const COUNT = !!DATA.count;
const METHODS = /\.(map|forEach|filter|reduce|some|every|find|findIndex|flatMap)\(/g;
// The array methods a counted card calls through, captured like the rest.
const COUNTABLE = {
  map: Array.prototype.map,
  forEach: Array.prototype.forEach,
  filter: Array.prototype.filter,
  reduce: Array.prototype.reduce,
  some: Array.prototype.some,
  every: Array.prototype.every,
  find: Array.prototype.find,
  findIndex: Array.prototype.findIndex,
  flatMap: Array.prototype.flatMap,
};
let counts = { loops: {}, calls: {} };

// A program run's bolts carry the card that returned them and that card's role (docs/LEGENDARY_LOOKS.md, Program tags):
// the job's `tags`. The card that returns a bolt is the one that cast it, even when it hands the bolt back unchanged.
// A card cannot choose its look through its returned values: the stamp overwrites any card or role key the card's code
// put on a bolt. The stamp calls the captures above, so a card that rebinds a built-in cannot change a bolt's tags.
const TAGS = !!DATA.tags;
function tagged(bolts, card) {
  const stamp = bolt => {
    if (!bolt || typeof bolt !== "object" || isArray(bolt)) return bolt;
    return { ...bolt, card: card.id, role: card.role || "" };
  };
  return arrayMap(bolts, stamp);
}

// Where a loop's header ends: the index of the parenthesis closing `for (` or `while (`, or -1.
function headerEnd(text) {
  const start = regexExec(/^\s*(for|while)\s*\(/, text);
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
  return arrayJoin(arrayMap(stringSplit(source, "\n"), instrumentLine), "\n");
}

function instrumentLine(text, index) {
  const line = index + 1;
  let out = text;
  const end = headerEnd(text);
  const rest = end >= 0 ? stringTrim(stringSlice(text, end + 1)) : "";
  if (end >= 0 && stringStartsWith(rest, "{")) {
    // for (...) { ...: count on entering the body.
    out = stringSlice(text, 0, end + 1) + stringReplace(stringSlice(text, end + 1), "{", "{ __loop(" + line + ");");
  } else if (end >= 0 && rest !== "" && !stringIncludes(rest, "//")) {
    // for (...) statement;  becomes  for (...) { __loop(n); statement; }  on the same line.
    out = stringSlice(text, 0, end + 1) + " { __loop(" + line + "); " + rest + " }";
  } else {
    const named = regexExec(/^\s*function\s+([A-Za-z_$][\w$]*)\s*\(.*\)\s*\{\s*$/, text);
    if (named) out = stringReplace(out, /\{\s*$/, "{ __call(\"" + named[1] + "\");");
  }
  return stringReplace(out, METHODS, (match, name) => ".__each(" + line + ", \"" + name + "\", ");
}

function loop(line) {
  counts.loops[line] = (counts.loops[line] || 0) + 1;
}

function call(name) {
  counts.calls[name] = (counts.calls[name] || 0) + 1;
}

// A counted callback is called through Reflect.apply with the arguments it was given: counting adds no call of its own.
function countedCallback(line, fn) {
  return (...args) => {
    loop(line);
    return reflectApply(fn, undefined, args);
  };
}

Object.defineProperty(Array.prototype, "__each", {
  value: function (line, method, fn, ...rest) {
    const counted = typeof fn === "function" ? countedCallback(line, fn) : fn;
    return reflectApply(COUNTABLE[method], this, arrayConcat([counted], rest));
  },
  enumerable: false,
});

function load(shard, counted = COUNT) {
  // Each shard is compiled in its own function scope, fresh for every spell, so shards never collide or keep state.
  // A hook is never counted: its loops are not the card's.
  const source = counted ? instrument(shard.source) : shard.source;
  const fn = new FunctionCtor("__loop", "__call", source + "\nreturn typeof " + shard.name + " === \"function\" ? " + shard.name + " : undefined;")(loop, call);
  if (typeof fn !== "function") throw new ErrorCtor(shard.id + " does not define " + shard.name + "(bolts, battle)");
  return fn;
}

// A program run's imports may hook a role (ADR-0018): the import's own function runs on the volley before or after
// every card of that role (heapq hands each strike the strongest bolt first; bisect sorts what each source made).
const HOOKS = DATA.hooks || [];

// LEARN: an import is not a step of the program (ProgramDeck.steps leaves it out), so after a card the bolts it hands
// back are still that card's. Each import's bolts are stamped before the next import runs: whatever an import wrote on
// a bolt is replaced, and a second import sees the card's tags, as the C++ harness does. Before a card the bolts are not
// yet its, so the card is handed them as they came.
function hooked(when, card, bolts, battleJson) {
  for (let index = 0, count = HOOKS.length; index < count; index++) {
    const hook = HOOKS[index];
    if (hook.when !== when || hook.role !== card.role) continue;
    const shard = SHARDS[hook.shard];
    try {
      const result = load(shard, false)(bolts, parseJson(battleJson));
      if (!isArray(result)) throw new TypeErrorCtor(shard.name + " must return an array of bolts, not " + typeof result);
      bolts = parseJson(stringifyJson(arraySlice(result, 0, DATA.limit)));
      if (TAGS && when === "after") bolts = tagged(bolts, card);
    } catch (error) {
      throw { shard, error };
    }
  }
  return bolts;
}

function workUnits(complexity, size, cap = 0, height = 1) {
  if (cap > 0) size = min(size, cap);
  const maximum = 2 ** 30;
  switch (complexity) {
    case "constant": return 1;
    case "logarithmic": return ceil(log2(size + 1));
    case "linearithmic": return ceil(size * log2(size + 1));
    case "quadratic": return min(maximum, size * size);
    case "exponential": return size >= 30 ? maximum : min(maximum, 2 ** size);
    case "pseudo": return min(maximum, size * max(1, height));
    default: return size;
  }
}

function isSorted(bolts) {
  if (arraySome(bolts, bolt => !bolt || typeof bolt !== "object" || typeof bolt.power !== "number")) return false;
  return arrayEvery(bolts, (bolt, i) => i === 0 || (bolts[i - 1].power || 0) <= (bolt.power || 0));
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
    const rules = this.options.small_program_work || [];
    for (let index = 0, count = rules.length; index < count; index++) {
      const rule = rules[index];
      if (this.indexes.length && this.indexes.length <= rule.max_cards) this.discount *= rule.factor;
    }
  }

  hooks(when, shard, bolts) {
    bolts = hooked(when, shard, bolts, this.battleJson);
    for (let index = 0, count = HOOKS.length; index < count; index++) {
      const hook = HOOKS[index];
      if (hook.when === when && hook.role === shard.role) this.order = SHARDS[hook.shard].makes || this.order;
    }
    return bolts;
  }

  bill(shard, slot, given, returned, measured, sortedInput) {
    let complexity = shard.complexity || "linear";
    if (shard.worst_case && shard.worst_case.input === (sortedInput ? "sorted" : "unsorted")) complexity = shard.worst_case.complexity;
    complexity = (this.options.role_complexity || {})[shard.role] || complexity;
    const height = shard.height === undefined ? (this.options.height || 1) : shard.height;
    let work = workUnits(complexity, max(given, returned), shard.cap_n || 0, height);
    if (shard.work_mode === "measured" && measured) {
      work = max(1, measured.calls + arrayReduce(objectValues(measured.loops), (a, b) => a + b, 0));
    }
    if ((slot === 0 && this.options.free_first_work) || (this.options.jit && arrayIncludes(this.options.ran || [], shard.id))) work = 0;
    return floor(work * (this.options.work_factor === undefined ? 1 : this.options.work_factor));
  }

  call(slot, bolts, body, part) {
    const shard = SHARDS[this.indexes[slot]];
    const original = parseJson(stringifyJson(bolts));
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
      const result = fn(bolts, parseJson(this.battleJson));
      if (!isArray(result)) throw new TypeErrorCtor(shard.name + " must return an array of bolts, not " + typeof result);
      // LEARN: the result is read once, into a JSON copy, and both the bill and the output come from that copy. A
      // Proxy can answer each read differently (its length, its slice), so a second read could bill fewer bolts than
      // the output holds.
      const copy = parseJson(stringifyJson(result));
      if (!isArray(copy)) throw new TypeErrorCtor(shard.name + " must return an array of bolts, not " + typeof copy);
      returned = copy.length;
      snapshot = stringifyJson(arraySlice(copy, 0, DATA.limit));
      // The stamp runs inside the card's try, on a JSON copy of what the card returned, so its errors are the card's.
      if (TAGS) snapshot = stringifyJson(tagged(parseJson(snapshot), shard));
      // The measured copy is taken inside the card's try: a counted card can make its own counts unwritable (a cycle, a
      // getter that throws), and then the failure is that card's, so the job and the other spells still print.
      if (COUNT) measured = parseJson(stringifyJson({ loops: counts.loops, calls: counts.calls[shard.name] || 0 }));
    } catch (error) {
      throw { shard, error };
    }
    const work = this.bill(shard, slot, given, returned, measured, sortedInput);
    const projected = min(2 ** 30, floor((this.work + work) * this.discount));
    const pruned = !!this.options.prune && projected > (this.options.budget === undefined ? 2 ** 30 : this.options.budget);
    if (pruned) {
      bolts = original;
      this.order = originalOrder;
    } else {
      this.work += work;
      bolts = parseJson(snapshot);
      let extra = 0;
      if (shard.role === "source") {
        const rules = this.options.source_power || [];
        for (let index = 0, count = rules.length; index < count; index++) {
          const rule = rules[index];
          if (!rule.paradigm || rule.paradigm === shard.paradigm) extra += rule.add;
        }
      }
      if (shard.role === "strike" && sortedInput) extra += this.options.sorted_strike_power || 0;
      if (extra) bolts = arrayMap(bolts, bolt => bolt && typeof bolt.power === "number" && (shard.role === "source" || !bolt.block)
        ? { ...bolt, power: bolt.power + extra } : bolt);
      this.order = shard.makes || this.order;
      bolts = this.hooks("after", shard, bolts);
    }
    const step = { shard: shard.id, given, returned, bolts: arraySlice(parseJson(stringifyJson(bolts)), 0, DATA.traceLimit) };
    if (measured) {
      objectAssign(step, measured);
      step.power = 0;
      step.elements = {};
      for (let index = 0, count = bolts.length; index < count; index++) {
        const bolt = bolts[index];
        if (bolt && typeof bolt.power === "number") step.power += bolt.power;
        if (bolt && typeof bolt.element === "string") step.elements[bolt.element] = (step.elements[bolt.element] || 0) + 1;
      }
    }
    if (this.extended) {
      step.slot = slot;
      step.input_sorted = sortedInput;
      if (body !== undefined) objectAssign(step, { body, part });
      if (pruned) step.pruned = true;
    }
    arrayPush(this.trace, step);
    return { bolts, accepted: !pruned };
  }

  body(owner, slot, bolts, depth) {
    const shard = SHARDS[this.indexes[slot]];
    const nested = depth > 1 && shard.splits && slot + 1 < this.indexes.length;
    let pieces = [bolts];
    for (let level = 0; level < (nested ? 1 : depth); level++) {
      pieces = arrayFlatMap(pieces, piece => {
        const half = ceil(piece.length / 2);
        return [arraySlice(piece, 0, half), arraySlice(piece, half)];
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
      out = arrayConcat(out, result.bolts);
    }
    const extra = this.options.rejoin_power || 0;
    if (extra) out = arrayMap(out, bolt => ({ ...bolt, power: bolt.power + extra }));
    out = arraySlice(out, 0, DATA.limit);
    const elements = {};
    let power = 0;
    for (let index = 0, count = out.length; index < count; index++) {
      const bolt = out[index];
      if (bolt && typeof bolt.power === "number") power += bolt.power;
      if (bolt && typeof bolt.element === "string") elements[bolt.element] = (elements[bolt.element] || 0) + 1;
    }
    objectAssign(this.trace[this.trace.length - 1], {
      joined: arraySlice(parseJson(stringifyJson(out)), 0, DATA.traceLimit), joined_returned: out.length,
      joined_power: power, joined_elements: elements,
    });
    return { bolts: out, consumed };
  }

  run(bolts) {
    let slot = 0;
    const bodyRule = this.options.body || {};
    const depth = bodyRule.kind === "split" ? max(0, min(2, bodyRule.depth || 0)) : 0;
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
  const bolts = parseJson(stringifyJson(spell.bolts !== undefined ? spell.bolts : DATA.bolts));
  return new Execution(spell, battleJson, trace).run(bolts);
}

// A failed spell's result. Its error is read inside a try, because a card made it and can make it unreadable (a getter
// that throws); the shard is the harness's own record of the card that failed.
function failureResult(spell, failure, trace) {
  try {
    const error = failure && failure.error;
    const name = error && error.name ? error.name : "Error";
    const message = error && error.message !== undefined ? error.message : stringOf(error);
    const shard = failure && failure.shard ? failure.shard.id : undefined;
    return { spell: spell.id, ok: false, error: name + ": " + message, shard, trace };
  } catch (unreadable) {
    return { spell: spell.id, ok: false, error: "Error: the error could not be read", trace };
  }
}

// The line one spell prints. Its own errors, and anything a card can reach while the line is written (a toJSON or a
// getter that throws), are that spell's: the other spells of the job still print theirs.
function spellLine(spell, defaultBattle) {
  const battleJson = spell.battle !== undefined ? stringifyJson(spell.battle) : defaultBattle;
  const trace = [];
  let result;
  try {
    result = { spell: spell.id, ok: true, bolts: runSpell(spell, battleJson, trace), trace };
  } catch (failure) {
    result = failureResult(spell, failure, trace);
  }
  // The line goes out through the captured console.log: a card that rebinds console.log cannot change it. The launcher's
  // built-ins behind console.log are captured in its own closure (game/sandbox/launch/launch.js).
  try {
    return MARKER + stringifyJson(result);
  } catch (error) {
    return MARKER + stringifyJson(failureResult(spell, { error }, []));
  }
}

const defaultBattle = stringifyJson(DATA.battle);
for (let index = 0, count = DATA.spells.length; index < count; index++) {
  printLine(spellLine(DATA.spells[index], defaultBattle));
}
