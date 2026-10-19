function add(bag, item) {
  for (const stack of bag) {
    if (stack.item === item) {
      stack.count += 1;
      return bag;
    }
  }
  bag.push({ item: item, count: 1 });
  return bag;
}

function remove(bag, item) {
  for (const stack of bag) {
    if (stack.item === item) {
      stack.count -= 1;
      if (stack.count === 0) {
        bag.splice(bag.indexOf(stack), 1);
      }
      return bag;
    }
  }
  return bag;
}
