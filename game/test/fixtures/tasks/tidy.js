function total(bag) {
  let count = 0;
  for (const stack of bag) {
    count += stack.count;
  }
  return count;
}

function tidy(bag) {
  return bag.slice().sort((a, b) => (a.item < b.item ? -1 : 1));
}
