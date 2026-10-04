Bolts dutch_flag_plus(Bolts bolts, const Battle& battle) {
  // Dijkstra's three regions grow in place: exact, greater, then smaller than the pivot value.
  if (battle.foes.empty()) return bolts;
  const int need = battle.foes[0].hp + battle.foes[0].shield;
  int low = 0;
  int scan = 0;
  int high = static_cast<int>(bolts.size()) - 1;
  while (scan <= high) {
    if (bolts[scan].power == need) {
      std::swap(bolts[low], bolts[scan]);
      low++;
      scan++;
    } else if (bolts[scan].power > need) {
      scan++;
    } else {
      std::swap(bolts[scan], bolts[high]);
      high--;
    }
  }
  for (int i = 0; i < low; i++) {
    bolts[i].pivot = true;
    bolts[i].power += 1;
  }
  return bolts;
}
