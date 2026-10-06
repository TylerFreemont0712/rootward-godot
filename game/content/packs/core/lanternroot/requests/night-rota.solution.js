function watchRota(names, nights) {
  const rota = [];
  for (let night = 0; night < nights; night++) {
    rota.push(names[night % names.length]);
  }
  return rota;
}

module.exports.watchRota = watchRota;
