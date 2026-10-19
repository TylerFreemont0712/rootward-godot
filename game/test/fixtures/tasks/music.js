function titles(tracks) {
  const names = [];
  for (const track of tracks) {
    names.push(track["title"]);
  }
  return names;
}

function nextTrack(index, count) {
  return (index + 1) % count;
}
