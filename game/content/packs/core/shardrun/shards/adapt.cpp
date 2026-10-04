Bolts adapt(Bolts bolts, const Battle& battle) {
  const std::vector<Foe>& foes = battle.foes;
  if (foes.empty() || foes[0].weak.empty()) return bolts;
  const std::string element = foes[0].weak[0];
  for (Bolt& bolt : bolts) bolt.element = element;
  return bolts;
}
