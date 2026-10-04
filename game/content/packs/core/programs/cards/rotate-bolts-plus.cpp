Bolts rotate_bolts_plus(Bolts bolts, const Battle& battle) {
  // std::rotate turns the whole range: the last k items come to the front, and k may be longer than the list.
  if (bolts.empty()) return bolts;
  const int k = 2 % static_cast<int>(bolts.size());
  std::rotate(bolts.begin(), bolts.end() - k, bolts.end());
  return bolts;
}
