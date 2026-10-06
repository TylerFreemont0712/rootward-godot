const { loavesFor } = require("./bakery");

function breadOrder(guestsByDay) {
  let loaves = 0;
  for (const guests of guestsByDay) {
    loaves += loavesFor(guests);
  }
  return loaves;
}

module.exports.breadOrder = breadOrder;
