function progress(done, total) {
  if (total === 0) {
    return 0;
  }
  return Math.floor(done * 100 / total);
}
