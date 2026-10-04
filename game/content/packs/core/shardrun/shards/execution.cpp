Bolts execution(Bolts bolts, const Battle& battle) {
  bool ready = false;
  for (const Foe& f : battle.foes) {
    if (f.hp * 2 <= f.max) {
      ready = true;
      break;
    }
  }
  for (Bolt& b : bolts) {
    if (ready && !b.ward.value_or(false)) {
      b.target = "weakest";
      b.mult = b.mult.value_or(1) * 3;
    }
  }
  return bolts;
}
