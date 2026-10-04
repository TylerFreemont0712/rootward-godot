Bolts sweep_plus(Bolts bolts, const Battle& battle) {
  // Every bolt becomes one bolt per foe, at two thirds of its power: n bolts times m foes.
  Bolts out;
  for (const Bolt& bolt : bolts) {
    for (int i = 0; i < static_cast<int>(battle.foes.size()); i++) {
      Bolt copy = bolt;
      copy.power = std::max(1, static_cast<int>(std::floor(double(bolt.power * 2) / 3)));
      copy.foe = i;
      out.push_back(copy);
    }
  }
  return out;
}
