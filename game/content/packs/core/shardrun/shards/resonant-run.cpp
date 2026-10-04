Bolts resonant_run(Bolts bolts, const Battle& battle) {
  std::optional<std::string> previous;
  int streak = 0;
  for (Bolt& b : bolts) {
    streak = b.element == previous ? streak + 1 : 1;
    previous = b.element;
    b.mult = b.mult.value_or(1) * streak;
  }
  return bolts;
}
