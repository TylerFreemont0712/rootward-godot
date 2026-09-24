function spectrumWheel(bolts, battle) {
  const colors = ["fire", "frost", "spark"];
  return bolts.map((b, i) => ({ ...b, element: colors[i % 3] }));
}
