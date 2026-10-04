function jobSequencingPlus(bolts, battle) {
  // Job sequencing with deadlines: every foe is a job, its deadline the tempo of its intent (a bolt takes a slot of
  // 4 operations) and its profit the damage it intends. Take the jobs by profit, biggest first, and keep one only if
  // the bolts that kill it still fit before its deadline. Bolts no job needed go to the first job kept.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts;
  const tempo = foes.map((foe) => foe.intent?.tempo ?? 0);
  const profit = foes.map((foe) => (foe.intent?.damage ?? 0) * (foe.intent?.hits ?? 1));
  const need = foes.map((foe) => foe.hp + (foe.shield || 0));
  const order = foes.map((_, i) => i).sort((a, b) => Math.floor((profit[b] * 100) / Math.max(1, need[b])) - Math.floor((profit[a] * 100) / Math.max(1, need[a])) || profit[b] - profit[a] || tempo[a] - tempo[b] || a - b);
  const strongest = bolts.map((_, i) => i).sort((a, b) => bolts[b].power - bolts[a].power);
  const aim = bolts.map(() => -1);
  const kept = [];
  let used = 0;
  for (const job of order) {
    const slots = Math.floor(tempo[job] / 4);
    let taken = 0;
    let total = 0;
    while (used + taken < strongest.length && total < need[job]) {
      total += bolts[strongest[used + taken]].power;
      taken++;
    }
    if (total >= need[job] && used + taken <= slots) {
      for (let k = used; k < used + taken; k++) aim[strongest[k]] = job;
      used += taken;
      kept.push(job);
    }
  }
  const first = kept.length > 0 ? kept[0] : order[0];
  return bolts.map((bolt, i) => ({ ...bolt, foe: aim[i] < 0 ? first : aim[i] }));
}
