# The music pipeline

The soundtrack is composed, not prompted (ADR-0019). Each track is a **brief** (what it is for, its key, tempo and
form) and a **score** (ABC notation: its melody and chords, bar by bar). A model performs the score; the pipeline
measures every take, masters it the way the game will play it, and lays the takes out on a page to pick from. The
composition is ours, the performance is the model's.

```
brief.json + score.abc ──perform.py──▶ takes (YuE2, seeded) ──listen.py──▶ index.html ──pick──▶ master.py ──▶ game
                                            │                   │ analyze.py: tempo, key, loudness, colour, shape,
                                            │                   │   and how closely each bar holds the score
                                            │                   │ lyrics.py: what a song sings (Whisper)
                                            │                   └ master.py: a master and the loop's seam, to hear
```

| Step | Command | Writes |
|---|---|---|
| Check a score | `uv run --project pipeline python pipeline/music/notation.py check <score.abc>` (`sung` counts a song's syllables) | nothing |
| Perform takes | `uv run --project pipeline python pipeline/music/perform.py <track> --takes 2 [--seed 1000]` | `pipeline/cache/music/<track>/yue2-<lm seed>-<seed>-s<steps>-<digest>.wav` and the request, score, semantic codes and log beside it |
| Measure, master and lay out every take | `uv run --project pipeline python pipeline/music/listen.py [<track>...]` | `pipeline/cache/music/index.html` (open it in a browser), `<take>.master.ogg`, `<take>.seam.ogg`, `analysis/` |
| Put the pick in the game | set `"pick": "<take>"` in the brief, then `uv run --project pipeline python pipeline/music/master.py <track>` | `game/assets/audio/<out>.ogg`, its loop in `music.json` |

A take's name carries its seeds and a digest of its request, so a revised score or style is a new take and the old
ones stay to be compared with; a take already rendered is never rendered again. Everything in the cache can be thrown
away and remade from the briefs, scores and seeds.

## Models

- **YuE2** (m-a-p, `yue2.cpp`, GGUF Q8_0 backbone 3.8 GB and its VAE; **CC BY-NC 4.0**, non-commercial): plays an ABC
  score it is given, melody and chords, in the style the brief describes, and sings lyrics. 48 kHz stereo, about 1.6×
  to 2.3× faster than real time on the laptop's GPU. Installed by `scripts/fetch-music-models.sh yue2`. Its licence
  suits Rootward, which is not sold; a commercial release would have to perform the scores again with another model.
- **ACE-Step 1.5** (MIT; 2B turbo, and the 4B XL SFT in ComfyUI) and **Stable Audio 3 Medium** (Stability AI Community
  Licence; instrumental, with inpainting and continuation) are fetched by `scripts/fetch-music-models.sh ace sa3` for
  comparison and repair work. Neither reads a score: they are prompted, which is what this pipeline replaced.
- **Whisper large-v3** (faster-whisper, CPU, MIT) transcribes songs for `lyrics.py`.

The GPU holds one model at a time: `perform.py` refuses to start while ComfyUI or Blender is up.

## The brief

`tracks/<id>/brief.json`:

| Field | Meaning |
|---|---|
| `id`, `out` | the track's folder, and the file it becomes in `game/assets/audio/` (`music-…`, `cue-…`) |
| `kind` | `loop` (the default: plays under a scene and loops), `cue` (a short stinger, faded), or `bonus` (not in the game) |
| `title`, `role`, `theme`, `reference` | what it is, where it plays and what it must do there, the motif it carries, and what it answers (the old track, a request) |
| `bpm`, `key`, `meter`, `form` | the score's facts, restated for the reader and for the measurements |
| `loop` | `{from, to, occurrence}`: the loop runs from the first bar of section `from` to the end of the `occurrence`-th `to` |
| `style` | YuE2's style tags, comma separated, ending in the key and tempo; an instrumental says `instrumental, no vocals` |
| `lyrics` | a song's sung sections in order (`[Verse]`, `[Pre-Chorus]`, `[Chorus]`, `[Bridge]`), empty for an instrumental |
| `pick` | the take that goes into the game |

## The score

ABC in the layout YuE2 was trained on (the one SheetSage2, its transcriber, writes):

- `L:1/16`, and only the lengths the transcriber writes: 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48 sixteenths. A 14 is
  written `z12z2` (a rest) or `c12-c2` (a tied note). `check` refuses anything else.
- Two voices: `V: Vocal` carries the chord symbols (`"Dm"`) at the start of every bar and wherever the chord changes,
  over rests in an instrumental and over the sung melody in a song; `V: Ins` carries the instrumental melody. Rests
  that fill whole bars are `Z` or `Z4`.
- Sections are `% name` comments (`intro`, `verse`, `pre-chorus`, `chorus`, `bridge`, `interlude`, `outro`, and
  `silence` for the one empty bar every score starts with), and each voice writes at most four bars at a time.
- A key change is a `K:` line after each voice's `V:` line, in the first group of bars in the new key.
- YuE2 is given the score in canonical form (`notation.canonical`): no title and no spaces inside a bar. The score
  files keep spaces between beats for the reader.

A song's lyrics line up with the Vocal voice one syllable to a note (a tied note continues the syllable before it). A
pickup into a section is written at the end of the previous section's last bar, as the transcriber does. `notation.py
sung <score>` counts the notes each section sings, to count syllables against.

## The motif

One leitmotif runs through the soundtrack: scale degrees 1 5 1 3 2 1, D A D F# E D in the title's D major, and in D
minor (`d4 A2d2 f4 e2d2`) the opening of Salvage Skirmish's melody. Each track carries it in its own guise (its
brief's `theme`): a lilting waltz in the Salvage, syncopated in its fights, bent by a chromatic neighbour in the Heap,
slowed to a hymn in the Kernel and driven by brass in its fights, at its darkest in the Guardian's low brass and
corrupted by a Phrygian flat second in the final one, a lullaby at rest, a fanfare at victory, falling to a bare low A
at defeat, and the opening of the bonus song's chorus.

## The measurements

A take is judged by numbers and a picture, since nobody in the loop can hear it (`analyze.py`):

| Number | What it says | Aim |
|---|---|---|
| tempo, steadiness, drift | the beat the take really keeps (YuE2 runs a percent or two off the asked tempo, steadily) | steadiness under 0.05 |
| key | the chroma's best match among the 24 keys | the brief's |
| follows its score | per bar, the correlation between the chroma heard and the pitch classes the score spells there | 0.6 and up; under 0.3 is a bar that went its own way |
| LUFS, LRA, true peak | loudness, loudness range, peak (EBU R128) | a master sits at −20 LUFS (loops), −17 (cues), −16 (bonus) |
| over 5 kHz, under 150 Hz | air and weight: the share of energy in each | about 1.2% and 20% after mastering |
| repetition, section turns | the self-similarity of the piece and where its sections change | the turns near the score's sections |
| seam | the spectral jump from a loop's end into its start, against the piece's usual change from one moment to the next | about 1 |
| lyrics (songs) | Whisper's transcript against the lyrics: words heard, misheard, missed | an error rate under 0.3 |

Mastering (`master.py`) places the take on its score (the beat grid fitted to the take, the first downbeat confirmed
by how well the score's harmony matches from there), cuts the loop on bar lines, crossfades the seam, shelves the
bass and treble toward the soundtrack's colour (at most 6 dB), and levels with one gain so a loop's end meets its
start at the same level.
