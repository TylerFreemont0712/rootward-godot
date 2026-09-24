function lodestone(bolts, battle) {
  return bolts.map((b, i) => i === bolts.length - 1 ? { ...b, target: "back", mult: b.mult * 2 } : b);
}
