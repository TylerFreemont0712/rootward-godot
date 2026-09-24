function seekWeakest(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, target: "weakest" }));
}
