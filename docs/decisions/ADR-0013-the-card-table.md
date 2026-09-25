# ADR-0013: the card table

- Status: accepted
- Date: 2026-09-26
- Related: ADR-0009 (the card Shardrun), ADR-0012 (programs), ADR-0004 (the art pipeline's manifest)

## Context

The player, after the first program runs: "start giving it a 'card' dynamic... make them look like actual cards and
seem like they are held in your 'hand', think slay the spire: when a card is hovered it has a small movement then you
can see the details. The base view doesn't need the details, just the name." Also: slightly bigger cards; padding in
the Program so its highlight does not crowd the text; details that were "too thin" and ran "way too far down"; the
Beginner summary "in green or comment style"; new art for the card; a guardian's HP "centered and in the middle"; the
turn ending by itself after the cast, the button reading like running the file; a detailed portrait of the worn skin
beside the numbers; a `.log` button instead of the scrolling log; a wider code panel.

## Decision

- **A card is a painted frame** (`assets/cards/frame.png`) with a window for its picture, its name on a banner, its
  mana cost on a crystal orb and its speed on a plate. The frame is one neutral steel-and-gold painting, tinted per
  paradigm by `ui/card_tint.gdshader` (grey takes the paradigm's colour, saturated gold and violet stay), so a new
  paradigm needs only a colour. A missing frame falls back to one drawn in code.
- **The frame is generated to a fixed geometry.** `pipeline/art/layouts.py` draws the card's layout in flat shapes,
  ComfyUI (NovaAnimeXL, img2img at 0.7 denoise) dresses it in filigree, and the post-process cuts the window and the
  outline with a mask drawn from the same numbers, repaints the banner and the plate clean for text, and writes those
  numbers as `frame.json`, which `CardFace` reads. The card back (the piles) is made the same way.
- **The hand is held** (`HandView`): fanned in an arc, resting low with the lower part of each card off the screen's
  edge, the pointed-at card upright, lifted whole and grown by a fifth, its neighbours leaning aside. Cards keep
  Godot's drag and drop and the click-on-release of ADR-0009.
- **Details beside the card** (`CardDetail`): shown while a card is pointed at, anywhere a card appears (hand, slots,
  deck, draft), as a top-level panel so no clipped table hides it. It is 580 wide and at most about thirteen code lines
  tall: name, speed, cost, role, paradigm, what it needs and leaves, the summary as green comment lines in the run's
  language (`# ...` or `// ...`, on difficulties that show summaries), and the code, its long comments rewrapped.
  Summaries on reward and draft cards read the same way.
- **The Program's run ends the turn.** In a program run the cast command also runs the foes' turn and starts the
  next (`ShardrunCommands._cast`); End turn is still there for a turn without a program. The button reads
  `▶ python program.py` or `▶ node program.js`.
- **A guardian's health is a bar across the top middle of the arena** (`FoeView.take_card`); its intent stays above
  its sprite.
- **The Maintainer panel** shows a painted bust of the worn skin (`assets/portraits/<skin>.png`, from the art
  manifest's `hero-portrait` style), falling back to the skin's own small face. The fight's log is kept whole and opened
  with `.log` (`BattleLog`): every entry by turn, with what went into its number, and each turn's sums as a comment.

## Consequences

- The card Shardrun (deck) gets the same table; Spellforge's spellbook is unchanged.
- Card pictures are still the old shards' icons in the frame's window; cards of their own can replace them one by one
  without touching the frame.
- The hand's lower edge is off-screen by design, so the fight screen drops its bottom margin.
