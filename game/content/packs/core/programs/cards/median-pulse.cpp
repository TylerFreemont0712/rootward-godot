Bolts median_pulse(Bolts bolts, const Battle&) {
  // Sort indices, not the volley: the lower-index member wins a tie and the original order stays intact.
  std::vector<size_t> attacks;
  for (size_t i = 0; i < bolts.size() && i < 16; i++) {
    if (!bolts[i].block && !bolts[i].stash) attacks.push_back(i);
  }
  if (attacks.empty()) return bolts;
  std::stable_sort(attacks.begin(), attacks.end(), [&](size_t a, size_t b) { return bolts[a].power < bolts[b].power; });
  bolts[attacks[attacks.size() / 2]].power += 2;
  return bolts;
}
