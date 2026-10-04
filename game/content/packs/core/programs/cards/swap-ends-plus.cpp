Bolts swap_ends_plus(Bolts bolts, const Battle& battle) {
  // C++ swaps with std::swap, one move of each bolt.
  if (bolts.size() > 1) std::swap(bolts.front(), bolts.back());
  if (!bolts.empty()) bolts.front().power += 1;
  return bolts;
}
