Bolts rod_cutting(Bolts bolts, const Battle& battle) {
  // Rod cutting: best[n] is the most a rod of length n can be worth when cut into pieces, trying every first piece.
  // A piece is worth its price (a 3 is worth 4, a 5 worth 7, a 7 worth 10); any other length is worth itself.
  // The strongest bolt is the rod. Its pieces become bolts, each as strong as that piece is worth.
  const std::map<int, int> price = {{3, 4}, {5, 7}, {7, 10}};
  const auto worth = [&](int piece) { return price.count(piece) ? price.at(piece) : piece; };
  int rod = -1;
  for (int k = 0; k < static_cast<int>(bolts.size()); k++) {
    if (bolts[k].power > 0 && !bolts[k].block && (rod < 0 || bolts[k].power > bolts[rod].power)) rod = k;
  }
  if (rod < 0) return bolts;
  const int length = std::min(bolts[rod].power, 30);
  std::vector<int> best(length + 1, 0);
  std::vector<int> cut(length + 1, 0);
  for (int n = 1; n <= length; n++) {
    best[n] = -1;
    for (int piece = n; piece > 0; piece--) {
      const int value = worth(piece) + best[n - piece];
      if (value > best[n]) {
        best[n] = value;
        cut[n] = piece;
      }
    }
  }
  std::vector<int> pieces;
  for (int n = length; n > 0; n -= cut[n]) pieces.push_back(cut[n]);
  Bolts result;
  for (int k = 0; k < static_cast<int>(bolts.size()); k++) {
    if (k != rod) {
      result.push_back(bolts[k]);
      continue;
    }
    for (int piece : pieces) {
      Bolt part = bolts[k];
      part.power = worth(piece);
      result.push_back(part);
    }
    if (bolts[k].power > length) {
      Bolt rest = bolts[k];
      rest.power = bolts[k].power - length;
      result.push_back(rest);
    }
  }
  return result;
}
