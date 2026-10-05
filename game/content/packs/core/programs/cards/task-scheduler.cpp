Bolts task_scheduler(Bolts bolts, const Battle& battle) {
  // Task scheduling with a cooldown of one: always take the element with the most bolts left that is not the one
  // just used. Only a spacer inserted when no task is eligible is marked idle for Handoff Ward.
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
      Bolt idle;
      idle.power = 1;
      idle.element = "none";
      idle.idle = true;
      result.push_back(idle);
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
