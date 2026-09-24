function pairFold(bolts, battle) {
  const out = [];
  for (let i = 0; i < bolts.length; i += 2) {
    const a = bolts[i], b = bolts[i + 1];
    if (b && a.ward === b.ward) {
      const power = Math.max(1, a.power);
      out.push({ ...a, power, mult: (a.power * a.mult + b.power * b.mult) / power });
    } else out.push(...bolts.slice(i, i + 2));
  }
  return out;
}
