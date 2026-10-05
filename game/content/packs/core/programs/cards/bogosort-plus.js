function bogosortPlus(bolts, battle) {
  // Bogosort: shuffle, check, repeat. A seeded LCG stands in for chance (the preview must equal the cast), and a
  // fixed number of tries stops the joke: after that, keep the best try; successful sorting buffs the head, while the
  // capped result gives its strongest bolt a smaller bonus.
  const head = bolts.slice(0, 7);
  const rest = bolts.slice(7);
  let seed = ((battle.turn ?? 1) * 7919 + head.reduce((sum, bolt, i) => sum + bolt.power * (i + 1), 0)) >>> 0;
  const order = head.slice();
  let best = head.slice();
  let bestDescents = -1;
  let sortedSuccessfully = false;
  for (let attempt = 0; attempt < 120; attempt++) {
    let descents = 0;
    for (let i = 0; i < order.length - 1; i++) {
      if (order[i].power > order[i + 1].power) descents++;
    }
    if (bestDescents < 0 || descents < bestDescents) {
      best = order.slice();
      bestDescents = descents;
    }
    if (descents === 0) {
      sortedSuccessfully = true;
      break;
    }
    for (let i = order.length - 1; i > 0; i--) {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      const j = (seed >>> 16) % (i + 1);
      [order[i], order[j]] = [order[j], order[i]];
    }
  }
  const result = best.map((bolt) => ({ ...bolt }));
  if (sortedSuccessfully) {
    for (const bolt of result) bolt.power += 1;
  } else if (result.length > 0) {
    let strongest = 0;
    for (let i = 1; i < result.length; i++) {
      if (result[i].power > result[strongest].power) strongest = i;
    }
    result[strongest].power += 3;
  }
  return result.concat(rest.map((bolt) => ({ ...bolt })));
}
