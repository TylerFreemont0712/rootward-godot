function bogosortPlus(bolts, battle) {
  // Bogosort: shuffle, check, repeat. A seeded LCG stands in for chance (the preview must equal the cast), and a
  // fixed number of tries stops the joke: after that, the arrangement with the fewest bolts out of place is kept.
  const head = bolts.slice(0, 7);
  const rest = bolts.slice(7);
  let seed = ((battle.turn ?? 1) * 7919 + head.reduce((sum, bolt, i) => sum + bolt.power * (i + 1), 0)) >>> 0;
  const order = head.slice();
  let best = head.slice();
  let bestDescents = -1;
  for (let attempt = 0; attempt < 120; attempt++) {
    let descents = 0;
    for (let i = 0; i < order.length - 1; i++) {
      if (order[i].power > order[i + 1].power) descents++;
    }
    if (bestDescents < 0 || descents < bestDescents) {
      best = order.slice();
      bestDescents = descents;
    }
    if (descents === 0) break;
    for (let i = order.length - 1; i > 0; i--) {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      const j = (seed >>> 16) % (i + 1);
      [order[i], order[j]] = [order[j], order[i]];
    }
  }
  return best.concat(rest).map((bolt) => ({ ...bolt }));
}
