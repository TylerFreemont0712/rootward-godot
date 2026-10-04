function popBoltPlus(bolts, battle) {
  // Array.pop() removes and returns the last item in O(1). A lone bolt has no first one to give its power to.
  const result = bolts.map((bolt) => ({ ...bolt }));
  if (result.length < 2) return result;
  const last = result.pop();
  result[0].power += last.power + 1;
  return result;
}
