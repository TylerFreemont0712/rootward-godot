function swapEnds(bolts, battle) {
  // JavaScript swaps two items without a temporary too: destructuring.
  const result = bolts.map((bolt) => ({ ...bolt }));
  if (result.length > 1) {
    [result[0], result[result.length - 1]] = [result[result.length - 1], result[0]];
  }
  return result;
}
