function countSacks(sacks) {
  const counts = {};
  for (const name of sacks) {
    counts[name] = (counts[name] || 0) + 1;
  }
  return counts;
}

module.exports.countSacks = countSacks;
