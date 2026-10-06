function loavesFor(guests, perLoaf = 4) {
  let loaves = Math.floor(guests / perLoaf);
  if (guests % perLoaf !== 0) {
    loaves += 1;
  }
  return loaves;
}

module.exports.loavesFor = loavesFor;
