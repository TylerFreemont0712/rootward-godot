Bolts focus(Bolts bolts, const Battle& battle) {
  if (bolts.empty()) return {};
  double total = 0;
  for (const Bolt& bolt : bolts) total += bolt.power;
  Bolt focused = bolts[0];
  focused.power = total;
  return {focused};
}
