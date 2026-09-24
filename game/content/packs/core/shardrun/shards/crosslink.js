function crosslink(bolts, battle) {
  return bolts.map((bolt, index) => {
    let kin = 0;
    for (let other = 0; other < bolts.length; other += 1) {
      if (other !== index && bolts[other].element === bolt.element) kin += 1;
    }
    return { ...bolt, mult: bolt.mult + kin };
  });
}
