function echo(bolts, battle) {
  return [...bolts, ...bolts.map((bolt) => ({ ...bolt }))];
}
