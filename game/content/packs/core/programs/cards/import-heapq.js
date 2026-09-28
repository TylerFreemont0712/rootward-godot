function importHeapq(bolts, battle) {
  // Runs before every strike card: the volley handed over strongest first, the order a max-heap pops it in.
  return bolts.slice().sort((a, b) => b.power - a.power);
}
