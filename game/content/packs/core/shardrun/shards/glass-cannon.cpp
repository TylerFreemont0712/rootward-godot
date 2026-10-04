Bolts glass_cannon(Bolts bolts, const Battle& battle) {
  Bolts out;
  for (const Bolt& b : bolts) {
    if (b.ward.value_or(false)) continue;
    Bolt doubled = b;
    doubled.power = b.power * 2;
    doubled.mult = b.mult.value_or(1) * 2;
    out.push_back(doubled);
  }
  return out;
}
