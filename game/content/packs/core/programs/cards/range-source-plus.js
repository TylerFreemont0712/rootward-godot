function rangeSourcePlus(bolts, battle) {
  // range(start, stop, step) counts from start in steps, stopping before stop: JavaScript has no range, so a loop.
  const counted = [];
  for (let power = 3; power < 15; power += 3) counted.push({ power, element: "none" });
  return bolts.concat(counted);
}
