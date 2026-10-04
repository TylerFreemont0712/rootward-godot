Bolts confluence(Bolts bolts, const Battle& battle) {
  std::set<std::string> elements;
  for (const Bolt& b : bolts) {
    if (b.element != "none") elements.insert(b.element);
  }
  const double factor = std::max<double>(1, elements.size());
  for (Bolt& b : bolts) b.mult = b.mult.value_or(1) * factor;
  return bolts;
}
