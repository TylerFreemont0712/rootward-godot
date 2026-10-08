function radixSort(bolts, battle) {
  // Four stable hexadecimal passes cover every power from 0 through the game's 9,999 cap.
  let result = bolts.map((bolt) => ({ ...bolt }));
  for (const shift of [0, 4, 8, 12]) {
    const buckets = Array.from({ length: 16 }, () => []);
    for (const bolt of result) buckets[(bolt.power >> shift) & 15].push(bolt);
    result = buckets.flat();
  }
  return result;
}
