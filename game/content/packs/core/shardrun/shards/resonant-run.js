function resonantRun(bolts, battle) {
  let previous = null, streak = 0;
  return bolts.map(b => {
    streak = b.element === previous ? streak + 1 : 1;
    previous = b.element;
    return { ...b, mult: b.mult * streak };
  });
}
