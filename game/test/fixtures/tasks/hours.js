function where(person, hour) {
  if (hour < 7 || hour >= 22) {
    return "home";
  }
  if (hour < 18) {
    return "work";
  }
  return "inn";
}
