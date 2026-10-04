function rangeSource(bolts, battle) {
  // range(start, stop, step) counts from start in steps, stopping before stop: JavaScript has no range, so a loop.
  const counted = [];
  for (let power = 2; power < 10; power += 2) counted.push({ power, element: "none" });
  return bolts.concat(counted);
}
