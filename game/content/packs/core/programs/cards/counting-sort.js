function countingSort(bolts, battle) {
  // Counting sort never compares two bolts: it counts how many bolts have each power, then reads the counts out in order.
  // O(n + k), where k is the strongest power: fast while powers are small, slow when one bolt is huge.
  let top = 0;
  for (const bolt of bolts) top = Math.max(top, bolt.power);
  const buckets = [];
  for (let power = 0; power <= top; power++) buckets.push([]);
  for (const bolt of bolts) buckets[bolt.power].push({ ...bolt });
  const result = [];
  for (const bucket of buckets) {
    for (const bolt of bucket) result.push(bolt);
  }
  return result;
}
