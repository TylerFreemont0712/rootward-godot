Bolts runoff_echo(Bolts bolts, const Battle&) {
  // Each strict rise produces a small echo; the cap keeps an already wide volley manageable.
  Bolts echoes;
  std::optional<int> previous;
  for (const Bolt& bolt : bolts) {
    if (bolt.block || bolt.stash) continue;
    if (previous && bolt.power > *previous && echoes.size() < 3 && bolts.size() + echoes.size() < 128) {
      Bolt echo;
      echo.power = 1;
      echo.element = bolt.element;
      echo.foe = bolt.foe;
      echoes.push_back(echo);
    }
    previous = bolt.power;
  }
  bolts.insert(bolts.end(), echoes.begin(), echoes.end());
  return bolts;
}
