Bolts cascade(Bolts bolts, const Battle& battle) {
  for (size_t index = 0; index < bolts.size(); index += 1) {
    bolts[index].mult = bolts[index].mult.value_or(1) + index + 1;
  }
  return bolts;
}
