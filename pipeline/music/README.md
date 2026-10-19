# The music pipeline

The soundtrack is composed, not prompted (ADR-0019). Each track is a **brief** (what it is for, its key, tempo and form)
and a **score** (ABC notation: its melody and chords, bar by bar). A model performs the score; the pipeline measures
every take, masters it the way the game will play it, and lays the takes out on a page to pick from. The composition
is ours, the performance is the model's.

```
brief.json + score.abc ──perform.py──▶ takes (yue2-…wav, seeded) ──listen.py──▶ index.html ──pick──▶ master.py ──▶ game
                            │  engine: comfy (ComfyUI)           │ analyze.py: tempo, key, loudness, colour, shape,
                            │  or native (yue2.cpp)              │   and how closely each bar holds the score
                            │                                    │ lyrics.py: what a song sings (Whisper)
                            └ every take: request, log, result   └ master.py: the game's file, the loop and its seam
```

| Step | Command | Writes |
|---|---|---|
| Check a score | `uv run --project pipeline python pipeline/music/notation.py check <score.abc>` (`sung` counts a song's syllables) | nothing |
| Perform a track | `uv run --project pipeline python pipeline/music/perform.py <track> --takes 2 [--seed 1000] [--engine auto]` | takes in `pipeline/cache/music/<track>/` (see below) |
| Perform a package | `uv run --project pipeline python pipeline/music/perform.py --package <name> --takes 2` | the same, track after track |
| Measure and lay out | `uv run --project pipeline python pipeline/music/listen.py [<track>...] [--package <name>] [--no-lyrics]` | `pipeline/cache/music/index.html` (or `index-<package>.html`), each take's master, seam clip and analysis |
| Master a take | `uv run --project pipeline python pipeline/music/master.py <track> [--take <take>] [--dest DIR]` | the take's master beside it; with the pick, `game/assets/audio/<out>.ogg` and its loop in `music.json` (`--dest`: there instead) |
| List tracks and packages | `uv run --project pipeline python pipeline/music/library.py [<package>]` | nothing |
| Measure any audio | `uv run --project pipeline python pipeline/music/analyze.py <audio>... [--bpm 76] [--key "F major"]` | nothing (`--out DIR` for the picture and numbers) |
| Test the pipeline | `uv run --project pipeline python -m unittest discover -s pipeline/music/tests -p 'test_*.py'` | nothing |

## Engines

`perform.py` plays a score with YuE2 in one of two engines. The score is the same; the takes are named and kept the
same way; the weights and the sampler are not.

- **comfy** (the default while ComfyUI is up): the `yue2_MusicGen` workflow as saved in the ComfyUI editor
  (`workflows/yue2_MusicGen.json`), run through ComfyUI's HTTP API (`comfy.py`). The workflow's planner (which writes
  its own score from the style) is not used: the composed score goes into the music node's `abc` input, so the take
  plays the score it was given. The checkpoint, sampler, decoder and output node are the workflow's own. The graph is
  checked against the running ComfyUI (its nodes and inputs) before it is sent, and a missing node in the saved
  workflow is refused by name.
- **native** (the default while ComfyUI is down): `yue-synth` from yue2.cpp (`YUE2_DIR`, default
  `~/personal-project/yue2.cpp`), the Q8_0 GGUF weights.

The seeds mean the same in both: the `lm_seed` draws the semantic tokens (the composition as YuE2 reads it), and the
`seed` draws the acoustic noise (the sound). The steps are the flow matching steps. They differ in: the checkpoint (the
workflow's int8 safetensors against the GGUF Q8_0), and the sampler (the workflow's `dpm_2` with `sgm_uniform` against
yue-synth's flow-matching ODE). So a ComfyUI take and a native take of the same seeds are different takes, named apart
(`yue2-comfy-…`).

The GPU holds one model at a time (8 GB). ComfyUI takes need ComfyUI up and Blender down; native takes need both down.
A perform run holds a lock in the takes folder, so two runs never load the GPU together. `--max-seconds 30` makes a
short take to prove a path (a smoke take); it is named by its own digest like any other.

## Takes, their cache and their logs

A take is `yue2-<lm seed>-<seed>-s<steps>-<digest>` (native) or `yue2-comfy-<lm seed>-<seed>-s<steps>-<digest>`. The
digest is six hex digits of the request the take was made from, so a revised score, style or setting is a new take, and
the old ones stay to be compared with. A take already in the cache is never rendered again: `perform.py` says `cached`
and goes on.

| File | What it is |
|---|---|
| `<take>.wav` | the take, 48 kHz stereo, 32-bit float (both engines) |
| `<take>.request.json` | what was asked: the style, the canonical score, the seeds, steps, duration and sampling; for ComfyUI the prompt itself |
| `<take>.log` | the native engine's output, or ComfyUI's job record |
| `<take>.result.json` | the measurements: seconds of audio, how long it took, times real time, peak GPU memory (MiB) |
| `<take>.tokens.csv`, `<take>.score.abc` | the native engine's semantic stream and the score it played |
| `<take>.partial.wav` | a take in progress; a failed one leaves nothing else behind |

`ROOTWARD_MUSIC_TAKES` moves the takes folder (`takes_dir` in config.json); `ROOTWARD_COMFY_URL` and `YUE2_DIR` the
other two paths.

## Packages

A package is a list of tracks made together: `packages/<name>.json`:

```json
{"name": "menu-and-lanternroot", "title": "The main menu and Lanternroot",
 "concept": "Concept/v0.3/05-lanternroot-overworld.md", "tracks": ["title", "lanternroot-front"]}
```

`perform.py --package` performs them one after another (never two GPU jobs at once), skips the takes already rendered,
goes on past a track that fails, and ends with a summary. `listen.py --package` lays out only those tracks. A track id
whose folder is not there yet is listed as missing and skipped, so a package can be written before its tracks. The
package file is checked when it is loaded (its name, its title, its ids, no repeats). `library.py <package>` says which
tracks have takes and which are still missing.

The package `menu-and-lanternroot` lists the title and the four Lanternroot tracks the composers had written when it was
made (`lanternroot-front`, `-home`, `-lesson`, `-town`); the conductor adds to it as they are written.

## Mastering and the game

`master.py` takes a track's brief and its take and makes the game's file: the take is placed on its score (below), its
loop is cut on the score's bar lines, its colour is corrected, and it is levelled.

- The loop (`loop: {from, to, occurrence}`) is in score bars: from the first bar of section `from` to the end of the
  `occurrence`-th section `to`. Placed on the take, its start and end are seconds. A take must be as long as the loop's
  end: a 30-second smoke take cannot be mastered as a loop (the listening page says so).
- Placement: the take's own beat (a line fitted through its tracked beats) and the downbeat nearest its first onset,
  then the downbeat within two bars whose bars best match the score's harmony (`analyze.adherence`).
- With the pick (`pick` in the brief), the file goes to `game/assets/audio/<out>.ogg` and its loop to `music.json`.
  Any other take, and a bonus track, is mastered beside its takes, as `<take>.master.ogg` (its seam clip is
  `<take>.seam.ogg`). Each take gets a master beside it, so the listening page plays every take the same way.

## Tests

`pipeline/music/tests/` (unittest, the pipeline's own environment, no GPU):

- `test_notation.py`: the check (bar lengths, lengths YuE2 never saw, sections, keys), the canonical form, the key
  signatures (`key_signature` reads a key, and refuses one it does not know rather than reading it as C major), the
  pitch classes of the melody in its key, the timeline, the loop's bars, and every committed track's score.
- `test_library.py`: take names and digests (a native take keeps its existing name), the cache's listing (partial files
  are not takes), briefs, and the package loader (missing tracks, malformed files).
- `test_comfy.py`: the saved workflow converted to the graph that performs a score: no planner, the score as the music
  node's input, the seeds, the duration and guidance, the links; a missing or doubled node refused; the node check; a
  ComfyUI that is down.
- `test_perform.py`: the native request (its digest is the one the existing `rest` take carries, so the cache still
  holds), the duration and cap, the ComfyUI request and its name.
- `test_analyze.py`: adherence bar by bar (a take that plays its score scores near 1, one that plays other bars near 0),
  the expected pitch classes, and the colour of the whole piece rather than its first minute.
- `test_master.py`: the loop's seconds from the bars, the shelves' limit, the start and end of the sound.

The fixtures in `tests/fixtures/` are copies of the `rest` track, so the tests do not move when a composer edits a track.

## Retired tools

`retired/` holds the ADR-0038 tools that read a `soundtrack.json` of slots (`manifest.py`, `plan.py`, `loops.py`,
`qc.py`, `install.py`); that file and its `music.sh` no longer exist, and nothing here runs them. `loops.py` (a
harmony-aware loop finder) is the one worth porting, to the brief's loop, if a track ever needs its loop found rather
than written.

## Models

- **YuE2** (m-a-p; `yue2.cpp`'s GGUF Q8_0 backbone 3.8 GB and its VAE for the native engine, the int8 safetensors
  checkpoint in the ComfyUI workflow; **CC BY-NC 4.0**, non-commercial): plays an ABC score it is given, melody and
  chords, in the style the brief describes, and sings lyrics. 48 kHz stereo, about 1.6× to 2.3× faster than real time on
  the laptop's GPU. The native weights are installed by `scripts/fetch-music-models.sh yue2`. Its licence suits Rootward,
  which is not sold; a commercial release would have to perform the scores again with another model.
- **ACE-Step 1.5** (MIT; 2B turbo, and the 4B XL SFT in ComfyUI) and **Stable Audio 3 Medium** (Stability AI Community
  Licence; instrumental, with inpainting and continuation) are fetched by `scripts/fetch-music-models.sh ace sa3` for
  comparison and repair work. Neither reads a score: they are prompted, which is what this pipeline replaced.
- **Whisper large-v3** (faster-whisper, CPU, MIT) transcribes songs for `lyrics.py`.

The GPU holds one model at a time (see Engines).

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
