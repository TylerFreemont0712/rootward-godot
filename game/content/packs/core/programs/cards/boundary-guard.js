function boundaryGuard(bolts, battle) {
  // A recursive call gets its own small boundary: sacrifice its weakest attack when there are at least two.
  const result = bolts.map((bolt) => ({ ...bolt }));
  const attacks = result.map((bolt, i) => i).filter((i) => !result[i].block && !result[i].stash);
  if (attacks.length < 2) return result;
  let weakest = attacks[0];
  for (const i of attacks.slice(1)) if (result[i].power < result[weakest].power) weakest = i;
  result[weakest].block = true;
  return result;
}
