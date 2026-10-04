Bolts boyer_moore(Bolts bolts, const Battle& battle) {
  // Boyer-Moore majority vote: one pass and one counter find the only element that could hold more than half the
  // volley, without counting each element. A second pass confirms it. If one does, every bolt becomes that element.
  std::string candidate;
  int count = 0;
  for (const Bolt& bolt : bolts) {
    if (count == 0) {
      candidate = bolt.element;
      count = 1;
    } else if (bolt.element == candidate) {
      count++;
    } else {
      count--;
    }
  }
  int votes = 0;
  for (const Bolt& bolt : bolts) {
    if (bolt.element == candidate) votes++;
  }
  if (votes * 2 <= static_cast<int>(bolts.size())) return bolts;
  for (Bolt& bolt : bolts) {
    bolt.element = candidate;
    bolt.power += 1;
  }
  return bolts;
}
