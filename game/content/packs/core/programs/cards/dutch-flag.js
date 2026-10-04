function dutchFlag(bolts, battle) {
  // Dijkstra's three regions grow in place: exact, greater, then smaller than the pivot value.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const need = foes[0].hp + (foes[0].shield || 0);
  const result = bolts.map((bolt) => ({ ...bolt }));
  let low = 0;
  let scan = 0;
  let high = result.length - 1;
  while (scan <= high) {
    if (result[scan].power === need) {
      [result[low], result[scan]] = [result[scan], result[low]];
      low++;
      scan++;
    } else if (result[scan].power > need) {
      scan++;
    } else {
      [result[scan], result[high]] = [result[high], result[scan]];
      high--;
    }
  }
  for (let i = 0; i < low; i++) {
    result[i].pivot = true;
    result[i].power += 0;
  }
  return result;
}
