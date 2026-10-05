function runoff_echo(bolts, battle) {
  // Each strict rise produces a small echo; the cap keeps an already wide volley manageable.
  const result = bolts.map((bolt) => ({ ...bolt }));
  const attacks = bolts.filter((bolt) => !bolt.block && !bolt.stash);
  const echoes = [];
  for (let i = 1; i < attacks.length && echoes.length < 3 && result.length + echoes.length < 128; i++) {
    const before = attacks[i - 1];
    const after = attacks[i];
    if (after.power <= before.power) continue;
    const echo = { power: 1, element: after.element };
    if (after.foe !== undefined) echo.foe = after.foe;
    echoes.push(echo);
  }
  return result.concat(echoes);
}
