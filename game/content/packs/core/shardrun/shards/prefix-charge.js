function prefixCharge(bolts, battle) {
  let total = 0;
  return bolts.map(b => { total += b.mult; return { ...b, mult: total }; });
}
