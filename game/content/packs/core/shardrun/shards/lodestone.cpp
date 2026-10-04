Bolts lodestone(Bolts bolts, const Battle& battle) {
  for (std::size_t i = 0; i < bolts.size(); i++) {
    if (i == bolts.size() - 1) {
      bolts[i].target = "back";
      bolts[i].mult = bolts[i].mult.value_or(1) * 2;
    }
  }
  return bolts;
}
