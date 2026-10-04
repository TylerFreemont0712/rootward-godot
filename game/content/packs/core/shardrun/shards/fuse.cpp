Bolts fuse(Bolts bolts, const Battle& battle) {
  Bolts wards;
  Bolts attacks;
  for (const Bolt& b : bolts) {
    if (b.ward.value_or(false)) {
      wards.push_back(b);
    } else {
      attacks.push_back(b);
    }
  }
  if (attacks.empty()) return wards;
  const double power = std::max(1.0, attacks[0].power);
  double sum = 0;
  for (const Bolt& b : attacks) sum += b.power * b.mult.value_or(1);
  Bolt fused = attacks[0];
  fused.power = power;
  fused.mult = sum / power;
  Bolts out = {fused};
  for (const Bolt& ward : wards) out.push_back(ward);
  return out;
}
