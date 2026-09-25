function prefixSum(bolts, battle) {
  // Running totals: each bolt carries the sum of every bolt up to and including it.
  let total = 0;
  return bolts.map((bolt) => {
    total += bolt.power;
    return { ...bolt, power: total };
  });
}
