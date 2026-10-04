Bolts divide_plus(Bolts bolts, const Battle& battle) {
  // Recursion: split the volley in half and divide each half. Every level of the split adds 2 to every bolt
  // below it (3 with `import math`), so each bolt ends up about log2(n) stronger. O(n log n): every level touches
  // every bolt.
  const auto& imports = battle.imports;
  const int step = std::find(imports.begin(), imports.end(), "math") != imports.end() ? 3 : 2;
  if (bolts.size() <= 1) return bolts;
  const size_t middle = bolts.size() / 2;
  Bolts halves = divide_plus(Bolts(bolts.begin(), bolts.begin() + middle), battle);
  Bolts right = divide_plus(Bolts(bolts.begin() + middle, bolts.end()), battle);
  halves.insert(halves.end(), right.begin(), right.end());
  for (Bolt& bolt : halves) bolt.power += step;
  return halves;
}
