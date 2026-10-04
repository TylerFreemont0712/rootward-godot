Bolts cross_product(Bolts bolts, const Battle& battle) {
  Bolts out;
  for (const Bolt& a : bolts) {
    for (const Bolt& b : bolts) {
      if (a.element != b.element) {
        Bolt pair = a;
        pair.power = (a.power + b.power) / 2;
        pair.mult = a.mult.value_or(1) + b.mult.value_or(1);
        out.push_back(pair);
      }
    }
  }
  return out;
}
