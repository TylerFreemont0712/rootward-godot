#!/usr/bin/env bash
# The motion lab (ADR-0030): every clip of the move library on the motion dummy, with the cast's magic circle, slow
# motion, frame steps, limited or smooth playback and hand trails. ROOTWARD_SKIN=<id> opens another 3D skin.
exec "$(cd "$(dirname "$0")" && pwd)/play.sh" --lab
