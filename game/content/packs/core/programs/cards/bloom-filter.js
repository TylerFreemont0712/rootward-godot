function bloomFilter(bolts, battle) {
  // A Bloom filter: each weak element sets two bits of a small array, and a bolt "might" match when both of its bits are set.
  // It never misses a real match, but a false positive can slip through: here the turn picks one bolt that gains the bonus wrongly.
  function bloomHash(element, seed) {
    let h = seed;
    for (let j = 0; j < element.length; j++) h = (h * 31 + element.charCodeAt(j)) % 32;
    return h;
  }
  const bits = new Array(32).fill(false);
  let marked = false;
  for (const foe of battle.foes || []) {
    for (const element of foe.weak || []) {
      bits[bloomHash(element, 3)] = true;
      bits[bloomHash(element, 7)] = true;
      marked = true;
    }
  }
  if (!marked || bolts.length === 0) return bolts;
  const might = [];
  for (const bolt of bolts) {
    might.push(bits[bloomHash(bolt.element, 3)] && bits[bloomHash(bolt.element, 7)]);
  }
  const start = ((battle.turn ?? 1) * 7 + 3) % bolts.length;
  for (let step = 0; step < bolts.length; step++) {
    const slot = (start + step) % bolts.length;
    if (!might[slot]) {
      might[slot] = true;
      break;
    }
  }
  const result = [];
  bolts.forEach((bolt, i) => {
    if (might[i]) result.push({ ...bolt, power: bolt.power + 2 });
    else result.push({ ...bolt });
  });
  return result;
}
