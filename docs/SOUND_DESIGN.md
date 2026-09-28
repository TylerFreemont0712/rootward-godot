# Sound design

What every sound in a fight is meant to be, written from the animation it accompanies. The player's report: "the
sound doesn't sound like it fits the animation or action that it's connected to a lot of the time". The audit below
says why: the sounds were designed as generic fantasy combat (stone, leather, fireballs rushing past, a knife, a
book), while the pictures are code-magic (lines of light drawing themselves, runes, brackets snapping shut,
hexagonal tiles, crystal splinters, blocks of code).

## Principles

1. **A sound belongs to its animation.** It starts when the animation starts and is designed on that animation's beats
   (the frame timings of `pipeline/sprites/spells.py`), so a heavy blow's three blocks each land with a sound and a
   critical blow can never be given a light hit's sound: the animation carries it.
2. **The pictures' materials, heard.** Light drawing itself is a rising glass shimmer; a rune is a small bright glyph
   tick; brackets snapping shut are a hard, bright clack; splinters are crystal; a block of code is a heavy, dense
   thud that crumbles into glass grit; a hex tile locking is a glassy click. Stone, leather, wood and paper belong only
   to the things that are made of them (cards, the map, the rooms).
3. **Weight follows the picture's weight.** A small cast's circle is a small sound; a grand one gathers in two waves.
   Hit, critical and heavy are three different sounds, chosen by the same rule that chooses the three animations.
4. **The element is a layer, not the sound.** Fire, frost and spark tint the pictures; they add a flare, a crackle of
   ice or a zap on top of a shared core, at the moment the picture takes their colour.
5. **Tuned to the music.** Pitched parts (runes, the ward's hum, the heal's shimmer) sit in D, the soundtrack's home.
6. **Variety where it repeats.** A volley lands twenty hits: each common sound has several takes, chosen at random
   and pitched a little by power, so a volley reads as a volley and not as one sample twenty times.

## The audit

Times are the animation's own (milliseconds from its first frame).

| Event | The picture (beats) | Plays now | Why it does not fit | The new sound |
|---|---|---|---|---|
| A program casts | `cast-sigil-1/-/-3/-4` by the cast's power: a circle draws itself (0-35%), runes take their places (8-42%), two brackets snap shut (28-44%), motes spiral in, it gathers (62-86%) and lets go (84%); a grand one doubles every layer and lets go in two waves; `cast-ground` adds runes rising round the caster | `sfx-cast`, or an element's (a fireball rushing past, ice cracking, an electric burst), its hit at 0 ms | Its loudest moment comes first, where the picture is only starting to draw; one sound for every size of spell; the fire version is a projectile, the picture is a seal releasing | Four sounds, one per tier, built on the sigil's beats: a rising glass shimmer as the circle draws, a tick per rune, a bright double clack for the brackets, a suction as it gathers, and the release, a bright burst with a low punch; the grand one's release twice. The element's layer joins at the release |
| A bolt lands (`hit-compile`) | Two brackets slam shut on the foe (190 ms), and it breaks open: a star, a ring racing out, splinters flung, runes scattered | `sfx-hit`: "a heavy impact on stone and leather" | A dull, low punch under a bright, sharp, glassy picture | A short in-rush as the brackets slam, a hard bright clack at 190 ms, a crystal burst and a thin ring sweep; the element's tint at the contact. Four takes |
| A critical blow (`hit-critical`) | Lines of light race in and a ring closes (0-192 ms); it breaks open with long spikes (192), a second shockwave (333 ms), splinters thrown far | `sfx-hit` or `sfx-hit-heavy`, chosen by a different rule (25% of the foe's HP, where the picture uses 18 damage or 45%) | A big hit on a sturdy foe gets the light sound under the critical picture | Its own sound: a reverse swell into a detonation at 192 ms (a sub punch, a bright crack), a second boom at 333 ms, a long glassy spray |
| A heavy cast's first blow (`hit-heavy`) | Three blocks of code appear one after another, hang, and drop: they land at 384, 576 and 896 ms, the last and largest the blow, each breaking into splinters and a ring of dust | `sfx-hit-heavy` once, after the whole animation | Two of the three landings are silent, and the one sound comes late | Three landings at 384, 576 and 896 ms: a dense block thud with glass grit, the third the biggest with a sub boom; a faint materialising shimmer and a short fall before each |
| A ward (`ward-hex`) | Hex tiles fly in and lock into a shield one after another (20-560 ms), a pulse runs across it (475-700 ms), it holds, then breaks up and its runes drift up (880 ms on) | `sfx-ward`: "a barrier forms with a deep airy impact, a rush of wind" | Close in spirit, but the picture's rhythm (tiles locking) and its pulse are missing | Glassy clicks converging as the tiles lock, a warm resonant hum for the pulse, a soft crystalline dissolve |
| A blow glances off (thick hide) | A popup: "glance" | `sfx-glance`: a glass shield ripple | A ripple is a shield's; nothing here is glass | A short ricochet: a hard tick and a bright ping flying off |
| A bolt is swallowed (nullify) | A popup: "nullified" | `sfx-glance`, pitched down | A glance is not a swallow | A hollow void gulp: the sound drawn into silence |
| A deadlock holds (the Golem's locks) | A popup: "locked", the foe recoils | `sfx-glance`, pitched down | A glance is not a lock | A heavy lock's clank, and a chain's rattle |
| A bolt flies at a fallen foe | A popup: "wasted" | `sfx-glance`, pitched up and quiet | Acceptable | A faint whiff of air past nothing |
| A foe breaks (`shatter`) | Cracks run out from its middle (0-295 ms), it bursts (340 ms), pieces tumble, runes rise | `sfx-shatter`: a crystal creature dissolving | The materials are right; the crack running out before the burst is missing | Creaking cracks spreading, the burst at 340 ms, pieces tumbling, a rising shimmer as the runes rise |
| A foe strikes the Maintainer (`claw`) | Three slashes torn across in quick succession (0, 51, 102 ms), each a dark cut with bright edges | `sfx-hurt`: "a punch against leather armour, a thud, a crack, a cloth rustle" | One thud for three slashes | Three fast tearing slashes, each a little different, over a short body impact |
| A strike is blocked | "N blocked" | `sfx-ward`, pitched up | A ward forming is not a blow meeting a shield | A blow meeting the hex shield: a bright glassy clang, damped |
| A foe acts first (`tempo`) | A clock face draws itself and its hand sweeps round once, fast, ticking | `sfx-charge`: a knife slice and a book flip | Nothing of a clock | A clock's quick ticking accelerating with the sweep, and a small bell as it ends |
| A foe stokes its fire | A popup: "stoked!" | `sfx-charge`: a knife slice and a book flip | Nothing of fire | A forge bellows' breath into a fire's whoomph |
| A foe raises a shield | "+N shield" | `sfx-ward` pitched down (the Maintainer's own ward) | A foe's shield is not the Maintainer's hex ward | A foe's guard: a heavy slab grinding up, a dull clunk |
| A foe or the Maintainer heals | "+N" | `sfx-heal` | Close | Kept, re-pitched to D |
| A curse burns | The Maintainer flashes | `sfx-curse` | Close | Kept |
| A program crashes (fizzle) | "fizzle" | `sfx-fail`: a hollow wooden knock | A crash is code failing | A glitch: an electrical sputter that dies |
| A program times out | "Time limit exceeded" | `sfx-fail` | Nothing of time | A clock running out: fast ticks cut off by a flat buzzer tone |
| A new turn | A banner | `sfx-turn` | Acceptable | Kept |
| A card is played, taken back, dealt | Cards move | `sfx-card` (a book placed), `sfx-draw` (a book flipped) | A book is heavier and duller than a card | Card sounds: a slide and a crisp place; a deal is a quick flick. Three takes |
| A line is written in the Program | The code panel writes a line | `sfx-charge` (a knife slice and a book flip) | Nothing of writing | A soft glyph typed: a light rune tick with a faint key click |
| Victory, defeat | Banners | `cue-victory`, `cue-defeat` | Unrelated to the music | Scored stingers of the main theme (`pipeline/music/tracks/victory`, `defeat`) |

## The palette

The ingredients the sounds are assembled from. Each is made once, several takes of it, and reused:

- **light-draw**: a rising glass shimmer (bowed glass, filtered); **rune-tick**: a tiny bright glyph tick in D;
  **bracket-clack**: two hard bright plates snapping shut; **gather**: a short suction into silence;
  **release**: a bright burst over a low punch.
- **crystal-burst**, **splinter-spray**, **ring-sweep**: the break-open of a hit and its splinters.
- **block-thud**, **block-grit**: a dense block landing, and the glass grit it breaks into; **sub-boom**.
- **tile-lock**, **ward-hum**, **dissolve**: the ward's tiles, its pulse, its end.
- **slash**: a tearing slash through air; **clang**: a blow on the hex shield.
- **tick**, **bell**, **buzzer**: the tempo clock and the time limit.
- **fire-flare**, **frost-crackle**, **spark-zap**: the elements' layers.
- **gulp**, **lock-clank**, **ricochet**, **whiff**, **glitch**, **slab**, **bellows**: the special events.
- **card-slide**, **card-place**, **card-flick**, **glyph-type**: the table and the Program.

## Production

1. **Ingredients** are generated (Stable Audio 3 in its sound-effects mode, several candidates each, prompted by
   material and gesture) or synthesised where exact pitch and shape matter (rune ticks in D, the ward's hum, sub
   booms, risers), and a few come from the CC0 packs already under `pipeline/sources/vendor` (cards, locks, chains).
2. **Each sound is a timeline** in the audio manifest: which ingredients, at which millisecond of its animation, at
   what level and pitch. The pipeline assembles, trims, levels and encodes it; a sound can be listened to against its
   animation (`pipeline/audio/beats.py` draws every take against its animation's beats).
3. **Variants**: `sfx-hit-1` to `-4` and the like; `Sound.play("sfx-hit")` picks one at random when variants exist.

## In the game

- `spells.json` names each animation's sound (and its element variants); `BattleStage.spell()` plays it when the
  animation starts. The log player stops playing hit sounds of its own, so a picture and its sound cannot disagree.
- The events without an animation (tempo's popup aside: it has the clock) get their own sounds: stoke, foe shield,
  blocked, nullify, locked, wasted, fizzle, timeout.

## As built (ADR-0020)

Every sound in the audit above is a `timeline` recipe in `pipeline/audio/manifest.json` with its animation's
`beats`; `spells.json` names each animation's sound, `SpellAnim` starts it with the first frame and adds the element's
layer at the impact, and the log player sounds only what has no animation. Victory and defeat are `Sound.cue`s.
