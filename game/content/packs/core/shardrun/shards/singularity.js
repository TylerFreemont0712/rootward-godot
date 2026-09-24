function singularity(bolts, battle) {
  const count = bolts.length;
  if (count === 0) return bolts;
  return [{ power: 4 * count, element: "none", target: "strongest", pierce: true, ward: false, mult: count }];
}
