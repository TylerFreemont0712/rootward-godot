"""Shared set-up for the music tests: the pipeline's folder on the import path, and the repository's own paths."""

import sys
from pathlib import Path

MUSIC = Path(__file__).resolve().parents[1]
if str(MUSIC) not in sys.path:
    sys.path.insert(0, str(MUSIC))
