function gridSearchPlus(bolts, battle) {
  // Grid search: try every cell of a 5 x 5 grid, one loop inside another. Cell (i, j) becomes a bolt of power
  // i * j // 2 + 1, added after the volley: the kind of sweep that tunes a model's two settings.
  const out = bolts.map((bolt) => ({ ...bolt }));
  for (let i = 0; i < 5; i++) {
    for (let j = 0; j < 5; j++) {
      out.push({ power: Math.floor((i * j) / 2) + 1, element: "none" });
    }
  }
  return out;
}
