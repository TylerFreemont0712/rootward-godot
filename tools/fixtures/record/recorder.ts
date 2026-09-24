// Stands in for packages/core/src/index.ts while the old engine's own unit tests run (see vitest.config.ts): every call
// into the Shardrun rules is passed through to the real function and written down with its arguments and result.
// The GDScript tests replay the calls (game/test/fixtures/shardrun-unit.json.gz), so the old tests' hand-made edge
// cases (traits, relics, custom catalogs) prove the port too.
import { writeFileSync } from "node:fs";
import { gzipSync } from "node:zlib";
import * as real from "../../../../ProgramMe/packages/core/src/index.ts";
import * as conditions from "../../../../ProgramMe/packages/core/src/shardrun/relic-conditions.ts";

export * from "../../../../ProgramMe/packages/core/src/index.ts";

const calls: unknown[] = [];
const catalogs = new Map<string, number>();
const catalogList: unknown[] = [];

/** JSON that keeps Maps (as objects) and non-finite numbers (as {"$num": "Infinity"}), taken at call time. */
function freeze(value: unknown): unknown {
  return JSON.parse(
    JSON.stringify(value, (_key, v: unknown) => {
      if (v instanceof Map) return Object.fromEntries(v);
      if (typeof v === "number" && !Number.isFinite(v)) return { $num: String(v) };
      return v;
    }),
  );
}

function catalogId(catalog: unknown): number {
  const text = JSON.stringify(freeze(catalog));
  let id = catalogs.get(text);
  if (id === undefined) {
    id = catalogList.length;
    catalogs.set(text, id);
    catalogList.push(JSON.parse(text));
  }
  return id;
}

const CATALOG_ARG: Record<string, number> = {
  startShardrun: 0, stepShardrun: 2, previewCast: 3, previewBolts: 2, manaPerTurn: 1, boltCap: 1, boltPowerBonus: 1,
  handSize: 1, holdLimit: 1, pipelineWork: 1,
};

function wrap<F extends (...args: never[]) => unknown>(name: string, fn: F): F {
  return ((...args: Parameters<F>) => {
    const at = CATALOG_ARG[name];
    const frozen = args.map((arg, i) => (i === at ? { $catalog: catalogId(arg) } : freeze(arg)));
    try {
      const result = fn(...args);
      calls.push({ fn: name, args: frozen, result: freeze(result) });
      return result;
    } catch (error) {
      calls.push({ fn: name, args: frozen, threw: String(error) });
      throw error;
    }
  }) as F;
}

export const startShardrun = wrap("startShardrun", real.startShardrun);
export const stepShardrun = wrap("stepShardrun", real.stepShardrun);
export const previewCast = wrap("previewCast", real.previewCast);
export const previewBolts = wrap("previewBolts", real.previewBolts);
export const billWork = wrap("billWork", real.billWork);
export const boltCap = wrap("boltCap", real.boltCap);
export const boltPowerBonus = wrap("boltPowerBonus", real.boltPowerBonus);
export const encounterFor = wrap("encounterFor", real.encounterFor);
export const manaPerTurn = wrap("manaPerTurn", real.manaPerTurn);
export const generateLayerMap = wrap("generateLayerMap", real.generateLayerMap);
export const handSize = wrap("handSize", real.handSize);
export const holdLimit = wrap("holdLimit", real.holdLimit);
export const nextRooms = wrap("nextRooms", real.nextRooms);
export const normalizeBolts = wrap("normalizeBolts", real.normalizeBolts);
export const pipelineWork = wrap("pipelineWork", real.pipelineWork);
export const scoreShardrun = wrap("scoreShardrun", real.scoreShardrun);
export const workUnits = wrap("workUnits", real.workUnits);
export const matchesRelic = wrap("matchesRelic", conditions.matchesRelic);

/** Writes the recording; setup.ts calls it once the test file is done. */
export function flushRecording(): void {
  const out = new URL("../../../game/test/fixtures/shardrun-unit.json.gz", import.meta.url);
  writeFileSync(out, gzipSync(JSON.stringify({ catalogs: catalogList, calls })));
  console.log(`recorded ${calls.length} calls over ${catalogList.length} catalogs`);
}
