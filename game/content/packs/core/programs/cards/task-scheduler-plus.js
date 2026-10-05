function taskSchedulerPlus(bolts, battle) {
  // Task scheduling with a cooldown of one: always take the element with the most bolts left that is not the one
  // just used. Only a spacer inserted when no task is eligible is marked idle for Handoff Ward.
  const names = [];
  const rows = [];
  for (const bolt of bolts) {
    if (!names.includes(bolt.element)) {
      names.push(bolt.element);
      rows.push([]);
    }
    rows[names.indexOf(bolt.element)].push(bolt);
  }
  const used = names.map(() => 0);
  const result = [];
  let last = -1;
  let left = bolts.length;
  while (left > 0) {
    let pick = -1;
    for (let k = 0; k < names.length; k++) {
      if (k !== last && used[k] < rows[k].length) {
        if (pick < 0 || rows[k].length - used[k] > rows[pick].length - used[pick]) pick = k;
      }
    }
    if (pick < 0) {
      result.push({ power: 2, element: "none", idle: true });
      last = -1;
      continue;
    }
    result.push({ ...rows[pick][used[pick]] });
    used[pick]++;
    left--;
    last = pick;
  }
  return result;
}
