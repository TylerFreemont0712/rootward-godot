using GapPair = std::vector<int>;  // {gap, first place, second place}

GapPair gap_pair(const std::pair<int, int>& a, const std::pair<int, int>& b) {
  return GapPair{std::abs(a.first - b.first), std::min(a.second, b.second), std::max(a.second, b.second)};
}

GapPair closest_gap(const std::vector<std::pair<int, int>>& items) {
  if (items.size() <= 3) {
    GapPair best;
    for (size_t a = 0; a < items.size(); a++) {
      for (size_t b = a + 1; b < items.size(); b++) {
        const GapPair pair = gap_pair(items[a], items[b]);
        if (best.empty() || pair < best) best = pair;
      }
    }
    return best;
  }
  const size_t middle = items.size() / 2;
  const GapPair left = closest_gap(std::vector<std::pair<int, int>>(items.begin(), items.begin() + middle));
  const GapPair right = closest_gap(std::vector<std::pair<int, int>>(items.begin() + middle, items.end()));
  GapPair best = right < left ? right : left;
  const int cut = items[middle].first;
  std::vector<std::pair<int, int>> strip;
  for (const auto& item : items) {
    if (std::abs(item.first - cut) <= best[0]) strip.push_back(item);
  }
  for (size_t a = 0; a < strip.size(); a++) {
    for (size_t b = a + 1; b < strip.size(); b++) {
      if (strip[b].first - strip[a].first > best[0]) break;
      const GapPair pair = gap_pair(strip[a], strip[b]);
      if (pair < best) best = pair;
    }
  }
  return best;
}

Bolts closest_pair(Bolts bolts, const Battle& battle) {
  // Closest pair, divide and conquer, on a line of powers. Sort the bolts by power, split in half and find the closest
  // pair in each half; a closer pair that straddles the cut must lie within that gap of it (the strip), and in the
  // strip each bolt needs comparing only with the few after it. A pair is (gap, first place, second place), and the
  // smallest wins, so ties go to the pair nearest the front. The two fuse into one bolt of double their total.
  if (bolts.size() < 2) return bolts;
  std::vector<std::pair<int, int>> items;
  for (size_t i = 0; i < bolts.size(); i++) items.push_back({bolts[i].power, static_cast<int>(i)});
  std::sort(items.begin(), items.end());
  std::vector<GapPair> pairs{closest_gap(items)};
  std::map<int, int> second;
  std::set<int> gone;
  for (const GapPair& pair : pairs) {
    second[pair[1]] = pair[2];
    gone.insert(pair[2]);
  }
  Bolts out;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (gone.count(i)) continue;
    if (second.count(i)) {
      const Bolt& other = bolts[second[i]];
      Bolt stronger = other.power > bolts[i].power ? other : bolts[i];
      stronger.power = 2 * (bolts[i].power + other.power);
      out.push_back(stronger);
    } else {
      out.push_back(bolts[i]);
    }
  }
  return out;
}
