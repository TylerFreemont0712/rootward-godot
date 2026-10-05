Bolts deadline_mint(Bolts bolts, const Battle& battle) {
  // Pick the lowest-tempo attack. On a tempo tie, prefer more total damage; exact ties keep the first foe.
  int best_index = -1;
  int best_tempo = 0;
  int best_total = 0;
  for (size_t i = 0; i < battle.foes.size(); i++) {
    const Foe& foe = battle.foes[i];
    const Intent& intent = foe.intent;
    if (foe.hp <= 0 || intent.kind != "attack" || intent.damage <= 0 || intent.hits <= 0) continue;
    const int total = intent.damage * intent.hits;
    if (best_index < 0 || intent.tempo < best_tempo || (intent.tempo == best_tempo && total > best_total)) {
      best_index = static_cast<int>(i);
      best_tempo = intent.tempo;
      best_total = total;
    }
  }

  if (best_index >= 0 && bolts.size() < 128) {
    Bolt minted;
    minted.power = std::min(best_total, 8);
    minted.element = "none";
    minted.foe = best_index;
    bolts.push_back(minted);
  }
  return bolts;
}
