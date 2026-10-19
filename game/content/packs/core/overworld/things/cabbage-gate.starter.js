function onUse(thing, player) {
  if (thing.keys.length === 4) {
    return {set: {open: true}, say: "The gate swings open. Walk through."};
  }
  return {say: "The gate stays shut until your boots know all four ways."};
}
