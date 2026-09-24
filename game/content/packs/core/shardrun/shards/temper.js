function temper(bolts, battle) {
  const tempered = [];
  for (const bolt of bolts) {
    let power = bolt.power;
    const leftOver = power % 5;
    if (leftOver !== 0) power = power + (5 - leftOver);
    tempered.push({ ...bolt, power });
  }
  return tempered;
}
