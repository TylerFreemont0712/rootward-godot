Bolts break_loop_plus(Bolts bolts, const Battle& battle) {
  // Hit the front foe with each bolt in turn; the moment it falls, break out of the loop. The bolts after the kill
  // are never touched, and the loop's work is only the bolts it used.
  if (battle.foes.empty()) return bolts;
  int remaining = battle.foes[0].hp + battle.foes[0].shield;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    bolts[i].foe = 0;
    remaining -= bolts[i].power;
    if (remaining <= 0) {
      if (battle.foes.size() > 1) {
        for (int j = i + 1; j < static_cast<int>(bolts.size()); j++) bolts[j].foe = 1;
      }
      break;
    }
  }
  return bolts;
}
