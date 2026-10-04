Bolts import_copy(Bolts bolts, const Battle& battle) {
  for (int i = static_cast<int>(bolts.size()) - 1; i >= 0; i--) {
    if (!bolts[i].block) {
      Bolt echo = bolts[i];
      echo.power = static_cast<int>(std::ceil(echo.power / 2.0));
      bolts.push_back(echo);
      return bolts;
    }
  }
  return bolts;
}
