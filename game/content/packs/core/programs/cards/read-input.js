function readInput(bolts, battle) {
  // Input from outside: the battle is data the program reads. One bolt per living foe, as strong as its next attack.
  const heard = [];
  for (const foe of battle.foes || []) {
    const intent = foe.intent || {};
    heard.push({ power: Math.max(1, (intent.damage ?? 0) * (intent.hits ?? 1)), element: "none" });
  }
  return bolts.concat(heard);
}
