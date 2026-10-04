function countingSortPlus(bolts, battle) {
  // Counting sort never compares two bolts: it counts how many bolts have each power, then reads the counts out in order. O(n + k).
  // k is capped at 64: bolts stronger than that skip the counting and are sorted the ordinary way after the rest.
  let top = 0;
  for (const bolt of bolts) top = Math.max(top, Math.min(bolt.power, 64));
  const buckets = [];
  for (let power = 0; power <= top; power++) buckets.push([]);
  const huge = [];
  for (const bolt of bolts) {
    if (bolt.power > 64) huge.push({ ...bolt });
    else buckets[bolt.power].push({ ...bolt });
  }
  const result = [];
  for (const bucket of buckets) {
    for (const bolt of bucket) result.push(bolt);
  }
  return result.concat(huge.sort((a, b) => a.power - b.power));
}
