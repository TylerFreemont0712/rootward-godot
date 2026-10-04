Bolts task_scheduler_plus(Bolts bolts, const Battle& battle) {
  // Task scheduling with a cooldown of one: always take the element with the most bolts left that is not the one
  // just used. When only the element just used remains, an idle bolt of 2 power goes in between.
  std::vector<std::string> names;
  std::vector<Bolts> rows;
  for (const Bolt& bolt : bolts) {
    int found = -1;
    for (int k = 0; k < static_cast<int>(names.size()); k++) {
      if (names[k] == bolt.element) found = k;
    }
    if (found < 0) {
      names.push_back(bolt.element);
      rows.push_back(Bolts{});
      found = static_cast<int>(names.size()) - 1;
    }
    rows[found].push_back(bolt);
  }
  std::vector<int> used(names.size(), 0);
  Bolts result;
  int last = -1;
  int left = static_cast<int>(bolts.size());
  while (left > 0) {
    int pick = -1;
    for (int k = 0; k < static_cast<int>(names.size()); k++) {
      if (k != last && used[k] < static_cast<int>(rows[k].size())) {
        if (pick < 0 || rows[k].size() - used[k] > rows[pick].size() - used[pick]) pick = k;
      }
    }
    if (pick < 0) {
      result.push_back(Bolt{.power = 2, .element = "none"});
      last = -1;
      continue;
    }
    result.push_back(rows[pick][used[pick]]);
    used[pick]++;
    left--;
    last = pick;
  }
  return result;
}
