function median_pulse(bolts, battle) {
  // Sort indices, not the volley: the lower-index member wins a tie and the original order stays intact.
  const result = bolts.map((bolt) => ({ ...bolt }));
  const attacks = result.slice(0, 16).map((bolt, i) => i).filter((i) => !result[i].block && !result[i].stash);
  if (attacks.length === 0) return result;
  attacks.sort((a, b) => result[a].power - result[b].power);
  result[attacks[Math.floor(attacks.length / 2)]].power += 2;
  return result;
}
