function scatter(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, target: "all" }));
}
