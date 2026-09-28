function dividePlus(bolts, battle) {
  // Recursion: split the volley in half and divide each half. Every level of the split adds 2 to every bolt
  // below it (3 with `import math`), so each bolt ends up about log2(n) stronger. O(n log n): every level touches
  // every bolt.
  const step = (battle.imports || []).includes("math") ? 3 : 2;
  if (bolts.length <= 1) return bolts.map((bolt) => ({ ...bolt }));
  const middle = Math.floor(bolts.length / 2);
  const halves = dividePlus(bolts.slice(0, middle), battle).concat(dividePlus(bolts.slice(middle), battle));
  return halves.map((bolt) => ({ ...bolt, power: bolt.power + step }));
}
