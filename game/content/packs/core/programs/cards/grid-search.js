function gridSearch(bolts, battle) {
  // Grid search: try every cell of a 4 x 4 grid, one loop inside another. Cell (i, j) becomes a bolt of power
  // i * j // 2 + 1, added after the volley: the kind of sweep that tunes a model's two settings.
  const out = bolts.map((bolt) => ({ ...bolt }));
  for (let i = 0; i < 4; i++) {
    for (let j = 0; j < 4; j++) {
      out.push({ power: Math.floor((i * j) / 2) + 1, element: "none" });
    }
  }
  return out;
}
