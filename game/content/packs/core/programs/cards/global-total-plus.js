function globalTotalPlus(bolts, battle) {
  // A global outlives the function that set it: the rules add every program's landed damage to total, and
  // battle.globals.total is how a card reads it.
  return bolts;
}
