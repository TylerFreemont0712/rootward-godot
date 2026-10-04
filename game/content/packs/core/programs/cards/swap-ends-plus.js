function swapEndsPlus(bolts, battle) {
  // JavaScript swaps two items without a temporary too: destructuring.
  const result = bolts.map((bolt) => ({ ...bolt }));
  if (result.length > 1) {
    [result[0], result[result.length - 1]] = [result[result.length - 1], result[0]];
  }
  if (result.length > 0) result[0].power += 1;
  return result;
}
