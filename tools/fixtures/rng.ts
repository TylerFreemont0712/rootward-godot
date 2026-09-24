// Writes game/test/fixtures/rng.json from the TypeScript engine, the reference the GDScript port must match bit for bit.
// Run: node tools/fixtures/rng.ts   (needs the old repo at ../ProgramMe with its node_modules installed)
import { writeFileSync } from "node:fs";
import { createRng, hashString, mix32, pickWeighted, randomFor, shuffled } from "../../../ProgramMe/packages/core/src/rng.ts";

const strings = ["", "a", "seed-1", "The quick brown fox", "日本語", "b8f0c3a2-5d7e-4f1a-9c3b-2e6d8a4f7b10"];
const seeds = ["s1", "run-42", "b8f0c3a2-5d7e-4f1a-9c3b-2e6d8a4f7b10"];

const fixture = {
  hash: strings.map((text) => ({ text, value: hashString(text) })),
  mix: [0, 1, 2, 0x7fffffff, 0x80000000, 0xffffffff, 123456789].map((value) => ({ value, mixed: mix32(value) })),
  randomFor: seeds.flatMap((seed) =>
    ["loot", "foe"].flatMap((stream) => [0, 1, 7, 1000].map((index) => ({ seed, stream, index, value: randomFor(seed, stream, index) }))),
  ),
  sequences: seeds.map((seed) => {
    const next = createRng(seed, "map");
    return { seed, stream: "map", values: Array.from({ length: 20 }, () => next()) };
  }),
  shuffles: seeds.map((seed) => ({ seed, items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], result: shuffled([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], createRng(seed, "shuffle")) })),
  weighted: [0, 0.1, 0.35, 0.5, 0.99].map((roll) => {
    const items = [1, 0, 3, 2].map((weight, i) => ({ weight, i }));
    return { weights: [1, 0, 3, 2], roll, index: pickWeighted(items, roll)?.i ?? -1 };
  }),
};

const out = new URL("../../game/test/fixtures/rng.json", import.meta.url);
writeFileSync(out, `${JSON.stringify(fixture, null, 1)}\n`);
console.log(`wrote ${out.pathname}`);
