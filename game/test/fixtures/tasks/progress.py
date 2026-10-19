def progress(done, total):
    if total == 0:
        return 0
    return done * 100 // total
