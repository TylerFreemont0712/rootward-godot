function higherOrderPlus(bolts, battle) {
  // A function that makes functions: map a small lambda over the volley now, and two more are written for later.
  const step = (bolt) => ({ ...bolt, power: bolt.power + 2 });
  return bolts.map(step);
}
