function repeatPlus(bolts, battle) {
  // A loop of fixed length (k = 4), so O(k) whatever the volley's size: four copies of the last bolt.
  const last = bolts.length > 0 ? bolts[bolts.length - 1] : { power: 4, element: "none" };
  for (let i = 0; i < 4; i++) bolts.push({ ...last });
  return bolts;
}
