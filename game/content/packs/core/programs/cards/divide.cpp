Bolts divide(Bolts bolts, const Battle& battle) {
  // Recursion: split the volley in half and divide each half. Every level of the split adds 1 to every bolt
  // below it (2 with `import math`), so each bolt ends up about log2(n) stronger. O(n log n): every level touches
  // every bolt.
  const auto& imports = battle.imports;
  const int step = std::find(imports.begin(), imports.end(), "math") != imports.end() ? 2 : 1;
  if (bolts.size() <= 1) return bolts;
  const size_t middle = bolts.size() / 2;
  Bolts halves = divide(Bolts(bolts.begin(), bolts.begin() + middle), battle);
  Bolts right = divide(Bolts(bolts.begin() + middle, bolts.end()), battle);
  halves.insert(halves.end(), right.begin(), right.end());
  for (Bolt& bolt : halves) bolt.power += step;
  return halves;
}
