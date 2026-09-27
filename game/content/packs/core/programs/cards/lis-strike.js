function lisStrike(bolts, battle) {
  // length[i]: the longest rising sequence ending at bolt i, built from every earlier j (O(n²)); `before` remembers
  // the step taken, so the sequence can be walked back from its end.
  const n = bolts.length;
  if (n === 0) return bolts;
  const length = new Array(n).fill(1);
  const before = new Array(n).fill(-1);
  for (let i = 0; i < n; i++) {
    for (let j = 0; j < i; j++) {
      if (bolts[j].power < bolts[i].power && length[j] + 1 > length[i]) {
        length[i] = length[j] + 1;
        before[i] = j;
      }
    }
  }
  let end = 0;
  for (let i = 1; i < n; i++) if (length[i] > length[end]) end = i;
  const chosen = new Set();
  while (end >= 0) {
    chosen.add(end);
    end = before[end];
  }
  const bonus = chosen.size;
  return bolts.map((bolt, i) =>
    chosen.has(i) ? { ...bolt, power: bolt.power + bonus, foe: 0 } : { ...bolt, block: true }
  );
}
