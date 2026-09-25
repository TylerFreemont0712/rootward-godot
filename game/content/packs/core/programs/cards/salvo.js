function salvo(bolts, battle) {
  // A rising run of six bolts, after whatever came before.
  const rising = [];
  for (let p = 1; p <= 6; p++) rising.push({ power: p, element: "none" });
  return bolts.concat(rising);
}
