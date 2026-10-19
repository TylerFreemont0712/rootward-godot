function goodCode(code) {
  if (code.length !== 4) {
    return false;
  }
  if (!/^[0-9]+$/.test(code)) {
    return false;
  }
  if (code === code[0].repeat(4)) {
    return false;
  }
  return true;
}
