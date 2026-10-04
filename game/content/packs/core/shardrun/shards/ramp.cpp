Bolts ramp(Bolts bolts, const Battle& battle) {
  for (size_t index = 0; index < bolts.size(); index++) bolts[index].power = bolts[index].power + index * 2;
  return bolts;
}
