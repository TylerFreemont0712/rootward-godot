Bolts cartesian_product_plus(Bolts bolts, const Battle& battle) {
  // The Cartesian product enumerates every pair, in bolt order then foe order.
  Bolts result;
  for (const Bolt& bolt : bolts) {
    for (int i = 0; i < static_cast<int>(battle.foes.size()); i++) {
      Bolt copy = bolt;
      copy.power = static_cast<int>(std::floor(double(bolt.power) / 2));
      copy.foe = i;
      result.push_back(copy);
    }
  }
  return result;
}
