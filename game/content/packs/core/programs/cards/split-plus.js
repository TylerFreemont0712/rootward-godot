function splitPlus(bolts, battle) {
  // Divide until the base case: a bolt under 4 power is small enough; anything bigger splits into two halves, and
  // each half is divided the same way.
  function pieces(bolt) {
    if (bolt.power < 4) return [{ ...bolt }];
    const half = Math.floor(bolt.power / 2);
    return pieces({ ...bolt, power: bolt.power - half }).concat(pieces({ ...bolt, power: half }));
  }
  let out = [];
  for (const bolt of bolts) out = out.concat(pieces(bolt));
  // Every piece gains 1: the more pieces, the more it adds.
  return out.map((piece) => ({ ...piece, power: piece.power + 1 }));
}
