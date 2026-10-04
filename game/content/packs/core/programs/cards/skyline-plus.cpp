struct Tower {
  int place;
  int absorbed;
};

std::vector<Tower> skyline_of(const Bolts& bolts, int lo, int hi) {
  if (hi - lo == 1) return {Tower{lo, 0}};
  const int mid = (lo + hi) / 2;
  std::vector<Tower> left = skyline_of(bolts, lo, mid);
  const std::vector<Tower> right = skyline_of(bolts, mid, hi);
  const int tallest = bolts[left.back().place].power;
  for (const Tower& tower : right) {
    const int power = bolts[tower.place].power;
    if (power < tallest) left.back().absorbed += power + tower.absorbed;
    else left.push_back(tower);
  }
  return left;
}

Bolts skyline_plus(Bolts bolts, const Battle& battle) {
  // The skyline problem, divide and conquer: the skyline of a volley is the skyline of its left half merged with the
  // skyline of its right half. Merging is one comparison: a right tower shorter than the left half's tallest is hidden
  // behind it and fuses into it, adding its whole power; the rest stay visible. A tower holds what it has absorbed so far, and
  // passes it on if it is hidden in its turn.
  if (bolts.empty()) return bolts;
  Bolts out;
  for (const Tower& tower : skyline_of(bolts, 0, static_cast<int>(bolts.size()))) {
    Bolt visible = bolts[tower.place];
    visible.power += tower.absorbed;
    out.push_back(visible);
  }
  return out;
}
