function postage(grams) {
  if (grams <= 10) {
    return 2;
  } else if (grams <= 50) {
    return 5;
  } else {
    return 9;
  }
}

module.exports.postage = postage;
