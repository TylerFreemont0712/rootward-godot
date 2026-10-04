Bolts singularity(Bolts bolts, const Battle& battle) {
  const int count = static_cast<int>(bolts.size());
  if (count == 0) return bolts;
  return {Bolt{.power = 4.0 * count, .element = "none", .target = "strongest", .pierce = true, .ward = false,
               .mult = double(count)}};
}
