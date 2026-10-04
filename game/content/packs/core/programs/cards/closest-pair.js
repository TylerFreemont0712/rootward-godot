function closestPair(bolts, battle) {
  // Closest pair, divide and conquer, on a line of powers. Sort the bolts by power, split in half and find the closest
  // pair in each half; a closer pair that straddles the cut must lie within that gap of it (the strip), and in the
  // strip each bolt needs comparing only with the few after it. A pair is [gap, first place, second place], and the
  // smallest wins, so ties go to the pair nearest the front. The two fuse into one bolt of double their total.
  const pairOf = (a, b) => [Math.abs(a[0] - b[0]), Math.min(a[1], b[1]), Math.max(a[1], b[1])];
  const smaller = (a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2];
  const closest = (items) => {
    // items are [power, place], sorted
    if (items.length <= 3) {
      let best = null;
      for (let a = 0; a < items.length; a++) {
        for (let b = a + 1; b < items.length; b++) {
          const pair = pairOf(items[a], items[b]);
          if (best === null || smaller(pair, best) < 0) best = pair;
        }
      }
      return best;
    }
    const middle = Math.floor(items.length / 2);
    const left = closest(items.slice(0, middle));
    const right = closest(items.slice(middle));
    let best = smaller(right, left) < 0 ? right : left;
    const cut = items[middle][0];
    const strip = items.filter((item) => Math.abs(item[0] - cut) <= best[0]);
    for (let a = 0; a < strip.length; a++) {
      for (let b = a + 1; b < strip.length; b++) {
        if (strip[b][0] - strip[a][0] > best[0]) break;
        const pair = pairOf(strip[a], strip[b]);
        if (smaller(pair, best) < 0) best = pair;
      }
    }
    return best;
  };
  const items = bolts.map((bolt, i) => [bolt.power, i]).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  if (items.length < 2) return bolts;
  const pairs = [closest(items)];
  const second = new Map(pairs.map((pair) => [pair[1], pair[2]]));
  const gone = new Set(second.values());
  const out = [];
  bolts.forEach((bolt, i) => {
    if (gone.has(i)) return;
    if (second.has(i)) {
      const other = bolts[second.get(i)];
      const stronger = other.power > bolt.power ? other : bolt;
      out.push({ ...stronger, power: 2 * (bolt.power + other.power) });
    } else {
      out.push(bolt);
    }
  });
  return out;
}
