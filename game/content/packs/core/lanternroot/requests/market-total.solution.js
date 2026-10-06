function total(prices) {
  let result = 0;
  for (const price of prices) {
    result += price;
  }
  return result;
}

module.exports.total = total;
