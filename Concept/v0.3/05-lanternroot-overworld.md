# Lanternroot's overworld: a top-down town with a light-novel face

Written 2026-10-09 from the player's brief. It refines path 1 (`01-academy-workshop-town.md`): the town becomes a real
top-down world you walk, and the first lesson is coding your own feet. The learning content of later lessons comes in
the next step; this page covers the world, the art pipeline, and the first lesson's machinery.

## 1. The brief

- A **Pokemon-style top-down town**: simple grid movement, a modern pixel look like most fantasy RPGs today, not much
  3D. The overworld stays simple; detail lives in the portraits and concept art.
- **Light-novel dialogue**: talking to a townsperson brings up their portrait from `Concept/v0.3/Townspeople/`, so the
  pixel sprite has a face.
- A **customizable main character**, simple enough for the kids to make their own. The main character's portrait can
  stay simple for now; the townspeople get the quality.
- A **fairy companion** who is always with you.
- The town is the tutorial and level 1. **The first task is to code your own movement**: blocks for absolute beginners,
  or a little code (`if key is right, move x by 1`).
- Pixel art **as crisp as possible**, and a town that feels **unique and lived in**, in a simple style.

## 2. What we already have

| Asset | State | Where |
|---|---|---|
| 17 townspeople portraits | 128 px in `Townspeople/`; every one also has **1024 px originals** (two candidates each), the prompt, the seed, and a cut-out mask | `~/personal-project/ProgramMe/assets/.art-cache/portrait-<name>/` |
| 10 overworld sprites | 32 by 48, 18 colours, clean, but **one front-facing pose**: no walk cycle, no other directions | `ProgramMe/assets/generated/npcs/` |
| 10 townspeople's dialogue | Nodes, choices and flags (Marta the innkeeper, Pell, Pip and the rest) | `ProgramMe/content/packs/core/npcs/*.yaml` |
| Kenney Tiny Town and roguelike characters | CC0, 16 px | `pipeline/sources/vendor/` |
| ComfyUI | Anime SDXL (novaAnimeXL), the Pixel Art XL LoRA, an OpenPose ControlNet, background removal (RMBG), a 4x anime upscaler, Wan 2.1 VACE (animation) | `~/personal-project/ComfyUI` |
| The sandbox | Python answers in about 67 ms, JavaScript in about 10 ms (ADR-0002) | `game/sandbox/` |

The seven without sprites or dialogue (artificer, keeper, necromancer, oracle, shade, summoner, warden) were the old
game's class portraits, and each also has a full-body avatar render in the same cache; they can become townspeople with
new sprites.

## 3. Is our ComfyUI enough?

**For portraits and concept art, yes. For crisp pixel characters and tiles, no, not on its own.**

| Asset | ComfyUI today | Why |
|---|---|---|
| Light-novel portraits, and expressions | Yes | The 1024 originals exist; expressions are inpainting with the same prompt and seed; RMBG cuts them out |
| Dialogue backgrounds and concept art | Yes | This is what SDXL does best |
| Single props and house fronts in pixel style | Workable | SDXL plus the pixel LoRA makes a "pixel-ish" 1024 image; it needs a cleaner (grid detect, downscale, palette lock) and a hand pass |
| Walk cycles in four directions at 16 to 32 px | **No** | Each frame is a separate image, so the character drifts between directions and frames. Wan worked for Vesper's fight sprite at a large size, not at 16 px |
| Seamless autotiling terrain (grass to path to water) | **No** | SDXL does not keep a tile grid or seamless edges |

So keep ComfyUI for faces, backgrounds and props, and add two things: a tool that understands pixel art for characters
and tiles, and a cleaner in our pipeline that every pixel asset passes through.

## 4. The options for pixel assets

| Option | Good at | Cost | Notes |
|---|---|---|---|
| **PixelLab** | Characters in 4 or 8 directions, walk and idle animations, Wang tilesets for terrain transitions, style from a reference, inpainting | Subscription, roughly $10 to $50 a month by third-party listings (check pixellab.ai) | Has an official **MCP server for Claude Code**, so the agents can generate and fetch directly |
| **Retro Diffusion** | A pixel-native model: sprites, tilesets, animations | API about $0.015 to $0.18 an image with no subscription, or an Aseprite extension at about $65 once (runs locally) | Also has an MCP server; a competitor lists fixed output sizes of 32 and 64 px |
| **ComfyUI plus a cleaner** | Props, house fronts, items | Free, local | The PixelArt Detector node (grid detection, palette quantize) or our own Python cleaner |
| **Blender to pixel** | Perfect consistency across directions and frames (render a model, then pixelate) | Free, local | Our VRM skins and move library could render walkers; the look tends to read as shrunk 3D unless cleaned by hand |
| **Hand pixel art** | The final crispness, every route needs it | Aseprite about $20 once (or free if built from source); Pixelorama free (made in Godot) | Both PixelLab and Retro Diffusion work with Aseprite |
| **Ninja Adventure pack** | Placeholder and base vocabulary: 16 px top-down tiles, many characters with walk cycles, a Godot 4 project | Free, **CC0** | The best free start |
| **LPC character generator** | Layered, customizable characters with walk cycles | Free; CC-BY-SA and GPL, so credits and share-alike apply | Taller, realistic proportions, a different look from chibi townspeople |
| **Mana Seed** | Lovely paper-doll character base and village sets | Paid | **Ruled out**: its licence forbids using it alongside generative AI, which Rootward does |

## 5. The recommended pipeline

1. **An art bible first** (one page): a 16 px grid; characters 16 by 32; the world drawn at 320 by 180 and scaled up by
   whole numbers (4 times for 720p, 6 for 1080p, 8 for 1440p); one fixed palette of about 48 colours, warm and lantern-lit to
   match the game; light from the top left; outline rules; walk cycles of four frames at about 8 frames a second.
2. **A source per kind of asset:**
   - Townspeople portraits and expressions: ComfyUI from the 1024 originals.
   - Characters (townspeople, you, the fairy): PixelLab, from a front design to rotations to walk and idle, with the
     portrait as the style reference; then the cleaner and a hand pass.
   - Terrain: Ninja Adventure's tiles as placeholders, then our own Wang tilesets from PixelLab, cleaned.
   - Houses and props, the "lived-in" pieces: ComfyUI with the pixel LoRA (or Retro Diffusion), then the cleaner and a hand
     pass.
3. **The cleaner** (new, in `pipeline/pixel/`), which every asset passes whatever its source:
   - Detect the pixel grid and downscale to it, nearest neighbour.
   - Map every pixel to the palette, without dithering by default.
   - Remove orphan pixels, and make alpha all or nothing.
   - Snap sizes to the 16 px grid, and add selective outlines where the art bible says.
   - A **crispness lint** that fails any overworld PNG with an off-palette colour or soft alpha, and contact sheets for review.
   - A provenance line for every file: its source, licence, prompt and seed.
4. **One asset's path**: generate, clean, look at it, fix it by hand, lint it, import it (filtering and mipmaps off).

ComfyUI and Blender never run together. Blender is open at the moment, so ComfyUI tests wait until it is closed.

## 6. Crisp on screen too

- The world renders in its own viewport at 320 by 180, scaled by a whole number, with nearest filtering and pixel-snapped
  transforms. The camera moves in whole pixels.
- The dialogue, the portraits and the menus draw above it at full resolution: large painted portraits and sharp text over a
  pixel world, which is the light-novel layer.
- The rules stay pure, as everywhere else in the game: the grid, walls, movement, who you are facing, and townspeople's
  routines live in `game/core/overworld/` and are tested without nodes. The scene only animates them.

## 7. The first lesson: code your own feet

**The beat.** You wake up in Lanternroot and cannot move. The fairy explains that everything here runs on code, even your
feet, and hands you your boots: the movement program, empty.

**Two ways to write it:**
- **Blocks**, for absolute beginners: an event block ("when right is pressed") holding an action ("step right"). Four
  pairs of blocks open all four directions. The Python they stand for is shown underneath, so blocks lead to text.
- **Text**, as simple as the brief asks:

  ```python
  def on_key(key, x, y):
      if key == "right":
          x = x + 1
      return x, y
  ```

**How it runs, without lag.** When you save your boots, one sandbox job calls your `on_key` for every key on every
walkable tile of the map (a few thousand calls in one job; my estimate is well under a tenth of a second, to be measured
in slice 2) and the world keeps the answers
as a table. Walking then reads the table, so there is no delay, and every step is still the result of your real code. Code
that keeps its own state (a step counter, say) runs once per step instead: about 10 ms in JavaScript and 67 ms in Python,
which fits inside a grid step. Walls belong to the world, so code can ask to move, but not through a wall.

**The town teaches by what it opens.** At first only "right" works. A path leads north, so you add `up`. A gap needs two
tiles at once, so you add a run key. A mirrored corridor swaps left and right until you fix it. Each change to your code
opens another part of town, so your code is your ability.

**No one gets stuck.** The fairy can put your boots back to the last version that walked, and the bell walks you home.

## 8. The fairy

- **Always with you**: she follows a tile behind, or floats beside you with a slow bob, and she glows, so she lights dark
  interiors and night streets. A lantern sprite in a lantern town.
- **The tutor voice**: hints, never answers. She reacts to your code, reads the world's code aloud, and keeps the history
  of your boots.
- **Design**: a tiny sprite (10 to 16 px) with a glow, and a portrait in the townspeople's painted style. Names to think
  about: Lumi, Hotaru (firefly), Kodama (a tree spirit). Yours to choose.
- **Sound**: a small chime for her voice.

## 9. Make your own character

- **Version 1**: two bodies, six skin tones, four hairstyles in eight colours, four outfits in eight colours, one accessory
  (a hat, a ribbon, glasses, or none), a name, a random button, and a preview that turns through four directions.
- **Built as layers** (body, outfit, hair, accessory) on the same 16 by 32 frames, with a palette-swap shader for the
  colours, so a few drawings make thousands of combinations.
- **The cost is in frames**: each part needs a four-frame walk in four directions, 16 frames (the idles reuse them).
  The thirteen parts above are about 200 frames. Start with two hairstyles and two outfits, and add more when the
  pipeline is proven.

## 10. Light-novel dialogue

- The world dims, the portrait slides in at one side, a name plate, a text box that types out, choices, an expression
  per line, and a short voice blip for each character.
- **Content is data**: one file per townsperson, with nodes, choices and flags, converted from the old YAML (ten
  townspeople's dialogue already exists), and Japanese beside it as the rest of the game does.
- **Expressions**: three or four for the main townspeople (calm, happy, surprised, worried), inpainted from the originals.
- **Japanese for the daughters**: kanji need furigana, and Godot's rich text has no ruby support, so either a small ruby
  control or kana-only lines for the youngest. Plus text speed and auto-advance.

## 11. A town that feels lived in, simply

- Townspeople keep small routines: walking between two or three places, going inside at night, an idle job (sweeping,
  fishing, reading).
- Small life everywhere: chimney smoke, birds and butterflies, a cat, flickering lanterns, laundry on a line.
- Signs of history in the props: a mended fence, a patched roof, a notice board with real notes (which can hold readable
  code later).
- Lanterns light at dusk. It is Lanternroot.
- Footsteps that change with the ground, and quiet ambient sound: wind, birds, the inn's chatter.
- Interiors for the important houses: the inn, the archive, the guild.

## 12. More ideas

- **Code sight**: the fairy lets you see the code behind things. A door shows `can_open`, a sign shows what it prints.
  Reading before writing (PRIMM). Later, some of it can be fixed: the broken bridge's code, the stuck mill.
- **Scrolls as progression**: new commands and blocks are found in the world. A scroll teaches `for`, and lamplighting
  needs it.
- **The station link, later**: the overworld could become the game's hub, with the lift down to the Shardrun at the edge
  of town. `docs/ROADMAP.md` already says the Academy's hub could become the World's first place. Not now.
- **Maps**: Godot's tile editor with terrains for the ground, scenes for maps, and townspeople, doors and signs placed by
  data files.
- **Gamepad** from the start.

## 13. Slices

0. **The art bible and the pipeline** (1 to 2 sessions, plus your choices): the palette and sizes; the cleaner and its
   lint; one asset of each kind through each candidate source, side by side, so you choose by eye.
1. **The world** (2 to 3 sessions): the crisp viewport, a test town on placeholder CC0 tiles, grid movement (written by
   us for now), the camera, walls, three townspeople, talking with real portraits, the fairy following, saving.
2. **You and your feet** (2 to 3 sessions): the character creator (colours, two hairstyles, two outfits); the movement
   lesson in blocks and text with the table; the map's gating by code.
3. **Lived in** (2 sessions or more): routines, small life, day and night, sound, interiors, and the real art replacing
   the placeholders.

## 14. Decisions for you

1. **Budget.** A PixelLab subscription (the strongest fit for characters, walks and terrain, and it talks to the agents)?
   Retro Diffusion credits or its Aseprite extension? Aseprite itself? Or the free route: ComfyUI, the cleaner,
   Pixelorama and CC0 packs, with more hand time.
2. **Scale.** 16 px tiles with 16 by 32 characters (recommended: crisp, quick to make and to fix), or 32 px tiles with 32
   by 48 characters (the old sprites' size: more detail, about four times the art).
3. **Placeholders.** Start on Ninja Adventure's CC0 tiles and characters while our own are made?
4. **The fairy**: her name, her look, her voice.
5. **Text-mode boots**: a function that returns the new position (as above), or a `move.x += 1` style.
6. **Customization for version 1**: as section 9, or smaller.
7. **When to close Blender**, so ComfyUI can run the pipeline tests.

## Sources

- PixelLab's MCP server: [mcpservers.org listing](https://mcpservers.org/servers/pixellab-code/pixellab-mcp),
  [npm package](https://npmjs.com/package/pixellab-mcp); pricing from third parties:
  [aipicks](https://aipicks.jp/tool/pixellab/pricing), [AlternativeTo](https://alternativeto.net/software/pixellab/about).
- Retro Diffusion: [its MCP server](https://mcpservers.org/servers/retro-diffusion/retro-diffusion-mcp),
  [a comparison](https://www.spritecook.ai/compare/retro-diffusion), [a guide](https://app.cinevva.com/fr/guides/ai-pixel-art-generators).
- [ComfyUI PixelArt Detector](https://github.com/dimtoneff/ComfyUI-PixelArt-Detector).
- [Ninja Adventure asset pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack/purchase) and its
  [CC0 confirmation](https://itch.io/post/5390864).
- [Universal LPC Spritesheet Character Generator](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).
- Mana Seed's licence and its rule on generative AI: [Character Base](https://seliel-the-shaper.itch.io/character-base/purchase),
  [the creator's reply](https://itch.io/post/8312629).
