Bolts repeat(Bolts bolts, const Battle& battle) {
  // A loop of fixed length (k = 3), so O(k) whatever the volley's size: three copies of the last bolt.
  const Bolt last = !bolts.empty() ? bolts.back() : Bolt{.power = 4, .element = "none"};
  for (int i = 0; i < 3; i++) bolts.push_back(last);
  return bolts;
}
