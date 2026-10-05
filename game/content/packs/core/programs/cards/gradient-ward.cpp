Bolts gradient_ward(Bolts bolts, const Battle& battle) {
  // Compare attacking bolts in their existing order. Each strict rise pays one point from its higher bolt; equal
  // neighbours do not. Existing wards and stashed bolts do not take part in the sequence.
  std::vector<size_t> ids(bolts.size());
  std::iota(ids.begin(), ids.end(), 0);
  const bool was_sorted = std::is_sorted(bolts.begin(), bolts.end(), [](const Bolt& a, const Bolt& b) {
    return a.power < b.power;
  });
  std::vector<size_t> attacks;
  for (size_t i = 0; i < bolts.size(); i++) {
    if (!bolts[i].block && !bolts[i].stash) attacks.push_back(i);
  }
  if (attacks.empty()) return bolts;

  std::vector<size_t> sources;
  for (size_t i = 1; i < attacks.size(); i++) {
    if (bolts[attacks[i]].power > bolts[attacks[i - 1]].power) sources.push_back(attacks[i]);
  }
  if (sources.empty()) {
    size_t weakest = attacks.front();
    for (size_t i : attacks) {
      if (bolts[i].power < bolts[weakest].power) weakest = i;
    }
    sources.push_back(weakest);
  }

  Bolts wards;
  int gained = 0;
  for (size_t source_id : sources) {
    if (gained >= 6) break;
    size_t i = static_cast<size_t>(std::distance(ids.begin(), std::find(ids.begin(), ids.end(), source_id)));
    const int power = bolts[i].power;
    if (power <= 0) continue;
    if (power == 1) {
      // A one-power source can become a ward without adding another bolt.
      bolts[i].block = true;
      gained++;
      continue;
    }

    if (bolts.size() + wards.size() < 128) {
      bolts[i].power--;
      if (was_sorted) {
        while (i > 0 && bolts[i - 1].power > bolts[i].power) {
          std::swap(bolts[i - 1], bolts[i]);
          std::swap(ids[i - 1], ids[i]);
          i--;
        }
      }
      Bolt ward;
      ward.power = 1;
      ward.element = bolts[i].element;
      ward.block = true;
      wards.push_back(ward);
      gained++;
      continue;
    }

    // At the bolt limit, add the point to an existing ward. Never siphon if there is nowhere safe to put it.
    auto existing = std::find_if(bolts.begin(), bolts.end(), [](const Bolt& bolt) {
      return bolt.block && !bolt.stash && bolt.power < 9999;
    });
    if (existing != bolts.end()) {
      const size_t existing_id = ids[static_cast<size_t>(std::distance(bolts.begin(), existing))];
      bolts[i].power--;
      if (was_sorted) {
        while (i > 0 && bolts[i - 1].power > bolts[i].power) {
          std::swap(bolts[i - 1], bolts[i]);
          std::swap(ids[i - 1], ids[i]);
          i--;
        }
      }
      size_t existing_index = static_cast<size_t>(std::distance(ids.begin(), std::find(ids.begin(), ids.end(), existing_id)));
      bolts[existing_index].power++;
      if (was_sorted) {
        while (existing_index + 1 < bolts.size() && bolts[existing_index].power > bolts[existing_index + 1].power) {
          std::swap(bolts[existing_index], bolts[existing_index + 1]);
          std::swap(ids[existing_index], ids[existing_index + 1]);
          existing_index++;
        }
      }
      gained++;
    }
  }

  if (!wards.empty()) {
    // New wards carry 1 power. Place them before the first stronger bolt so a weakest-first volley stays ordered.
    auto insertion = std::find_if(bolts.begin(), bolts.end(), [](const Bolt& bolt) { return bolt.power > 1; });
    bolts.insert(insertion, wards.begin(), wards.end());
  }
  return bolts;
}
