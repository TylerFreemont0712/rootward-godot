function monteCarlo(bolts, battle) {
  // A Monte Carlo method answers with random samples. The seed comes from the turn and the bolts, so the same
  // volley always rolls the same dice: what the preview shows is what the cast does.
  let seed = battle.turn || 1;
  for (const bolt of bolts) seed = (Math.imul(seed, 31) + bolt.power) >>> 0;
  const rolls = [];
  for (let i = 0; i < 8; i++) {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    rolls.push({ power: (seed >>> 16) % 6 + 1, element: "none" });
  }
  return bolts.concat(rolls);
}
