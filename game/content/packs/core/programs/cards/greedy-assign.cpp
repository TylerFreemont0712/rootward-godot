Bolts greedy_assign(Bolts bolts, const Battle& battle) {
  // Greedy: strongest bolts first, weakest foes first; keep adding bolts to a foe until they would kill it, then
  // move on. Fast and usually good, not always optimal. The sort makes it O(n log n).
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  Bolts strongest = bolts;
  std::stable_sort(strongest.begin(), strongest.end(), [](const Bolt& a, const Bolt& b) { return a.power > b.power; });
  auto need = [&foes](int i) { return foes[i].hp + foes[i].shield; };
  std::vector<int> order;
  for (int i = 0; i < static_cast<int>(foes.size()); i++) order.push_back(i);
  std::stable_sort(order.begin(), order.end(), [&need](int a, int b) { return need(a) < need(b); });
  Bolts out;
  size_t k = 0;
  for (int i : order) {
    int left = need(i);
    while (left > 0 && k < strongest.size()) {
      Bolt aimed = strongest[k];
      aimed.foe = i;
      out.push_back(aimed);
      left -= strongest[k].power;
      k++;
    }
  }
  // Whatever is left over goes at the toughest foe, the last in the order.
  for (; k < strongest.size(); k++) {
    Bolt aimed = strongest[k];
    aimed.foe = order.back();
    out.push_back(aimed);
  }
  return out;
}
