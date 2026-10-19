function price(prices, item, count) {
  if (item in prices) {
    return prices[item] * count;
  }
  return 0;
}

function canBuy(coins, cost) {
  return coins >= cost;
}
