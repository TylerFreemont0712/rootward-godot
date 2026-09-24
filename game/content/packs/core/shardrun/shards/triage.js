function triage(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, target: "strongest" }));
}
