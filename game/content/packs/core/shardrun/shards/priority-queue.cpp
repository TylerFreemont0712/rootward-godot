Bolts priority_queue(Bolts bolts, const Battle& battle) {
  Bolts ordered = bolts;
  std::stable_sort(ordered.begin(), ordered.end(), [](const Bolt& a, const Bolt& b) { return a.power > b.power; });
  if (!ordered.empty()) ordered[0].target = "strongest";
  return ordered;
}
