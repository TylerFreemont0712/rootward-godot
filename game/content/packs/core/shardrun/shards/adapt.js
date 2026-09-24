function adapt(bolts, battle) {
  const foes = battle.foes;
  if (foes.length === 0 || foes[0].weak.length === 0) return bolts;
  const element = foes[0].weak[0];
  return bolts.map((bolt) => ({ ...bolt, element }));
}
