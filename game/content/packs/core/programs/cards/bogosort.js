function bogosort(bolts, battle) {
  // A seeded LCG makes the preview match the cast. Check the initial order and up to 120 shuffles; keep the attempt
  // with the fewest descents. A completed sort gets a small volley bonus, while reaching the cap still rewards its
  // strongest bolt.
  const head = bolts.slice(0, 6);
  const rest = bolts.slice(6);
  let seed = ((battle.turn ?? 1) * 7919 + head.reduce((sum, bolt, i) => sum + bolt.power * (i + 1), 0)) >>> 0;
  const order = head.slice();
  let best = head.slice();
  let bestDescents = -1;
  let sortedSuccessfully = false;
  for (let shuffles = 0; shuffles <= 120; shuffles++) {
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
    if (shuffles === 120) break;
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
