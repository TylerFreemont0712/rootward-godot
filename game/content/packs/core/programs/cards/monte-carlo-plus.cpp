Bolts monte_carlo_plus(Bolts bolts, const Battle& battle) {
  // A Monte Carlo method answers with random samples. The seed comes from the turn and the bolts, so the same
  // volley always rolls the same dice: what the preview shows is what the cast does.
  unsigned int seed = static_cast<unsigned int>(battle.turn);
  for (const Bolt& bolt : bolts) seed = seed * 31u + static_cast<unsigned int>(bolt.power);
  for (int i = 0; i < 8; i++) {
    seed = seed * 1664525u + 1013904223u;
    Bolt roll;
    roll.power = static_cast<int>((seed >> 16) % 6u) + 2;
    bolts.push_back(roll);
  }
  return bolts;
}
