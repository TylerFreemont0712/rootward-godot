Bolts global_total_plus(Bolts bolts, const Battle& battle) {
  // A global outlives the function that set it: the rules add every program's landed damage to total, and
  // battle.globals.at("total") is how a card reads it.
  return bolts;
}
