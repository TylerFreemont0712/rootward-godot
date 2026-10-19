def price(prices, item, count):
    if item in prices:
        return prices[item] * count
    return 0


def can_buy(coins, cost):
    return coins >= cost
