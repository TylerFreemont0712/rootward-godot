Bolts reservoir_sampling_plus(Bolts bolts, const Battle& battle) {
  // Algorithm R: keep 4 items from a stream in one pass, without knowing its length. Item i replaces a kept one
  // with chance 4 / (i + 1), so every bolt is equally likely to stay. The seed makes the preview the cast.
  unsigned int seed = static_cast<unsigned int>(battle.turn);
  for (const Bolt& bolt : bolts) seed = seed * 31u + static_cast<unsigned int>(bolt.power);
  std::vector<int> reservoir;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (i < 4) {
      reservoir.push_back(i);
    } else {
      seed = seed * 1664525u + 1013904223u;
      const int j = static_cast<int>((seed >> 16) % static_cast<unsigned int>(i + 1));
      if (j < 4) reservoir[j] = i;
    }
  }
  std::sort(reservoir.begin(), reservoir.end());
  Bolts result;
  for (int i : reservoir) {
    Bolt copy = bolts[i];
    copy.power *= 2;
    result.push_back(copy);
  }
  return result;
}
