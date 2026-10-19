function timeOfDay(minute) {
  if (minute < 360) {
    return "night";
  }
  if (minute < 720) {
    return "morning";
  }
  if (minute < 1080) {
    return "afternoon";
  }
  if (minute < 1260) {
    return "evening";
  }
  return "night";
}

function clockText(minute) {
  const hours = Math.floor(minute / 60);
  const mins = minute % 60;
  return hours + ":" + String(mins).padStart(2, "0");
}
