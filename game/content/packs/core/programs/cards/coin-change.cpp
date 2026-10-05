int coin_change_lowest_set_bit(unsigned long long value) {
  int offset = 0;
  if ((value & 0xFFFFFFFFULL) == 0) { offset += 32; value >>= 32; }
  if ((value & 0xFFFFULL) == 0) { offset += 16; value >>= 16; }
  if ((value & 0xFFULL) == 0) { offset += 8; value >>= 8; }
  if ((value & 0xFULL) == 0) { offset += 4; value >>= 4; }
  if ((value & 0x3ULL) == 0) { offset += 2; value >>= 2; }
  if ((value & 0x1ULL) == 0) offset += 1;
  return offset;
}

Bolts coin_change(Bolts bolts, const Battle& battle) {
  // Bounded 0/1 bitset prefers exact lethal damage, then the lowest lethal total through 1,024. Above that range,
  // strongest-first greedy selects a deterministic lethal group. Exact kills can turn weak spare bolts into block,
  // limited to the largest attack intent among foes that the selected group does not kill.
  const auto& foes = battle.foes;
  if (foes.empty()) return bolts;
  const int need = std::max(0, foes[0].hp + foes[0].shield);
  if (need <= 0) return bolts;

  std::vector<int> candidates;
  std::vector<int> items;
  int total_power = 0;
  int max_power = 0;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (bolts[i].block || bolts[i].stash) continue;
    candidates.push_back(i);
    if (bolts[i].power > 0) {
      items.push_back(i);
      total_power += bolts[i].power;
      max_power = std::max(max_power, bolts[i].power);
    }
  }
  if (total_power < need) {
    for (int i : candidates) bolts[i].foe = 0;
    return bolts;
  }

  // A minimum lethal group crosses need on its last bolt; cap the exact search at 1,024 power.
  const int limit = std::min({total_power, need + max_power - 1, 1024});
  const int word_count = limit / 64 + 1;
  std::vector<unsigned long long> reachable(word_count, 0);
  reachable[0] = 1ULL;
  // The bitset updates and saves at most 17 words per bolt; reconstruction adds one step per bolt.
  std::vector<std::vector<unsigned long long>> history{reachable};
  for (int i : items) {
    const int power = bolts[i].power;
    if (power <= limit) {
      const int word_shift = power / 64;
      const int bit_shift = power % 64;
      for (int word = word_count - 1; word >= word_shift; word--) {
        const int source = word - word_shift;
        unsigned long long shifted = reachable[source] << bit_shift;
        if (bit_shift > 0 && source > 0) shifted |= reachable[source - 1] >> (64 - bit_shift);
        reachable[word] |= shifted;
      }
      const int last_bits = limit % 64 + 1;
      if (last_bits < 64) reachable.back() &= (1ULL << last_bits) - 1ULL;
    }
    history.push_back(reachable);
  }

  int chosen_total = -1;
  const int first_word = need / 64;
  for (int word = first_word; word < word_count; word++) {
    unsigned long long options = reachable[word];
    if (word == first_word) options &= (~0ULL << (need % 64));
    if (options != 0) {
      chosen_total = word * 64 + coin_change_lowest_set_bit(options);
      break;
    }
  }
  std::set<int> chosen;
  if (chosen_total >= 0) {
    int remaining = chosen_total;
    for (int position = static_cast<int>(items.size()) - 1; position >= 0; position--) {
      if ((history[position][remaining / 64] >> (remaining % 64)) & 1ULL) continue;
      const int i = items[position];
      chosen.insert(i);
      remaining -= bolts[i].power;
    }
  } else {
    // Beyond the bounded search, take strongest bolts first until the target is lethal.
    std::sort(items.begin(), items.end(), [&bolts](int a, int b) {
      if (bolts[a].power != bolts[b].power) return bolts[a].power > bolts[b].power;
      return a < b;
    });
    int gathered = 0;
    for (int i : items) {
      chosen.insert(i);
      gathered += bolts[i].power;
      if (gathered >= need) {
        chosen_total = gathered;
        break;
      }
    }
  }
  if (chosen_total < 0) {
    for (int i : candidates) bolts[i].foe = 0;
    return bolts;
  }

  std::set<int> warded;
  if (chosen_total == need) {
    // The exact-lethal group removes foe 0, so its intent does not contribute to the block budget.
    int threat = 0;
    for (size_t index = 1; index < foes.size(); index++) {
      const Foe& foe = foes[index];
      if (foe.intent.kind.empty() || foe.intent.kind == "attack") {
        threat = std::max(threat, foe.intent.damage * foe.intent.hits);
      }
    }
    int have = battle.me.block;
    for (const Bolt& bolt : bolts) if (bolt.block) have += bolt.power;
    int room = std::max(0, threat - have);
    std::vector<int> spare;
    for (int i : candidates) if (!chosen.count(i) && bolts[i].power > 0) spare.push_back(i);
    std::sort(spare.begin(), spare.end(), [&bolts](int a, int b) {
      if (bolts[a].power != bolts[b].power) return bolts[a].power < bolts[b].power;
      return a < b;
    });
    for (int i : spare) {
      if (bolts[i].power <= room) {
        warded.insert(i);
        room -= bolts[i].power;
      }
    }
  }

  const int next_foe = foes.size() > 1 ? 1 : 0;
  for (int i : candidates) {
    if (chosen.count(i)) bolts[i].foe = 0;
    else if (warded.count(i)) bolts[i].block = true;
    else bolts[i].foe = next_foe;
  }
  return bolts;
}
