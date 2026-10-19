function volume(slider) {
  slider = Math.max(slider, 0);
  slider = Math.min(slider, 10);
  return slider / 10;
}
