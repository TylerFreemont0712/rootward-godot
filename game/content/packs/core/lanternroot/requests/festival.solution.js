const { loavesFor } = require("./bakery");
const { lampOil } = require("./lamps");
const { greeting } = require("./post");

function festivalPlan(guests) {
  return {
    loaves: loavesFor(guests.length),
    oil: lampOil(guests.length),
    letters: guests.map((name) => greeting(name)),
  };
}

module.exports.festivalPlan = festivalPlan;
