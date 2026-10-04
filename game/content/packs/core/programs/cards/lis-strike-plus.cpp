Bolts lis_strike_plus(Bolts bolts, const Battle& battle) {
  // length[i]: the longest rising sequence ending at bolt i, built from every earlier j (O(n²)); `before` remembers
  // the step taken, so the sequence can be walked back from its end.
  const int n = static_cast<int>(bolts.size());
  if (n == 0) return bolts;
  std::vector<int> length(n, 1);
  std::vector<int> before(n, -1);
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < i; j++) {
      if (bolts[j].power < bolts[i].power && length[j] + 1 > length[i]) {
        length[i] = length[j] + 1;
        before[i] = j;
      }
    }
  }
  int end = 0;
  for (int i = 1; i < n; i++) if (length[i] > length[end]) end = i;
  std::set<int> chosen;
  while (end >= 0) {
    chosen.insert(end);
    end = before[end];
  }
  const int bonus = 2 * static_cast<int>(chosen.size());
  for (int i = 0; i < n; i++) {
    if (chosen.count(i)) {
      bolts[i].power += bonus;
      bolts[i].foe = 0;
    } else {
      bolts[i].block = true;
    }
  }
  return bolts;
}
