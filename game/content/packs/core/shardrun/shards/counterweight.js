function counterweight(bolts, battle) {
  const factor = 1 + bolts.filter(b => b.ward).length;
  return bolts.map(b => !b.ward ? { ...b, mult: b.mult * factor } : b);
}
