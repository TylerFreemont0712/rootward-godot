// Writes the Shardrun rules fixtures from the TypeScript engine, the reference the GDScript port must reproduce:
//   game/test/fixtures/shardrun-catalog.json   the catalog the engine reads (content with schema defaults, balance)
//   game/test/fixtures/shardrun-pure.json      maps, encounters, pricing, clamps, relic modifiers, scores, id order
//   game/test/fixtures/shardrun-runs.json.gz   seeded runs: every command a seeded "player" issued, and what came back
// Run: node tools/fixtures/shardrun.ts   (needs ../ProgramMe with its node_modules installed)
//
// The player is a policy drawing from its own seeded stream: it enters rooms, arranges and composes, casts spells whose
// sandbox outcomes it makes up (valid bolts, malformed ones, fizzles, floods past the cap), claims and leaves rewards,
// rests, forges, abandons, issues dev commands in sandbox runs, and now and then sends a command that must be refused.
import { writeFileSync } from "node:fs";
import path from "node:path";
import { gzipSync } from "node:zlib";
import { loadBalance } from "../../../ProgramMe/packages/content-tools/src/config.ts";
import { loadContent } from "../../../ProgramMe/packages/content-tools/src/loader/load-content.ts";
import { createRng } from "../../../ProgramMe/packages/core/src/rng.ts";
import {
  billWork,
  boltCap,
  boltPowerBonus,
  encounterFor,
  foeHp,
  handSize,
  holdLimit,
  manaPerTurn,
  normalizeBolts,
  pipelineWork,
  previewCast,
  relicModifiers,
  type PipelineOutcome,
  type ShardrunCatalog,
  type ShardrunCommand,
  startShardrun,
  stepShardrun,
  workUnits,
} from "../../../ProgramMe/packages/core/src/shardrun/engine.ts";
import { generateLayerMap, nextRooms } from "../../../ProgramMe/packages/core/src/shardrun/map.ts";
import { scoreShardrun } from "../../../ProgramMe/packages/core/src/shardrun/score.ts";
import type { ShardrunState } from "../../../ProgramMe/packages/core/src/shardrun/types.ts";

const oldRoot = path.resolve(import.meta.dirname, "../../../ProgramMe");
const { index, diagnostics } = await loadContent({ contentDir: path.join(oldRoot, "content"), rootDir: oldRoot });
const balance = await loadBalance(path.join(oldRoot, "config"), diagnostics, oldRoot);
if (!balance || !index.shardrun) throw new Error("content did not load");
const catalog: ShardrunCatalog = {
  config: index.shardrun.value,
  shards: new Map([...index.shards].map(([id, shard]) => [id, shard.value])),
  foes: new Map([...index.shardrunFoes].map(([id, foe]) => [id, foe.value])),
  relics: new Map([...index.shardrunRelics].map(([id, relic]) => [id, relic.value])),
  balance: balance.shardrun,
};
const out = (name: string) => new URL(`../../game/test/fixtures/${name}`, import.meta.url);

// --- The catalog --------------------------------------------------------------------------------------------------
writeFileSync(
  out("shardrun-catalog.json"),
  `${JSON.stringify({
    config: catalog.config,
    shards: Object.fromEntries(catalog.shards),
    foes: Object.fromEntries(catalog.foes),
    relics: Object.fromEntries(catalog.relics),
    balance: catalog.balance,
  })}\n`,
);

// --- Pure functions -----------------------------------------------------------------------------------------------
const SEEDS = ["alpha", "b8f0c3a2-5d7e-4f1a-9c3b-2e6d8a4f7b10", "seed-3", "run-42", "x", "maps-6", "maps-7", "maps-8"];
const maps = SEEDS.flatMap((seed) =>
  catalog.config.layers.map((layer, layerIndex) => {
    const map = generateLayerMap(seed, layerIndex, layer);
    return {
      seed,
      layer: layerIndex,
      map,
      next: [null, ...map.nodes.map((node) => node.id)].map((position) => ({
        position,
        rooms: nextRooms(map, position).map((node) => node.id),
      })),
      encounters: map.nodes.map((node) => ({ node: node.id, foes: encounterFor(seed, node, layer) })),
    };
  }),
);

const counts = [0, 1, 2, 3, 4, 5, 7, 8, 15, 16, 31, 63, 64, 100, 127, 128, 255, 256, 1000, 2.5];
const pure = {
  maps,
  work_units: (["constant", "linear", "linearithmic", "quadratic"] as const).flatMap((complexity) =>
    counts.map((given) => ({ complexity, given, units: workUnits(complexity, given) })),
  ),
  bill_work: (["log", "sqrt", "linear"] as const).flatMap((curve) =>
    [0, 1, 7, 8, 15, 16, 24, 63, 64, 100, 255, 256, 999, 4096, 12345, 1e6].map((units) => ({
      curve,
      units,
      mana: billWork(units, curve, catalog.balance),
    })),
  ),
  pipeline_work: [
    [{ shard: "adapt", given: 3 }],
    [...catalog.shards.keys()].slice(0, 12).map((shard, i) => ({ shard, given: i * 5 + 1 })),
    [{ shard: "no-such-shard", given: 9 }],
  ].map((steps) => ({ steps, units: pipelineWork(steps, catalog) })),
  foe_hp: [0, 0.4, 0.5, 1.5, 2.5, -3, 1e13, Infinity, NaN, 19.49, 1234.5].map((raw) => ({
    raw: Number.isFinite(raw) ? raw : String(raw),
    hp: foeHp(raw, catalog.balance),
  })),
  normalize: [
    [{ power: 4, element: "fire", target: "front", pierce: false, ward: false }],
    [{ power: 4.5, element: "frost", target: "all", pierce: true, ward: false, mult: 2.5 }],
    [{ power: -2, element: "none", target: "back", pierce: false, ward: true, mult: -1 }],
    [{ power: 99, element: "spark", target: "weakest", pierce: false, ward: false, mult: 5000 }],
    [{ power: 2.5, element: "none", target: "front", pierce: false, ward: false }, { power: 3.5, element: "none", target: "front", pierce: false, ward: false }],
    [{ power: 4, element: "arcane", target: "front", pierce: false, ward: false }],
    [{ power: "4", element: "fire", target: "front", pierce: false, ward: false }],
    [{ power: 4, element: "fire", target: "front", pierce: false, ward: false, extra: 1 }],
    [{ power: 4, element: "fire", target: "front", pierce: 0, ward: false }],
    [{ power: 4, element: "fire", target: "middle", pierce: false, ward: false }],
    [{ power: 4, element: "fire", target: "front", pierce: false }],
    [null, 3, "bolt", [], { power: 1, element: "none", target: "front", pierce: false, ward: false }],
    Array.from({ length: 20 }, (_, i) => ({ power: i, element: "none", target: "front", pierce: false, ward: false })),
  ].map((raw) => ({ raw, cap: 16, result: normalizeBolts(raw, catalog.balance, 16) })),
  // Relic modifiers for every relic alone and for a few mixes, in both playstyles and at three layers.
  modifiers: [
    ...[...catalog.relics.keys()].map((id) => [id]),
    [...catalog.relics.keys()].slice(0, 6),
    [...catalog.relics.keys()].slice(6, 14),
    [...catalog.relics.keys()],
  ].flatMap((relics) =>
    (["spellbook", "deck"] as const).flatMap((playstyle) =>
      [0, 1, 2].map((layer) => {
        const state = { relics, layer, playstyle, deck: ["a", "b", "c", "d", "e", "f", "g"] };
        return {
          state,
          modifiers: relicModifiers(state, catalog),
          mana_per_turn: manaPerTurn(state, catalog),
          bolt_cap: boltCap(state, catalog),
          bolt_power_bonus: boltPowerBonus(state, catalog),
          hand_size: handSize(state, catalog),
          hold_limit: holdLimit(state, catalog),
        };
      }),
    ),
  ),
  sorted: {
    shards: [...catalog.shards.keys()].sort((a, b) => a.localeCompare(b)),
    relics: [...catalog.relics.keys()].sort((a, b) => a.localeCompare(b)),
  },
};

// --- Seeded runs --------------------------------------------------------------------------------------------------
const ELEMENTS = ["none", "fire", "frost", "spark"];
const TARGETS = ["front", "back", "weakest", "strongest", "all"];
type Rng = () => number;
const pick = <T>(rng: Rng, items: readonly T[]): T | undefined => items[Math.floor(rng() * items.length)];
const int = (rng: Rng, lo: number, hi: number) => lo + Math.floor(rng() * (hi - lo + 1));

function makeBolt(rng: Rng): unknown {
  const roll = rng();
  if (roll < 0.03) return pick(rng, [null, 7, "bolt", { power: "4" }, { power: 4, element: "arcane", target: "front", pierce: false, ward: false }]);
  const bolt: Record<string, unknown> = {
    power: rng() < 0.15 ? int(rng, 0, 90) + 0.5 * int(rng, 0, 1) : int(rng, 1, 30),
    element: pick(rng, ELEMENTS),
    target: pick(rng, TARGETS),
    pierce: rng() < 0.2,
    ward: rng() < 0.15,
  };
  if (rng() < 0.4) bolt.mult = pick(rng, [1, 1.5, 2, 0.5, 3, 1.25, 12]);
  if (rng() < 0.02) bolt.extra = true;
  return bolt;
}

function makeOutcome(rng: Rng, shards: readonly string[]): PipelineOutcome {
  if (rng() < 0.07) return { ok: false, reason: pick(rng, ["adapt line 3: ValueError: nope", "it ran out of time (a loop that never ends?)"])! };
  const count = rng() < 0.05 ? int(rng, 60, 160) : int(rng, 0, 1 + shards.length * 3);
  const bolts = Array.from({ length: count }, () => makeBolt(rng));
  const work = shards.map((shard) => ({ shard, given: int(rng, 1, Math.max(1, count + 2)) }));
  return { ok: true, bolts, work };
}

/** Deal every item into buckets of the given capacities at random; what does not fit stays behind. */
function deal(rng: Rng, items: readonly string[], capacities: readonly number[]): { buckets: string[][]; rest: string[] } {
  const buckets = capacities.map((): string[] => []);
  const rest: string[] = [];
  for (const item of items) {
    const open = buckets.map((b, i) => i).filter((i) => buckets[i]!.length < capacities[i]!);
    if (open.length > 0 && rng() < 0.75) buckets[pick(rng, open)!]!.push(item);
    else rest.push(item);
  }
  return { buckets, rest };
}

function invalidCommand(rng: Rng, state: ShardrunState): ShardrunCommand {
  const spell = pick(rng, state.spells);
  return pick(rng, [
    { type: "enter", nodeId: "nowhere" },
    { type: "cast", spellId: "spell-99", outcome: { ok: true, bolts: [], work: [] } },
    { type: "take", shardId: "not-offered" },
    { type: "claim-relic", relicId: "nothing" },
    { type: "claim-spell" },
    { type: "rest" },
    { type: "forge", shardId: "adapt" },
    { type: "widen", spellId: spell?.id ?? "spell-1" },
    { type: "bind" },
    { type: "open-chest" },
    { type: "leave" },
    { type: "end-turn" },
    { type: "purge", shardId: "adapt" },
    { type: "cleanse-relic", relicId: "nothing" },
    { type: "arrange", spells: state.spells.map((s) => ({ id: s.id, shards: [...s.shards, "extra"] })), inventory: state.inventory },
    { type: "compose", spells: [], hand: [], held: [] },
    { type: "dev-set", integrity: 5 },
  ] as ShardrunCommand[])!;
}

function devCommand(rng: Rng, state: ShardrunState): ShardrunCommand {
  const shards = [...catalog.shards.keys()];
  const relics = [...catalog.relics.keys()];
  const foes = [...catalog.foes.keys()];
  return pick(rng, [
    { type: "dev-grant-shard", shardId: pick(rng, shards)! },
    { type: "dev-remove-shard", shardId: pick(rng, [...state.inventory, ...state.deck, "adapt"])! },
    { type: "dev-grant-relic", relicId: pick(rng, relics)! },
    { type: "dev-remove-relic", relicId: pick(rng, [...state.relics, "nothing"])! },
    { type: "dev-grant-spell", name: "Dev Spell", capacity: int(rng, 1, 5) },
    { type: "dev-set", integrity: int(rng, 0, 60), mana: int(rng, 0, 12) },
    { type: "dev-spawn", kind: pick(rng, ["fight", "elite", "boss"] as const)!, foes: [pick(rng, foes)!, ...(rng() < 0.4 ? [pick(rng, foes)!] : [])] },
    { type: "dev-end-battle", outcome: rng() < 0.8 ? "win" : "lose" },
    { type: "dev-goto-layer", layer: int(rng, 0, catalog.config.layers.length) },
  ] as ShardrunCommand[])!;
}

interface Choice {
  command: ShardrunCommand;
  preview?: unknown;
}

function choose(rng: Rng, state: ShardrunState): Choice {
  if (rng() < 0.03) return { command: invalidCommand(rng, state) };
  if (state.sandbox && rng() < 0.08) return { command: devCommand(rng, state) };
  if (rng() < 0.002) return { command: { type: "abandon" } };
  const deck = state.playstyle === "deck";
  switch (state.status) {
    case "map": {
      if (!deck && rng() < 0.15) {
        const all = [...state.spells.flatMap((s) => s.shards), ...state.inventory];
        const { buckets, rest } = deal(rng, all, state.spells.map((s) => s.capacity));
        return { command: { type: "arrange", spells: state.spells.map((s, i) => ({ id: s.id, shards: buckets[i]! })), inventory: rest } };
      }
      const room = pick(rng, nextRooms(state.map, state.position));
      return { command: { type: "enter", nodeId: room?.id ?? "nowhere" } };
    }
    case "battle": {
      const battle = state.battle!;
      if (deck && battle.hand.length > 0 && rng() < 0.55) {
        const open = state.spells.filter((s) => !battle.cast.includes(s.id));
        const pool = [...battle.hand, ...battle.held, ...open.flatMap((s) => s.shards)];
        const { buckets, rest } = deal(rng, pool, open.map((s) => s.capacity));
        const hold = rng() < 0.3 && rest.length > 0 ? rest.slice(0, holdLimit(state, catalog)) : [];
        const hand = rest.slice(hold.length);
        const spells = state.spells.map((s) => {
          const i = open.indexOf(s);
          return { id: s.id, shards: i >= 0 ? buckets[i]! : [...s.shards] };
        });
        return { command: { type: "compose", spells, hand, held: hold } };
      }
      const castable = state.spells.filter((s) => !battle.cast.includes(s.id) && s.shards.length > 0);
      const spell = pick(rng, castable);
      if (spell && rng() < 0.85) {
        const outcome = makeOutcome(rng, spell.shards);
        return { command: { type: "cast", spellId: spell.id, outcome }, preview: previewCast(state, spell.id, outcome, catalog) };
      }
      return { command: { type: "end-turn" } };
    }
    case "reward": {
      const reward = state.reward!;
      if (reward.chest) return { command: rng() < 0.85 ? { type: "open-chest" } : { type: "leave" } };
      if (reward.shards) return { command: { type: "take", shardId: rng() < 0.85 ? pick(rng, reward.shards)! : null } };
      if (reward.relics) return { command: { type: "claim-relic", relicId: pick(rng, reward.relics)! } };
      if (reward.spell && rng() < 0.8) return { command: { type: "claim-spell" } };
      return { command: { type: "leave" } };
    }
    case "rest": {
      const curse = state.relics.find((id) => catalog.relics.get(id)?.cursed);
      if (curse && rng() < 0.5) return { command: { type: "cleanse-relic", relicId: curse } };
      return { command: { type: "rest" } };
    }
    case "forge": {
      const owned = deck ? state.deck : [...state.spells.flatMap((s) => s.shards), ...state.inventory];
      const forgeable = owned.filter((id) => catalog.shards.get(id)?.forge);
      const roll = rng();
      if (roll < 0.4 && forgeable.length > 0) return { command: { type: "forge", shardId: pick(rng, forgeable)! } };
      if (roll < 0.55) return { command: { type: "widen", spellId: pick(rng, state.spells)!.id } };
      if (roll < 0.7) return { command: { type: "bind" } };
      if (deck && roll < 0.85) return { command: { type: "purge", shardId: pick(rng, state.deck) ?? "adapt" } };
      return { command: { type: "forge", shardId: null } };
    }
    default:
      return { command: { type: "abandon" } };
  }
}

/** The state without its map, which is written only when it changed, to keep the fixture small. */
function withoutMap(state: ShardrunState): Omit<ShardrunState, "map"> {
  const { map: _map, ...rest } = state;
  return rest;
}

const RUNS = 36;
const MAX_STEPS = 260;
const runs = [];
let stepsTotal = 0;
for (let r = 0; r < RUNS; r++) {
  const seed = `fixture-${r}`;
  const playstyle = r % 3 === 2 ? "deck" : "spellbook";
  const difficulty = catalog.config.difficulties[r % catalog.config.difficulties.length]!.id;
  const sandbox = r % 5 === 4;
  const rng = createRng(seed, "policy");
  let state = startShardrun(catalog, { seed, language: "python", difficulty, sandbox, playstyle });
  const start = state;
  const steps = [];
  let lastMap = JSON.stringify(state.map);
  for (let s = 0; s < MAX_STEPS && !["won", "lost", "abandoned"].includes(state.status); s++) {
    const { command, preview } = choose(rng, state);
    const result = stepShardrun(state, command, catalog);
    const step: Record<string, unknown> = { command };
    if (preview !== undefined) step.preview = preview;
    if (result.ok) {
      state = result.state;
      step.state = withoutMap(state);
      const map = JSON.stringify(state.map);
      if (map !== lastMap) {
        step.map = state.map;
        lastMap = map;
      }
    } else step.error = result.error;
    steps.push(step);
  }
  stepsTotal += steps.length;
  runs.push({ seed, playstyle, difficulty, sandbox, start, steps, score: scoreShardrun(state) });
  console.log(`run ${r} (${playstyle}${sandbox ? ", sandbox" : ""}): ${steps.length} steps, ended ${state.status} on layer ${state.layer}`);
}

writeFileSync(out("shardrun-pure.json"), `${JSON.stringify(pure)}\n`);
writeFileSync(out("shardrun-runs.json.gz"), gzipSync(JSON.stringify({ runs })));
console.log(`wrote ${runs.length} runs, ${stepsTotal} steps`);
