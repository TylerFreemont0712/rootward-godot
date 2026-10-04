Bolts mirror_power(Bolts bolts, const Battle& battle) {
  if (bolts.empty()) return {};
  double peak = bolts[0].power;
  for (const Bolt& b : bolts) peak = std::max(peak, b.power);
  for (Bolt& b : bolts) b.power = peak;
  return bolts;
}
