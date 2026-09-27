function repeat(bolts, battle) {
  // A loop of fixed length (k = 3), so O(k) whatever the volley's size: three copies of the last bolt.
  const last = bolts.length > 0 ? bolts[bolts.length - 1] : { power: 4, element: "none" };
  for (let i = 0; i < 3; i++) bolts.push({ ...last });
  return bolts;
}
