// Writes game/test/fixtures/spells.json: spells of real shards run through the old server's harness and sandboxes
// (QuickJS and Pyodide), the reference the Godot spell harness must match.
// Run: node tools/fixtures/spells.ts   (needs ../ProgramMe with its node_modules installed)
import { writeFileSync } from "node:fs";
import path from "node:path";
import type { Shard } from "../../../ProgramMe/packages/content-schema/src/index.ts";
import { loadBalance } from "../../../ProgramMe/packages/content-tools/src/config.ts";
import { loadContent } from "../../../ProgramMe/packages/content-tools/src/loader/load-content.ts";
import { readSpellRuns, spellsJob } from "../../../ProgramMe/packages/content-tools/src/shardrun.ts";
import { WasmJsRunner, WasmPythonRunner } from "../../../ProgramMe/packages/runners/src/index.ts";

const oldRoot = path.resolve(import.meta.dirname, "../../../ProgramMe");
const { index, diagnostics } = await loadContent({ contentDir: path.join(oldRoot, "content"), rootDir: oldRoot });
const balance = await loadBalance(path.join(oldRoot, "config"), diagnostics, oldRoot);
if (!balance) throw new Error("balance.yaml did not load");

const shards = [...index.shards.values()].map((sourced) => sourced.value).sort((a, b) => a.id.localeCompare(b.id));
const byId = new Map(shards.map((shard) => [shard.id, shard]));

// Shards that go wrong on purpose, so failures are compared too.
const broken: Shard[] = [
  {
    ...shards[0]!,
    id: "test-raises",
    function: "raises_here",
    code: {
      python: "def raises_here(bolts, battle):\n    x = 1\n    raise ValueError('no bolts today')\n",
      javascript: "function raisesHere(bolts, battle) {\n  throw new RangeError('no bolts today');\n}\n",
    },
  },
  {
    ...shards[0]!,
    id: "test-not-a-list",
    function: "not_a_list",
    code: { python: "def not_a_list(bolts, battle):\n    return 3\n", javascript: "function notAList(bolts, battle) {\n  return 3;\n}\n" },
  },
  {
    ...shards[0]!,
    id: "test-prints",
    function: "prints",
    code: {
      python: "def prints(bolts, battle):\n    print('looking at', len(bolts), 'bolts')\n    return bolts\n",
      javascript: "function prints(bolts, battle) {\n  console.log('looking at', bolts.length, 'bolts');\n  return bolts;\n}\n",
    },
  },
  {
    // Breaks if a whole number arrives as 4.0: range() refuses a float, so the int/float distinction is compared too.
    ...shards[0]!,
    id: "test-int-power",
    function: "int_power",
    code: {
      python: "def int_power(bolts, battle):\n    return [dict(bolt, power=len(list(range(bolt['power'])))) for bolt in bolts]\n",
      javascript: "function intPower(bolts, battle) {\n  return bolts.map((bolt) => ({ ...bolt, power: Array.from({ length: bolt.power }).length }));\n}\n",
    },
  },
];
for (const shard of broken) byId.set(shard.id, shard);

// Every shard alone, then chains picked by a fixed stride so they mix kinds, then the broken ones in a chain.
const spells: { id: string; shards: string[] }[] = shards.map((shard) => ({ id: `solo-${shard.id}`, shards: [shard.id] }));
for (let i = 0; i < 24; i++) {
  const length = 2 + (i % 4);
  const chain = Array.from({ length }, (_, k) => shards[(i * 7 + k * 11) % shards.length]!.id);
  spells.push({ id: `chain-${i}`, shards: chain });
}
spells.push({ id: "broken-raises", shards: [shards[1]!.id, "test-raises", shards[2]!.id] });
spells.push({ id: "broken-not-a-list", shards: ["test-not-a-list"] });
spells.push({ id: "prints", shards: ["test-prints", shards[3]!.id] });
spells.push({ id: "int-power", shards: ["test-int-power"] });

const battles = [
  {
    turn: 1,
    me: { hp: 30, max: 30, block: 0, mana: 6 },
    foes: [
      { name: "Wisp", hp: 20, max: 20, shield: 0, weak: ["frost"], resist: [] },
      { name: "Cinder Imp", hp: 14, max: 18, shield: 5, weak: ["arcane"], resist: ["fire"] },
    ],
  },
  { turn: 4, me: { hp: 11, max: 40, block: 6, mana: 2 }, foes: [{ name: "Warden", hp: 180, max: 200, shield: 12, weak: [], resist: ["frost", "spark"] }] },
];
const bolt = (power: number, element: string, mult = 1) => ({ power, element, target: "front", pierce: false, ward: false, mult });
const ELEMENTS = ["none", "fire", "frost", "spark", "arcane"];
// The game's real start (one base bolt) under the real limits, then a crowd of bolts under tight limits, so cutting
// to the limit and to the trace limit is compared too.
const inputs = [
  { battle: 0, bolts: [bolt(balance.shardrun.base_bolt_power, "none")], limit: balance.shardrun.max_pipeline_bolts, traceLimit: balance.shardrun.trace_bolts },
  { battle: 1, bolts: [bolt(balance.shardrun.base_bolt_power, "none")], limit: balance.shardrun.max_pipeline_bolts, traceLimit: balance.shardrun.trace_bolts },
  { battle: 0, bolts: Array.from({ length: 20 }, (_, i) => bolt(1 + (i % 7), ELEMENTS[i % 5]!, i % 3 === 0 ? 1.5 : 1)), limit: 12, traceLimit: 5 },
];
const input = (spec: (typeof inputs)[number]) => ({ bolts: spec.bolts, battle: battles[spec.battle]!, limit: spec.limit, traceLimit: spec.traceLimit });

const limits = { wallMs: 60000, cpuMs: 20000, memMb: 256, pids: 128, outputKb: 1024 };
const runners = { javascript: new WasmJsRunner(), python: new WasmPythonRunner({ warm: false }) };
const cases = [];
for (const language of ["python", "javascript"] as const) {
  for (const [b, spec] of inputs.entries()) {
    const programs = spells.map((spell) => ({ id: spell.id, shards: spell.shards.map((id) => byId.get(id)!) }));
    const job = spellsJob(language, [{ spells: programs, input: input(spec) }], limits);
    if (!job) throw new Error(`a shard has no ${language} code`);
    const result = await runners[language].run(job, AbortSignal.timeout(120000));
    const runs = readSpellRuns(result, 0, programs.map((program) => program.id));
    cases.push({ language, input: b, runs: Object.fromEntries(runs) });
    console.log(`${language} input ${b}: ${[...runs.values()].filter((run) => run.ok).length}/${runs.size} spells ok`);
  }
}
await runners.python.dispose?.();

const fixture = {
  shards: [...byId.values()].map((shard) => ({ id: shard.id, function: shard.function, code: shard.code })),
  spells,
  inputs: inputs.map(input),
  cases,
};
const out = new URL("../../game/test/fixtures/spells.json", import.meta.url);
writeFileSync(out, `${JSON.stringify(fixture)}\n`);
console.log(`wrote ${out.pathname}`);
