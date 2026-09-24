// The Shardrun spell harness for JavaScript (old ADR-0012, ADR-0013). Standard input is one JSON object: the shards'
// sources, the spells (lists of indexes into the shards), the starting bolts, the battle, and the limits. Each spell's
// result is printed as one line starting with the job's marker. SpellHarness (spell_harness.gd) builds the input and
// reads the lines back.
const DATA = JSON.parse(require("fs").readFileSync(0, "utf8"));
const SHARDS = DATA.shards;
const MARKER = DATA.marker;

function load(shard) {
  // Each shard is compiled in its own function scope, fresh for every spell, so shards never collide or keep state.
  const fn = new Function(shard.source + "\nreturn typeof " + shard.name + " === \"function\" ? " + shard.name + " : undefined;")();
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
      const result = fn(bolts, JSON.parse(battleJson));
      if (!Array.isArray(result)) throw new TypeError(shard.name + " must return an array of bolts, not " + typeof result);
      returned = result.length;
      snapshot = JSON.stringify(result.slice(0, DATA.limit));
    } catch (error) {
      throw { shard, error };
    }
    bolts = JSON.parse(snapshot);
    trace.push({ shard: shard.id, given, returned, bolts: JSON.parse(snapshot).slice(0, DATA.traceLimit) });
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
