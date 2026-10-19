function changed(old, latest) {
  const lines = [];
  for (let i = 0; i < Math.max(old.length, latest.length); i++) {
    if (i >= old.length || i >= latest.length) {
      lines.push(i + 1);
      continue;
    }
    if (old[i] !== latest[i]) {
      lines.push(i + 1);
    }
  }
  return lines;
}
