Bolts combinations_plus(Bolts bolts, const Battle& battle) {
  // Combinations: choose 3 of the first 7 bolts, in every way, order ignored (7 choose 3 = 35). Each trio becomes
  // one bolt of half its sum, with its strongest bolt's element. The rest of the volley follows.
  const int count = std::min<int>(7, bolts.size());
  if (count < 3) return bolts;
  Bolts out;
  for (int a = 0; a < count; a++) {
    for (int b = a + 1; b < count; b++) {
      for (int c = b + 1; c < count; c++) {
        const Bolt* strongest = &bolts[a];
        for (const Bolt* bolt : {&bolts[b], &bolts[c]}) {
          if (bolt->power > strongest->power) strongest = bolt;
        }
        const int total = bolts[a].power + bolts[b].power + bolts[c].power;
        Bolt made;
        made.power = static_cast<int>(std::floor(double(total) / 2)) + 1;
        made.element = strongest->element;
        out.push_back(made);
      }
    }
  }
  for (size_t i = count; i < bolts.size(); i++) out.push_back(bolts[i]);
  return out;
}
