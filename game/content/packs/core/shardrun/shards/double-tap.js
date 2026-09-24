function doubleTap(bolts, battle) {
  if (bolts.length === 0) return bolts;
  return [{ ...bolts[0] }, ...bolts];
}
