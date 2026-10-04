function consistentHashingPlus(bolts, battle) {
  // Consistent hashing: foes and bolts are hashed onto one ring (0 to 359) and a bolt flies at the next foe clockwise.
  // A foe sits at a point set by its max HP, not by its place in the list, so when one falls only its own bolts move on to the next. None are wasted.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const points = foes.map((foe) => (foe.max * 47 + 13) % 360);
  const remaining = foes.map((foe) => foe.hp + (foe.shield || 0));
  const ring = foes.map((_, i) => i).sort((a, b) => points[a] - points[b]);
  const result = [];
  bolts.forEach((bolt, i) => {
    const spot = (bolt.power * 37 + i * 101) % 360;
    let lo = 0;
    let hi = ring.length;
    while (lo < hi) {
      const mid = Math.floor((lo + hi) / 2);
      if (points[ring[mid]] < spot) lo = mid + 1;
      else hi = mid;
    }
    const start = lo % ring.length;
    let step = 0;
    while (step < ring.length - 1 && remaining[ring[(start + step) % ring.length]] <= 0) step++;
    const target = ring[(start + step) % ring.length];
    let power = bolt.power;
    if (step > 0 && remaining[target] > 0) power += 1;
    result.push({ ...bolt, power, foe: target });
    remaining[target] -= power;
  });
  return result;
}
