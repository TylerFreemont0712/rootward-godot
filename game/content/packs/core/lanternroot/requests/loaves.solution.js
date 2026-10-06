function loavesFor(guests) {
  let loaves = Math.floor(guests / 4);
  if (guests % 4 !== 0) {
    loaves += 1;
  }
  return loaves;
}

module.exports.loavesFor = loavesFor;
