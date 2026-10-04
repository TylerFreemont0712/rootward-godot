Bolts reverse(Bolts bolts, const Battle& battle) {
  // Walk the volley from its last index down to 0: O(n).
  Bolts out;
  for (int i = static_cast<int>(bolts.size()) - 1; i >= 0; i--) out.push_back(bolts[i]);
  return out;
}
