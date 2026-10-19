function credits(maker, parts) {
  const lines = ["The Makers"];
  lines.push("Made by " + maker);
  for (const part of parts) {
    lines.push("Built: " + part);
  }
  return lines;
}
