# The soundtrack, solid: a groove, a hook, and no lullaby

Written 2026-10-13 from the player's note: the main menu is a little too lullaby-like, and they would like a more solid
soundtrack concept. The title theme is the first piece written to this concept; the four Lanternroot pieces followed it
(section 6). The pipeline is in `pipeline/music/README.md`: a brief and a score are written here, a model performs them,
and the player picks a take.

## 1. What the player asked for

A main menu that sounds like a game worth going down into, not a bedtime story. In the player's words, a little more
"solid": something with a beat, a tune to hum, and sections that feel different from each other.

## 2. What "solid" means here

Four things, in order of importance. Each one can be checked by ear, and most by the measurements in the pipeline.

- **A pulse you can tap your foot to.** A groove under the melody from the first bar: a strummed guitar on the beat,
  an upright bass on the root, drums with a backbeat. Tempo 96 to 110 BPM, in 4/4. Nothing rubato, nothing that drifts.
- **A melody you can hum.** Phrases of four bars, a clear top line, stepwise motion with a leap at each turn, and
  rhythms that move (eighths, the odd dotted eighth), not long sustained notes.
- **Sections with contrast.** A verse, a lift (pre-chorus), a chorus that is bigger than the verse, a bridge in another
  key area, and a final chorus that is the biggest thing in the piece. The listener should always know which part they
  are in.
- **Fuller and brighter.** The old title had nothing above 5 kHz and a centroid of 490 Hz, so it sounded muffled and
  far away. Solid means the top is there: fiddle, flute and horns sit in the air, and the bass is weight rather than
  mud. The pipeline aims for about 1.2% of the energy over 5 kHz and about 20% under 150 Hz after mastering.

## 3. The palette: lantern folk with a backbeat

Folk instruments carry the melody, and a rock-style rhythm section carries the pulse. The score can only write the
melody and the chords, so the palette is set in each brief's `style` line and performed by the model.

| Role | Instruments | Notes |
|---|---|---|
| Pulse | Strummed acoustic guitar, upright bass (or a warm electric bass), live drums | Brushes when calm, sticks when bold; the backbeat on 2 and 4 |
| Melody | Fiddle, wooden flute or tin whistle, accordion | One melodic voice at a time; the fiddle is the hook's voice |
| Big statements | French horns, brass | Only in the chorus that is the biggest, and the final one |
| Engine | Strings as an ostinato (short repeated figures) | A moving line under the chords, not a pad |

Not in the palette for the menus: harp and celesta as the main voices, music boxes, and soft pads that carry the whole
piece. A harp may pluck a figure under the guitar; it may not be the groove.

## 4. Tempo, key and metre

| Setting | Range | Why |
|---|---|---|
| Tempo, all menu and town pieces | 96 to 110 BPM | Tappable. Below about 80 BPM the pieces read as lullabies (the old `rest` track is 76). |
| Metre | 4/4 for the menus and the town; 3/4 only in a deliberate waltz (the Salvage) | The waltz is a place's identity, not a menu's |
| Keys, menus and town | D major, G major, A major (the title is D) | Bright keys that suit horns and fiddle |
| Keys, contrast | B minor or G major for a bridge; E minor or A minor for a quiet verse | A key change is a section change, written with a `K:` line |
| Keys to avoid for the menus | F major and C minor (the rest and the kernel) | They read as calm and far away |

The motif is 1 5 1 3 2 1. In D major that is D A D F# E D; it sounds the same wherever it is transposed, which is why
the motif can be the hook in a major key and still be the same tune as the lullaby in F major.

## 5. How the motif appears

The motif is the soundtrack's leitmotif (`pipeline/music/README.md`). Each piece carries it in its own guise, so the
player hears one tune across the package without hearing the same piece twice.

| Piece | Where it plays | The motif's guise |
|---|---|---|
| `title` | The title screen and the menus between runs | The whole hook. Whistled in the intro, stated boldly by the fiddle in the verse, climbed a fourth in the chorus (G D G B A G), on B minor in the chorus's fifth bar, an octave up in the final chorus, and sung down in the bridge (F# E D). |
| `lanternroot-front` | The character select screen | Stated whole and plain in the verse's first two bars (D A D F# E D in quarter notes) on plucked guitar; the chorus lifts 1 3 2 1 an octave in eighths and closes each phrase on E D |
| `lanternroot-town` | Walking the town | In G (G D G B A G) as the fiddle's first bar in eighths; the whistle chorus climbs the same shape in dotted rhythms; the bridge sighs down its tail (B A G) in E minor colour |
| `lanternroot-home` | Indoors | In A (A E A C# B A) on guitar and accordion, restated after the chorus, which lifts it an octave into arpeggios |
| `lanternroot-lesson` | Coding with the boots and the things that take code | In E minor (E B E G F# E) as a repeating marimba figure with a rest closing each bar, rebuilt on each chord like a loop re-running over new inputs |

Lanternroot's music is one track per place with the same motif in each one's guise. The front door is a steady groove in
D major at 100 BPM, its plucked guitar stating the motif in full. Walking the town is lively folk with a backbeat at 110
BPM in G major: the fiddle opens on the motif, a whistle chorus climbs, a minor sigh of a bridge gives way to a return.
Indoors (the house, the inn, the workshop) a warm steady pulse at 92 BPM in A major has guitar and accordion carrying
it. The coding screens get the quietest loop, at 116 BPM in E minor: a marimba plays the motif as a repeating figure
under a steady pulse, so the eyes can stay on the code. None of them uses harp, celesta or music box carrying the tune,
and none is under 80 BPM.

## 6. The package

| Track | Plays | Status | Brief and score |
|---|---|---|---|
| `title` | The main theme: the title screen and the menus between runs | Written (D major, 104 BPM, 4/4). The game still plays the old take until a new one is picked. | `pipeline/music/tracks/title/` |
| `lanternroot-front` | The character select screen | Written (D major, 100 BPM; 21 bars, a 16-bar loop of 38 s) | `pipeline/music/tracks/lanternroot-front/` |
| `lanternroot-town` | Walking the town | Written (G major, 110 BPM; 49 bars, a 40-bar loop of 87 s) | `pipeline/music/tracks/lanternroot-town/` |
| `lanternroot-home` | Indoors | Written (A major, 92 BPM; 49 bars, a 40-bar loop of 104 s) | `pipeline/music/tracks/lanternroot-home/` |
| `lanternroot-lesson` | Coding with the boots and the things that take code: steady and unobtrusive | Written (E minor, 116 BPM; 33 bars, a 24-bar loop of 50 s) | `pipeline/music/tracks/lanternroot-lesson/` |

The title's form, for reference: silence 1, intro 4 (a whistled hook, the groove from its first bar), verse 8 (the motif,
bold), verse 8 (answered by the flute and strings), pre-chorus 4 (the lift), chorus 8 (the hook, full band), bridge 8
(G major, rising, horns), chorus 8 (the final chorus, an octave up, horns), outro 4. Its loop runs from the first verse
to the end of the final chorus, about 101 seconds at 104 BPM, so the seam is the chorus's tonic D back to the verse's
tonic D. The outro lies past the loop's end and so is cut from the game's file; it is in the full take.

## 7. What to avoid

- **The lullaby recipe**: a harp, celesta or music box carrying everything; rubato; tempos under about 80 BPM; sparse
  textures with one line and nothing under it; endless pads with no pulse; a 3/4 lilt for a menu.
- **Mud**: nothing below 150 Hz that is not the bass, and nothing that stays under 5 kHz for a whole piece.
- **A chorus that is the same as the verse.** The chorus needs a bigger band, a higher register or a new key area.
- **A groove that stops.** A loop that drops its drums at the seam is no longer solid; the seam is measured (`seam`,
  about 1 is the aim).

## 8. Performing and picking takes

These are the commands in `pipeline/music/README.md`, run from the repository root. The GPU holds one model at a time,
so stop ComfyUI and Blender first (`perform.py` refuses to start while either is up).

1. Check the score: `uv run --project pipeline python pipeline/music/notation.py check pipeline/music/tracks/<track>/score.abc`
2. Perform takes: `uv run --project pipeline python pipeline/music/perform.py <track> --takes 2`, with `--seed 1000` or
   another seed for a different pair. A take already rendered is never rendered again, and a revised score is a new take.
3. Measure and listen: `uv run --project pipeline python pipeline/music/listen.py <track>`, then open
   `pipeline/cache/music/index.html` in a browser. Each take shows its tempo, key, loudness, how closely each bar holds
   the score, and its seam.
4. Pick: set `"pick": "<take>"` in the track's `brief.json`, then `uv run --project pipeline python pipeline/music/master.py <track>`.
   The game file is `game/assets/audio/<out>.ogg`, and its loop goes into `music.json`.

The package's tracks are listed in `pipeline/music/packages/menu-and-lanternroot.json`, which the pipeline engineer is
adding; run the commands above for each track it lists.
