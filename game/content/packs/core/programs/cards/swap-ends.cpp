Bolts swap_ends(Bolts bolts, const Battle& battle) {
  // C++ swaps with std::swap, one move of each bolt.
  if (bolts.size() > 1) std::swap(bolts.front(), bolts.back());
  return bolts;
}
