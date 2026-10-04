Bolts guard_echo(Bolts bolts, const Battle& battle) {
  Bolts out;
  for (const Bolt& b : bolts) {
    out.push_back(b);
    if (!b.ward.value_or(false)) {
      Bolt echo = b;
      echo.ward = true;
      echo.power = b.power / 4;
      out.push_back(echo);
    }
  }
  return out;
}
