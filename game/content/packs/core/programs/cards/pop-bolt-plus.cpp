Bolts pop_bolt_plus(Bolts bolts, const Battle& battle) {
  // vector::pop_back() removes the last item in O(1). A lone bolt has no first one to give its power to.
  if (bolts.size() < 2) return bolts;
  const Bolt last = bolts.back();
  bolts.pop_back();
  bolts.front().power += last.power + 1;
  return bolts;
}
