function skyline(bolts, battle) {
  // The skyline problem, divide and conquer: the skyline of a volley is the skyline of its left half merged with the
  // skyline of its right half. Merging is one comparison: a right tower shorter than the left half's tallest is hidden
  // behind it and fuses into it, adding half its power; the rest stay visible. A tower holds what it has absorbed so far, and
  // passes it on if it is hidden in its turn.
  if (bolts.length === 0) return bolts;
  const skyline = (lo, hi) => {
    // the visible towers of bolts[lo:hi], as [place, absorbed]
    if (hi - lo === 1) return [[lo, 0]];
    const mid = Math.floor((lo + hi) / 2);
    const left = skyline(lo, mid);
    const right = skyline(mid, hi);
    const tallest = bolts[left[left.length - 1][0]].power;
    for (const tower of right) {
      const power = bolts[tower[0]].power;
      if (power < tallest) left[left.length - 1][1] += Math.floor(power / 2) + tower[1];
      else left.push(tower);
    }
    return left;
  };
  return skyline(0, bolts.length).map(([place, absorbed]) => ({ ...bolts[place], power: bolts[place].power + absorbed }));
}
