def good_code(code):
    if len(code) != 4:
        return False
    if not code.isdigit():
        return False
    if code == code[0] * 4:
        return False
    return True
