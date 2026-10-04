Bolts merge_strike_plus(Bolts bolts, const Battle& battle) {
  // A tournament of merges: pair the bolts up, fuse each pair (+30%, +50% with `import math`), and repeat on the
  // survivors until one is left. n bolts take n - 1 merges in log2(n) rounds. The one bolt flies at the foe with the
  // most HP.
  if (bolts.empty()) return bolts;
  const auto& imports = battle.imports;
  const int growth = std::find(imports.begin(), imports.end(), "math") != imports.end() ? 15 : 13;
  Bolts level = bolts;
  while (level.size() > 1) {
    Bolts merged;
    for (size_t i = 0; i + 1 < level.size(); i += 2) {
      Bolt fused = level[i];
      fused.power = static_cast<int>(std::floor(double(level[i].power + level[i + 1].power) * growth / 10));
      merged.push_back(fused);
    }
    if (level.size() % 2 == 1) merged.push_back(level.back());
    level = merged;
  }
  const auto& foes = battle.foes;
  int toughest = 0;
  for (int i = 1; i < static_cast<int>(foes.size()); i++) if (foes[i].hp > foes[toughest].hp) toughest = i;
  level[0].foe = toughest;
  return level;
}
