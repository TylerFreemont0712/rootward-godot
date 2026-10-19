function menuItems(built) {
  let items = ["continue"];
  for (const item of built) {
    items.push(item);
  }
  items.push("quit");
  return items;
}
