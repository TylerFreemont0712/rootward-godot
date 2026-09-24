function priorityQueue(bolts, battle) {
  const ordered = [...bolts].sort((a, b) => b.power - a.power);
  if (ordered.length > 0) ordered[0] = { ...ordered[0], target: "strongest" };
  return ordered;
}
