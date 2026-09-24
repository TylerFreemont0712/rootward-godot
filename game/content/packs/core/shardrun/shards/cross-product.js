function crossProduct(bolts, battle) {
  const out = [];
  for (const a of bolts) for (const b of bolts) {
    if (a.element !== b.element) out.push({ ...a, power: (a.power + b.power) / 2, mult: a.mult + b.mult });
  }
  return out;
}
