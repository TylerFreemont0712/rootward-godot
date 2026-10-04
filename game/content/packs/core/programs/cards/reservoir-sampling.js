function reservoirSampling(bolts, battle) {
  // Algorithm R: keep 3 items from a stream in one pass, without knowing its length. Item i replaces a kept one
  // with chance 3 / (i + 1), so every bolt is equally likely to stay. The seed makes the preview the cast.
  let seed = battle.turn || 1;
  for (const bolt of bolts) seed = (Math.imul(seed, 31) + bolt.power) >>> 0;
  const reservoir = [];
  for (let i = 0; i < bolts.length; i++) {
    if (i < 3) {
      reservoir.push(i);
    } else {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      const j = (seed >>> 16) % (i + 1);
      if (j < 3) reservoir[j] = i;
    }
  }
  reservoir.sort((a, b) => a - b);
  return reservoir.map((i) => ({ ...bolts[i], power: bolts[i].power * 2 }));
}
