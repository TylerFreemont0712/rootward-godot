function guardEcho(bolts, battle) {
  const out = [];
  for (const b of bolts) {
    out.push(b);
    if (!b.ward) out.push({ ...b, ward: true, power: b.power / 4 });
  }
  return out;
}
