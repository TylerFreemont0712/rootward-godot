Bolts cursor_plus(Bolts bolts, const Battle& battle) {
  // A cursor walks a sorted collection one item at a time: it takes the 4 weakest bolts from the index, in order.
  // A taken bolt must stay exactly as banked, so each brings a 2-power bolt of its element beside it.
  const auto& index = battle.index;
  const int count = std::min(4, static_cast<int>(index.size()));
  for (int i = 0; i < count; i++) {
    Bolt taken{.power = index[i].power, .element = index[i].element};
    taken.from_index = true;
    bolts.push_back(taken);
    bolts.push_back(Bolt{.power = 2, .element = index[i].element});
  }
  return bolts;
}
