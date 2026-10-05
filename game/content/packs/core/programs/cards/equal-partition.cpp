Bolts equal_partition(Bolts bolts, const Battle& battle) {
  // Exact 0/1 subset-sum finds the closest split through 1,024 total power. Above that, a deterministic
  // strongest-first greedy balance bounds work. The larger side attacks; the smaller can become block. Only an exact
  // split keeps the original +25% bonus.
  std::vector<int> pool;
  int total = 0;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (bolts[i].power > 0 && !bolts[i].block && !bolts[i].stash) {
      pool.push_back(i);
      total += bolts[i].power;
    }
  }
  if (pool.size() < 2) return bolts;
  std::set<int> smaller;
  int smaller_total = 0;
  if (total <= 1024) {
    const int target = total / 2;

    // A bounded 64-bit bitset updates and saves at most nine words per bolt, plus one backtracking check; height 20
    // bills this bounded work through total power 1,024.
    const int word_count = target / 64 + 1;
    std::vector<unsigned long long> reachable(word_count, 0);
    reachable[0] = 1ULL;
    std::vector<std::vector<unsigned long long>> history{reachable};
    for (int i : pool) {
      const int power = bolts[i].power;
      const int word_shift = power / 64;
      const int bit_shift = power % 64;
      for (int word = word_count - 1; word >= word_shift; word--) {
        const int source = word - word_shift;
        unsigned long long shifted = reachable[source] << bit_shift;
        if (bit_shift > 0 && source > 0) shifted |= reachable[source - 1] >> (64 - bit_shift);
        reachable[word] |= shifted;
      }
      const int last_bits = target % 64 + 1;
      if (last_bits < 64) reachable.back() &= (1ULL << last_bits) - 1ULL;
      history.push_back(reachable);
    }

    smaller_total = -1;
    for (int word = word_count - 1; word >= 0 && smaller_total < 0; word--) {
      if (reachable[word] == 0) continue;
      for (int bit = 63; bit >= 0; bit--) {
        if ((reachable[word] >> bit) & 1ULL) {
          smaller_total = word * 64 + bit;
          break;
        }
      }
    }
    if (smaller_total <= 0) return bolts;

    int remaining = smaller_total;
    for (int position = static_cast<int>(pool.size()) - 1; position >= 0; position--) {
      const int word = remaining / 64;
      const int bit = remaining % 64;
      if ((history[position][word] >> bit) & 1ULL) continue;
      const int i = pool[position];
      smaller.insert(i);
      remaining -= bolts[i].power;
    }
  } else {
    // Above the exact-DP limit, process strongest-first and always place the next bolt on the lighter side.
    std::vector<int> ordered = pool;
    std::sort(ordered.begin(), ordered.end(), [&bolts](int a, int b) {
      if (bolts[a].power != bolts[b].power) return bolts[a].power > bolts[b].power;
      return a < b;
    });
    std::vector<int> sides[2];
    int side_totals[2] = {0, 0};
    for (int i : ordered) {
      const int side = side_totals[0] <= side_totals[1] ? 0 : 1;
      sides[side].push_back(i);
      side_totals[side] += bolts[i].power;
    }
    const int smaller_side = side_totals[0] <= side_totals[1] ? 0 : 1;
    smaller.insert(sides[smaller_side].begin(), sides[smaller_side].end());
    smaller_total = side_totals[smaller_side];
  }
  std::vector<int> smaller_indices;
  std::vector<int> larger_indices;
  for (int i : pool) {
    if (smaller.count(i)) smaller_indices.push_back(i);
    else larger_indices.push_back(i);
  }
  const int smaller_lead = *std::max_element(smaller_indices.begin(), smaller_indices.end(), [&bolts](int a, int b) {
    return bolts[a].power < bolts[b].power;
  });
  const int larger_lead = *std::max_element(larger_indices.begin(), larger_indices.end(), [&bolts](int a, int b) {
    return bolts[a].power < bolts[b].power;
  });
  const int larger_total = total - smaller_total;
  Bolt large_attack = bolts[larger_lead];
  large_attack.power = larger_total;
  Bolt small_attack = bolts[smaller_lead];
  small_attack.power = smaller_total;
  Bolts result;

  if (smaller_total == larger_total) {
    // Keep the original payoff only when the two groups are exactly balanced.
    large_attack.power = large_attack.power * 5 / 4;
    small_attack.power = small_attack.power * 5 / 4;
    result.push_back(large_attack);
    result.push_back(small_attack);
  } else {
    int threat = 0;
    for (const Foe& foe : battle.foes) {
      if (foe.intent.kind.empty() || foe.intent.kind == "attack") {
        threat = std::max(threat, foe.intent.damage * foe.intent.hits);
      }
    }
    int have = battle.me.block;
    for (const Bolt& bolt : bolts) if (bolt.block) have += bolt.power;
    const int block_power = std::min(smaller_total, std::max(0, threat - have));
    result.push_back(large_attack);
    if (block_power > 0) {
      const int excess = smaller_total - block_power;
      // Keep the residual offensive power in the larger attack output without adding another bolt.
      if (excess > 0) result[0].power += excess;
      Bolt small_block = bolts[smaller_lead];
      small_block.power = block_power;
      small_block.block = true;
      result.push_back(small_block);
    } else result.push_back(small_attack);
  }

  std::set<int> pool_set(pool.begin(), pool.end());
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (!pool_set.count(i)) result.push_back(bolts[i]);
  }
  return result;
}
