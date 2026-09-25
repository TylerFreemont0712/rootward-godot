function memo_table(bolts, battle) {
  const seen = new Set();
  return bolts.map((bolt) => {
    const power = bolt.power + (seen.has(bolt.element) ? 4 : 0);
    seen.add(bolt.element);
    return { ...bolt, power };
  });
}
