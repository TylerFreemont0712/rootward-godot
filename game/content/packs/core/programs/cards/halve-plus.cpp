Bolts halve_plus(Bolts bolts, const Battle& battle) {
  // The divide step by itself: the volley is cut at ceil(n / 2) and the card after this one runs on each half.
  // The cut is a rule, so a card can find it without being told: the first bolt of the right half is bolts[half].
  const int half = (static_cast<int>(bolts.size()) + 1) / 2;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    if (i == 0 || i == half) bolts[i].power += 1;
  }
  return bolts;
}
