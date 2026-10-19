function count(lanterns) {
  let lit = 0;
  for (const lantern of lanterns) {
    if (lantern["lit"]) {
      lit = lit + 1;
    }
  }
  return lit;
}
