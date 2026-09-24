function tithe(bolts, battle) {
  return bolts.map((bolt) => ({ ...bolt, power: Math.floor(bolt.power / 2), mult: bolt.mult * 2 }));
}
