Bolts take_two(Bolts bolts, const Battle& battle) {
  Bolts taken(bolts.begin(), bolts.begin() + std::min<size_t>(2, bolts.size()));
  for (Bolt& b : taken) b.mult = b.mult.value_or(1) * 2;
  return taken;
}
