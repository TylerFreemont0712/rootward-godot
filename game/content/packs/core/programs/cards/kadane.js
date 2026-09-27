function kadane(bolts, battle) {
  // Kadane: the best run ending here is this bolt alone, or this bolt added to the best run ending just before; a
  // run whose score falls to zero or below is dropped. Scores are power minus 3, so weak bolts count against a run.
  // The best run seen fuses into one bolt of its whole power, 1 stronger for every bolt in it. O(n).
  if (bolts.length === 0) return bolts;
  let best = null;
  let bestFrom = 0;
  let bestTo = 0;
  let here = 0;
  let start = 0;
  bolts.forEach((bolt, i) => {
    if (here <= 0) {
      here = 0;
      start = i;
    }
    here += bolt.power - 3;
    if (best === null || here > best) {
      best = here;
      bestFrom = start;
      bestTo = i;
    }
  });
  const run = bolts.slice(bestFrom, bestTo + 1);
  let strongest = run[0];
  for (const bolt of run) if (bolt.power > strongest.power) strongest = bolt;
  const power = run.reduce((sum, bolt) => sum + bolt.power, 0) + run.length;
  return bolts.slice(0, bestFrom).concat([{ ...strongest, power }], bolts.slice(bestTo + 1));
}
