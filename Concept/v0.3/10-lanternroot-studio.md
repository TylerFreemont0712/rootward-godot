# Lanternroot Studio: the town's own editor, inside the game

Spec v1, written 2026-10-13 with the player, updated later that day for the compact asset browser and object actions.
Status: **S1 to S9 implemented (S4: all buildings/props resize directly; only blockout pictures can be remade; S8 makes new things, editing an existing thing's files waits); S0 and S2 have open checks; S10 (heights) next**. This is the document every
session that works on the Studio starts from. Section 1 is a prompt to paste; sections 2 to 4 say what the Studio is and
what the player decided; sections 5 to 9 are the precise design; section 10 is the build order with acceptance checks;
sections 11 and 12 are the instructions for agents and for the player; section 13 is what is still open.

Read with it: `AGENT.md`, `CLAUDE.md`, ADR-0004 (content is JSONC), ADR-0061 (the overworld), ADR-0062 (the town),
ADR-0064 (40 px, one scale), ADR-0065 (the player's reverted layering prototype), `pipeline/world/README.md` (how a thing's picture is
made). Decisions: **ADR-0066** and **ADR-0076** (2026-10-18 sizing and persistent asset reviews).

---

## 1. The prompt (paste this to start a Studio session)

> Read `AGENT.md`, `CLAUDE.md`, `WIP.md` (top section) and `Concept/v0.3/10-lanternroot-studio.md` (all of it), then
> the ADRs it lists in its header and `pipeline/world/README.md`. Run `git log --oneline -8` and `git status`.
>
> We are building Lanternroot Studio: an editor inside the game, behind a developer toggle, where I edit the town in the
> same view I play it in, play-test my draft, and publish it into the game's content files. Find the first phase in
> section 10 whose checklist is not ticked in `docs/PLAN.md` and build it, in the order section 10 gives, to its
> acceptance checks. Follow section 11 exactly (tests first for the pure model, screenshots of everything visible, the
> file-writing rules). Ask me only what section 13 marks as mine to decide, or anything that would change what I see.
>
> My standing rules: no paid tools or assets; never commit `WIP.md`; ComfyUI and Blender never at once; nothing writes
> the game's content files except the Studio's Publish (and tests write only to temporary copies).

---

## 2. What the Studio is

**One sentence:** press a key while playing Lanternroot and the town stops and becomes editable, in the very view you
were playing in; move, add, remove, resize and repaint anything; play your draft to try it; publish it, and the game is
changed for good.

**Why:** the town is data (maps, people, quests, things in `game/content/packs/core/overworld/`), but editing it means
typing coordinates into a file with 1,600 objects. The Studio is the hands-on way to shape it, modelled on The Sims'
Build and Buy modes, which make arranging a place feel like play.

**Where it is going** (later phases, same tool): the developer inspector (see every flag, quest and event, and poke
them); objects that take code (almost everything interactable, each interaction unlocked by play); the main quest
edited in place (where it happens, its steps and words, how it is shown, how it completes, its flags); and in the end a
smaller Studio for players, a build mode for their own house and yard. Because the Studio edits the same data the
game plays, every one of those is a new panel on one tool, not a new tool.

**What it is not:** not a Godot editor plugin (the Studio replaces the Godot map tool idea; see section 13), not a
general engine editor, not a way to change engine code. It edits content; the game's rules stay in code.

---

## 3. What the player decided (2026-10-13)

1. **A toggle first.** The Studio is a developer toggle while it is being built. Folding it into the game for players
   comes later (phase S11).
2. **The entire game, seen.** The edit view is the play view: same renderer, same 40 px scale, same lighting and art.
   Editing only adds overlays and panels; nothing looks different underneath.
3. **Permanent changes.** The Studio writes the real content files, so a published change is part of the game.
4. **Drafts, then publish.** Edits go into a draft that survives restarts and can be play-tested; Publish copies the
   draft into the content files after checking it.
5. **Scene editing is the main goal now.** Rearranging and resizing things comes first.
6. **Snap to the grid,** and an in-depth system for separating assets (categories, subcategories, tags, filters,
   search), in The Sims' style.
7. **Resizing: both.** Pick a ready size variant instantly, or drag a thing to any footprint and have the world
   pipeline remake its picture at that size (a placeholder shows until it is done).
8. **Land:** paint the ground now (grass, path, cobble, water, flowers, floors), and grow or shrink a map; heights
   (cliffs, ledges, stairs) in a later phase.
9. **The main quest, eventually all of it:** where it happens, its steps and words, how it is shown, how it is
   completed, its flags. This is on the back end of the build (phase S9).
10. **Interactions on almost all objects,** for programming, unlocked through play (phase S8).
11. **Order agreed:** scene editing first (S0 to S6), then the developer inspector (S7), then objects that take code and
    links between them (S8), the quest editor (S9), heights (S10), the players' build mode (S11).
12. **A bounded UI addition** (later 2026-10-13): keep the current look, add a small asset preview and filters for object
    kind, category/subcategory and likely indoor/outdoor placement; add Delete selected and a right-click menu for
    simple object actions. Build this piece on its own. Code actions are reserved for later work.

---

## 4. Principles (non-negotiable; a change needs the player's word)

- **What you edit is what you play.** The Studio draws the map with the game's own `TownMapView`, `GroundLayer`,
  `Walker` and `PixelView`. Overlays (grid, footprints, markers) sit on top and can all be hidden. A screenshot of the
  edit view with every overlay off (see-through and the player's ring included) is pixel-identical to the play view of
  the same draft, at the same camera.
- **Content is the source of truth.** The Studio reads and writes the same JSONC files `OverworldContent` loads
  (ADR-0004). It never invents another format for published data. Drafts are copies of that data, kept outside the
  repository.
- **Nothing reaches the content files except Publish,** and Publish writes only what passed every check. (The one
  other write outside `user://` is a remake's spec in `pipeline/world/objects/`, written by Run remakes; section 7.7.) Tests never
  write to `res://`: they copy content to a temporary folder and point the loader there.
- **A pure model.** The Studio's document, commands, rules and writer live in `game/core/studio/` as pure code (no
  nodes, no file access; files are read and written by a thin service in `game/scenes/studio/`), and are tested
  headless first, like the rest of `game/core/`.
- **Every edit can be undone.** Each change is a command with an inverse; undo and redo cover every tool.
- **The grid rules.** Positions and sizes are whole tiles (`OverworldScale.TILE`, 40 px). Free placement is a deliberate
  modifier, and even then positions stay whole cells. A placement can resize its picture while keeping the native
  source art and shape metadata (section 7.7, updated by ADR-0076).
- **The Studio exists only where it can write.** It appears only when the game runs from the repository (not in an
  exported build) and the toggle is on. The children's normal play never shows it.
- **Missing art never breaks a screen.** A thing whose picture is missing shows the plain block it shows in play.
- **Fast enough to feel direct.** On Lanternroot (80 x 56 tiles, about 1,600 objects) at 2560 x 1440: 60 frames a
  second while panning and dragging, a pick under the cursor in under a millisecond, a placement shown within one frame.

---

## 5. The Sims as reference: what maps to what

| The Sims | Lanternroot Studio |
|---|---|
| Live mode / Build mode / Buy mode (F1, F3, F2) | **Play** (F1) and **Edit** (F2); in Edit, tabs for Objects, Build, Land, People & Doors (later Things, Quests, Debug) |
| Buy mode catalog: by function and by room, thumbnails, search, filters | The catalog (section 8): by category and subcategory, by place (outdoor, indoor), tags, filters, search, thumbnails |
| Hand tool: pick up, move, put down | **Select** tool: click, drag, drop; the ghost shows green where it fits and red where it does not |
| Eyedropper | **Eyedropper** (E): pick any placed thing and place more of it with the same settings |
| Sledgehammer | **Delete** (Del, or the tool): click or box-select to remove |
| Rotate with `,` and `.` | **Flip** (F) for flippable art; **Facing** (R) for people. Art has one facing, so rotation is a flip |
| Design tool (colours and patterns) | **Variant** (`[` and `]`): the same thing in its other sizes or styles (section 7.7) |
| Terrain paint, raise and lower | **Land** tab: paint ground types with brushes; heights later (S10) |
| `moveobjects on` (place anywhere) | **Free placement** (hold Alt): ignore overlap and blocking checks; the cell grid still holds |
| Walls up, cutaway, down | **See-through**: big art near the cursor fades (roofs, tree crowns), so what is behind can be picked |
| Lot view and neighbourhood view | The **map** view and the **overview** (the whole map scaled to fit); the map picker for interiors |
| Undo and redo | Ctrl+Z, Ctrl+Y (Ctrl+Shift+Z), with the command's name in the history list |

---

## 6. The screen

At 2560 x 1440 the world shows at 2x in the middle (the play view's 1280 x 720), and the panels are full-resolution UI
in the game's modern menu style (they shrink the visible world; they never cover it with translucency).

```
+----------------------------------------------------------------------------------------------------------+
| [Lanternroot v] [Play F1 | Edit F2]  Objects  Build  Land  People&Doors  (Things) (Quests) (Debug)       |
|                                         Draft: 12 changes, saved 14:02   [Undo] [Redo]  [Play draft] [Publish] |
+------+----------------------------------------------------------------------------------+-------------+
| Tools|                                                                                  | Inspector   |
| [S]  |                                                                                  | barrel      |
| [E]  |                          the town, exactly as it plays                           | at  39, 40  |
| [Del]|              + grid  + footprints  + doors and warps  + markers                  | size 1 x 1  |
| [F]  |                                                                                  | solid  [x]  |
| [R]  |                       ghost of the thing being placed                            | text  ...   |
| ---  |                                                                                  | variant 1/3 |
| grid |                                                                                  | [raw JSON]  |
| over-|                                                                                  | problems: 0 |
| lays |                                                                                  |             |
+------+----------------------------------------------------------------------------------+-------------+
| Catalog: [Buildings][Nature][Street][Farm&Work][Furniture][People][Interactive][Markers]  search [____]  |
|   Trees | Bushes&Flowers | Rocks | Water plants | Ground cover        filters: outdoor  1x1  solid  40px  |
|   [oak] [oak2] [birch] [apple] [apple2] [pine] [bush] ...   (thumbnails, name, footprint, source badge)    |
+----------------------------------------------------------------------------------------------------------+
| cell 39, 40  ground path  under cursor: barrel (prop)   zoom 2x   Alt: free placement   2 warnings      |
+----------------------------------------------------------------------------------------------------------+
```

- **Top bar:** the map picker (every map, interiors included), Play and Edit, the edit tabs, the draft status (number of
  changes, last saved), Undo and Redo, Play draft (switch to Play with the draft loaded), Publish.
- **Tools (left):** Objects selection and overlays. Land's brushes, grounds and map size use the lower workspace.
- **Inspector (right):** the selected thing's fields from the content schema (section 9.4), its problems, and a raw JSON
  view for anything the form does not cover. Multi-selection shows the fields they share.
- **Lower workspace:** Objects shows the section 8 catalog with two rows of cards; Land uses the same space for its
  brushes, ground swatches and Map size. The catalog slides away (Tab) to see more of the town.
- **Status bar:** the cell under the cursor, its ground, what stands there, the zoom, active modifiers, and the count of
  problems (click it to list them and jump to each).

### Camera

- Pan: middle-drag, or WASD (Shift for faster). The arrows pan too while nothing is selected; with a selection they
  nudge it (section 7.2). Zoom: the wheel steps through whole-number scales (1x,
  2x, 3x, 4x) so pixels stay crisp; `O` toggles the **overview**, the whole map fitted to the window (the only
  non-whole scale, for orientation; placing still works there).
- `Home` centres on the player (or the map's start in an empty session). Double-click a problem or a search result to
  fly to it.
- Switching Play and Edit keeps the camera where it is.

---

## 7. Tools and behaviours, precisely

### 7.1 Modes

- **Play (F1):** the game as always. With **Play draft** on, the map, people and things come from the draft, so it can be
  walked, talked to and used before publishing. A small "DRAFT" tag in a corner says so. The save file is not written
  while playing a draft (play-testing never corrupts a real save); a fresh test state starts at the cursor's cell or the
  map's start.
- **Edit (F2):** time stops (no walking, no talk, no sandbox jobs; water may keep rippling), the player stays drawn
  where they stand (a small ring under their feet is part of the overlays), and the edit tabs, tools and panels
  appear. Esc leaves the active tool first, then a second Esc returns to
  Play.

### 7.2 Select and move (Objects tab, `S`)

**Updated 2026-10-18 (ADR-0077):** **Select area (Q)** starts a rectangle even on occupied ground. Choose All
objects, Props only or Trees only, drag across their footprints, and release to select. The rectangle previews
matches and a count. Shift adds, Delete removes the selected group as one undo step, Ctrl+Z restores it, and Escape
cancels an unfinished rectangle without changing the selection. S returns to ordinary selection and moving.

- Click picks the topmost thing under the cursor: the one drawn in front (lowest feet), ignoring see-through art. `Tab`
  cycles through everything stacked under the cursor. Shift-click adds or removes; dragging on empty ground draws a
  selection box (everything whose footprint it touches).
- Dragging a selection moves it as a **ghost** snapped to whole cells: green where it fits, red where it does not, with
  the reason in the status bar ("overlaps the well", "off the map", "blocks the Inn's door"). Dropping on red does
  nothing unless Alt is held (free placement); then it is placed and marked with a problem.
- Arrow keys (with something selected and the Select tool active) nudge one cell; Shift+arrows nudge four.
- `Ctrl+D` duplicates beside the original; `Ctrl+C` / `Ctrl+V` copy and paste at the cursor (also across maps).
- `Del` deletes the selection. People and things ask first ("Pip has talk and a quest step: delete anyway?").
- **Delete selected** in the inspector uses the same undoable draft command and confirmation as Del. It removes the
  selected placed instances. The control is available for one or several selected objects.
- **Right-click a placed object** opens Copy, Duplicate, Delete and, when every target allows it, Flip. Clicking within
  an existing selection keeps that selection; clicking another object selects it first. Right-clicking also leaves the
  active placement/drag tool. On empty ground, a nonempty clipboard offers Paste here at that cell.
- The menu captures its map and object session ids. Changing selection cannot redirect its action; a removed target,
  replaced session/history or map switch invalidates it. Escape dismisses the menu. Editor shortcuts are held while
  the menu or a delete confirmation is open. Protected deletes revalidate their original targets on confirmation.

### 7.3 Place (from the catalog)

- Clicking a catalog entry enters place mode: its ghost follows the cursor, snapped so the cursor is in the footprint's
  bottom-middle cell (where the thing stands). Click places it and stays in place mode; Shift-drag paints a row (fences,
  trees along a road); right-click or Esc leaves.
- New things get the catalog entry's defaults (kind, size, solid, draw layer, sink, group) and nothing else.
- Hovering a browser entry updates the preview without placing it. A left click selects that asset for placement;
  other mouse buttons do not start placement from the list.

### 7.4 Eyedropper (`E`)

Click any placed thing: place mode starts with a copy of it (art, size, solid, text, group; not its id).

### 7.5 Flip and facing (`F`, `R`)

- `F` flips the selection left to right. Before the catalog exists (S1 and S2) any prop may flip and buildings,
  signs and people may not; from S3 only catalog entries marked `flippable` may (most nature and street art; not
  buildings with lettering, not anything lit from one side if it reads wrong flipped; the catalog decides). A flip is
  stored as `"flip": true` on the object (a new optional field: add it to the map schema and `TownMapView._standing`
  first).
- `R` turns a person to the next facing (down, left, up, right).

### 7.6 Overlays (toggles in the tools column, all remembered)

Grid; footprints (each thing's cells, dotted); solid cells (red tint); walkable cells (green tint, off by default);
doors and warps (an arrow to where they lead, with the target map's name); ids and art names on hover; people (their
name); things that take code (a gear badge); groups (one colour per group); problems (a red ring and an icon);
see-through (on by default).

### 7.7 Resize: variants and remakes (S4)

**Updated 2026-10-18 on the player's request (ADR-0076):** all placed buildings and props, including imported
artwork, resize immediately using width/depth in the inspector or footprint handles. The picture, footprint,
collision masks and linked doorway follow in one undo step. Original size restores dimensions. Native picture and
shape baselines prevent rounding drift across repeated sizes. This supersedes the picture-stretching restriction
and resize-handle limits in the original design below; explicit art remakes remain available separately.

Right-click a catalog asset or placed object → **Needs updating**. The catalog's Needs updating view and
**Asset updates** list show flagged assets, with notes and replacement prompts saved across restarts. Mark reviewed
retains the brief. For a restylable blockout, Queue replacement creates a new catalog variant, then Run remakes uses
the existing pipeline with its town style and negatives. Imported or exact authored art keeps the brief for later.

- **Variants.** A catalog entry may list variants: the same thing at other footprints or in other styles (`cottage-5x5`,
  `cottage-6x6`; `oak`, `oak2`). With a thing selected, `[` and `]` swap it for the previous or next variant in place,
  keeping its feet where they are (bottom-middle of the footprint). Instant, and it is just a change of `art` and `size`.
- **Remake at a new size.** Things whose picture comes from a world-pipeline spec (`pipeline/world/objects/<id>.jsonc`)
  show footprint handles when selected. Dragging a handle proposes a new footprint; dropping asks "Remake `<id>` at
  6 x 5?". Yes:
  1. drafts a new spec `<id>-<w>x<h>` (the source spec with the new footprint and, for a building, the door moved to the
     new middle column unless the player sets it) and a catalog entry for it as a variant of the source. The spec file is
     written into `pipeline/world/objects/` when **Run remakes** starts (the pipeline needs it on disk; it is an input to
     the art pipeline, not game content); the catalog entry and the map change are written at Publish;
  2. puts the object in the draft with the new art and size at once, drawn with the old picture scaled to fit and a
     hatched "remaking" overlay (the placeholder is never published as art);
  3. adds the id to the remake queue (`user://studio/remakes.json`).
- **Run remakes** (a button on the Objects tab, also offered at Publish) runs `scripts/world.sh make --only <ids>` as a
  background process (only when running from the repository), shows its progress line by line, and swaps the
  placeholders for the real pictures when `world.json` lists them. It follows the GPU rule by itself (`world.sh make`
  stops and starts ComfyUI).
- Adopted pictures (re-cut renders, no blockout) cannot be remade until someone writes their blockout spec; the Studio
  says so and offers the variants instead.

### 7.8 Land (S5)

- **Paint:** the ground types are declared through `paint` metadata in `terrain.jsonc` plus the map's legend
  (grass, meadow, dry grass, forest floor, moss, flowers, path, soil, tilled soil, sand, gravel, cobble and water outdoors;
  floor, wall, void indoors). Brushes 1, 2, 3 and 5 cells; a line tool (Shift-drag); a rectangle tool; flood fill. The
  dual-grid edges redraw live around the painted cells (`GroundLayer` gets a method to repaint a rectangle instead of
  the whole map).
- A ground type not yet in the map's legend is added to it with a free character.
- **Automatic variation (2026-10-18, ADR-0077):** every outdoor ground has eight texture variants. A place keeps
  its variant across painting, undo and reload; small plants, clods and stones vary without changing movement.
  Variant borders share their geometry and water keeps three ripple frames. Three meadow variants are quiet grass
  patches without flowers. Land tools and grounds share the catalog's lower workspace; Objects has room for two rows
  of asset cards.
- **Continuous materials:** empty meadow uses a flower-removal edit of the same painted turf. Path has a shared
  continuous dirt texture, with weathered top/bottom/left/right edges, corners and ends selected automatically by
  neighbor masks; connected centers and intersections have no internal tile border.
- Painting under a solid thing is allowed; painting water under a solid thing raises a warning (section 9.5).
- **Map size:** grow or shrink by rows and columns at any edge (a dialog with the four edges); things move with their
  cells; things that fall off are listed before confirming.
- **Heights** are phase S10 (section 10).

### 7.9 People and doors (S6)

- **People:** the catalog's People category lists every townsperson in `townsfolk.jsonc`, with their cast sheet's front
  frame as the thumbnail. A person stands in one place in the whole town: placing someone already on this map moves
  them (one undo step); placing someone who stands on another map asks first, then they leave it in the same change.
  `R` sets their facing. The inspector links to their talk file and lists where quests mention them.
- **Doors:** a building's door is a handle on its footprint's bottom row; dragging it along the row sets `door`.
  **Link door** picks a target: choose a map in the picker, click the cell, choose the facing; the Studio writes the
  building's `to`. **Make interior** creates a new interior map from a template (two rows of wall, a floor, a bottom row of void,
  the doormat warp in the middle of the bottom row, as the player's room is drawn) 11 x 8 by default (the player's call,
  2026-10-14: a 5 x 5 footprint leaves no room for 64 x 96 people; Map size changes it), and links both ways:
  the building's `to` lands on the cell above the doormat; the doormat's warp leads to the cell below the building's door.
- **Warps:** placed from the Markers category; linked the same way.
- **The start:** the map's `start` and `facing` are a marker that can be dragged.

### 7.10 Things, unlocks, quests, debug

Specified in section 10 (S7 to S9), as panels on the same tool.

---

## 8. The catalog: separating the assets

### 8.1 Where it lives

`game/content/packs/core/overworld/catalog.jsonc`, content like the rest, checked by the content loader and by a test.
Every picture a map can use has exactly one catalog entry; a test fails when a picture in `world/world.json`,
`props/props.json`, `buildings/` or the townsfolk has none, or when an entry names a picture that does not exist.

```jsonc
{
  "categories": [
    {"id": "nature", "name": "Nature", "icon": "leaf", "subcategories": [
      {"id": "trees", "name": "Trees"}, {"id": "bushes", "name": "Bushes and flowers"}, {"id": "rocks", "name": "Rocks"}
    ]}
  ],
  "assets": {
    "oak": {
      "name": "Oak", "kind": "prop", "category": "nature", "subcategory": "trees",
      "place": ["outdoor"], "tags": ["round", "leafy", "big"],
      "size": [1, 1], "solid": true, "flippable": true,
      "family": "oak", "variant": "Round oak"
    },
    "cottage-hollis": {
      "name": "Hollis's cottage", "kind": "building", "category": "buildings", "subcategory": "homes",
      "place": ["outdoor"], "tags": ["ivy", "red roof"], "size": [5, 5], "door": [2, 4], "flippable": false
    }
  }
}
```

Fields: `name` (shown), `kind` (building, prop, sign, person, warp, start, trigger; start and trigger are Studio
markers: the map's `start`, and trigger cells from S8), `category` and `subcategory` (ids from
`categories`), `place` (outdoor, indoor), `tags` (free words for search), the defaults a new placement gets (`size`,
`door`, `solid`, `draw_layer`, `sink`, `group`), `flippable`, `family` and `variant` (entries with the same family are
variants of each other, in the order listed), and `interactive` (S8: which hooks it can take). The picture's source
(the new world pipeline at 40 px, or older art enlarged) is not written here: the Studio reads it from the art indexes
and shows it as a badge.

### 8.2 The tree (first version; the player may rename or regroup)

| Category | Subcategories |
|---|---|
| Buildings | Homes; Shops and inns; Civic (hall, archive, shrine); Workshops (smithy, workshop); Landmarks (Lantern Root, Root Gate) |
| Nature | Trees; Bushes and flowers; Rocks and stumps; Water plants (lilypads, reeds); Ground cover (tufts, mushrooms) |
| Street | Lamps and lights; Benches and seats; Signs and boards; Fences and gates; Posts and mailboxes; Bridges and steps; Wells |
| Farm and work | Crops (cabbages); Containers (barrels, crates, sacks); Carts; Woodpiles; Forge (anvil) |
| Furniture (indoor) | Beds; Seating; Tables and desks; Storage (shelves, chests); Decor; Lighting (lanterns); Plants; Windows and wall decor; Rugs and mats |
| People | Townsfolk (from `townsfolk.jsonc`) |
| Interactive | Things that take code (gates, signs; later plates, levers, lamps) |
| Markers | Warps and doormats; Start; Triggers (S8) |

### 8.3 Finding things

- **The compact browser slice:** the existing list gains Category, Subcategory, Location (Any, Indoor, Outdoor) and
  Object kind (Any, Building, Prop) selectors. They combine with search; changing category clears an incompatible
  subcategory. Reset clears search and filters. The category tree comes from the catalog, including Nature / Bushes
  and flowers. Place tags describe where the asset is typically used; they do not change map placement rules.
- **Search** by name, id, tags and category/subcategory words, across categories, as you type (typing while a category
  tab is chosen moves the view to All; in Recent or On this map it searches within that view). Every word must match;
  capitalization and underscores are normalized. Results are sorted by display name and then asset id. Show a result
  count and an explicit empty-results message.
- **The full catalog (S3, built after the compact slice and replacing its selectors):** three compact rows over two
  row of cards, as the diagram in section 6 draws it. The first row has the views and the categories as tabs (All,
  Recent, On this map, then each catalog category that has a placeable entry, in the file's order) with search, the
  result count and Reset on the right; the second has the chosen category's subcategory tabs; the third has the filter
  chips. Each card shows the thumbnail, the name, the footprint and the source badge ("40 px" or "old"); the wheel
  scrolls further rows of cards. The preview card stays docked on the right.
- **Filters** (combinable chips): Outdoor, Indoor; footprint (1x1, 2x1, 1x2, 2x2, bigger); Solid, Walkable; Flat
  (ground layer); Takes code; Source (40 px, old). The "old" filter shows at a glance which pictures still need
  remaking.
- **Recently used** and **Placed on this map** are the first two views, beside All and before the categories (one row
  of tabs keeps the panel compact; the earlier idea was a row of each at the start of every category). Recent lists
  the last twelve pictures put down this run (from a card, the eyedropper or a row), newest first.
- **Thumbnails** are made at run time from the art (the first frame of a sheet, cropped to the picture, scaled by a
  whole number to fit 64 x 64, on a soft card) and kept in memory for the run. Making one was measured at about 0.2 ms
  (2026-10-13), so the disk cache this spec first planned (`user://studio/thumbs/`) would cost more to write than it
  saves; it was dropped.

### 8.4 The small asset preview

The compact browser includes a small docked preview card beside its list. Hovering or choosing an asset, or selecting
a placed object, shows its actual picture with its name, kind, footprint, category and likely placement. Previewing a
placed object uses its current size/flip fields. Pictures use nearest filtering and keep their proportions; a sheet
shows its first frame rather than all frames side by side. Missing art shows a labeled placeholder. Preview operations
change neither the draft nor the map. This card is the current browser addition; the larger thumbnail grid remains
part of the full catalog phase.

---

## 9. Architecture

### 9.1 Files

```
game/core/studio/                      pure, tested headless (tests first)
  studio_doc.gd        StudioDoc: one content file's data, its header comment, the hash of the text it came from
  studio_commands.gd   commands with an inverse: add, remove, move, set field, paint cells, resize map, set map field,
                       batch; apply(doc) -> doc and revert(doc) -> doc, never mutating the input
  studio_rules.gd      the checks of section 9.5 over a world of docs (pure)
  studio_diff.gd       what changed between a doc and its base, in words, for the Publish dialog
  studio_catalog.gd    the catalog model: tree, entries, families, search and filters (pure)
  studio_catalog_filter.gd  the catalog's pure combined query (search, tabs, chips, views) over catalog entries
  studio_row.gd        the cells of a Shift-dragged row (pure)
  jsonc_writer.gd      the canonical writer (section 9.6)
game/scenes/studio/                    nodes and file access
  studio.gd            the mode controller: Play and Edit, draft on or off, the panels, input ownership
  studio_files.gd      the only code that touches files: reads content, writes drafts, publishes, backups
  studio_overlay.gd    world-space overlays drawn in the PixelView's viewport above the town
  tool_select.gd, tool_place.gd, tool_paint.gd, tool_door.gd ...   one script per tool, the same small interface
  catalog_panel.gd, inspector_panel.gd, top_bar.gd, status_bar.gd, publish_dialog.gd, history_panel.gd
  studio_asset_preview.gd, studio_context_menu.gd  compact art preview and placed-object action popup
  studio_place_panel.gd, studio_catalog_card.gd, studio_thumbs.gd   the catalog panel, its cards, its thumbnails
game/content/packs/core/overworld/catalog.jsonc
game/test/core/studio/*_test.gd, game/test/scenes/studio_*_test.gd, game/test/content/catalog_test.gd
docs/decisions/ADR-0066-lanternroot-studio.md
```

### 9.2 Data flow

`res://content/...` (JSONC) -> `OverworldContent.load_world(root, drafts)` -> the catalog of maps, people, things,
quests -> `OverworldMap.build` -> `TownMapView` draws it. The Studio holds a `StudioDoc` per content file it edits. A
tool turns input into a command; the command applies to the doc; the Studio rebuilds only what changed (the moved
things' nodes; the painted rectangle of ground) and saves the draft.

`OverworldContent.load_world` gains one parameter, `drafts: Dictionary` (content path -> data), used in place of the
file's own data. Nothing else in the game changes to support drafts.

### 9.3 Identity

Map objects have no ids in the files (only people and things do). The Studio gives each object a session id (`sid`)
when it loads a doc, kept beside the data and never written to content files (drafts keep them; section 9.7). Commands and the diff refer to sids. A published file
keeps the original order of untouched objects and appends new ones at the end of their map's list, so a diff in git
shows exactly what moved.

### 9.4 The inspector's fields

Straight from `OverworldContent.map_schema()`: a building has `art`, `at`, `size`, `door`, `to`, `name`, `text`, `sink`;
a prop has `art`, `at`, `size`, `solid`, `talk`, `text`, `sink`, `draw_layer`, `group`, `id`, `program`,
`solid_unless` (and `flip`, added in S1); a sign has `art`, `at`, `text`, `talk`; a person has `id`, `at`, `facing`;
a warp has `at`, `to`. Each field gets a fitting control (cell picker, checkbox, text, map-and-cell picker, choice). A
new optional field anywhere goes into the schema with a default first (CLAUDE.md), then into the inspector.

### 9.5 The checks (before Publish, and live in the status bar)

Errors stop Publish; warnings are shown and may be accepted.

- **Errors:** anything the content loader rejects (the schema); `OverworldMap.build` errors, which include two solid
  things on one cell (free placement can put them there in a draft, but the game's own rule refuses it, so Publish
  does too: make one of them not solid, or move it); a thing off the map; a
  picture that does not exist; a person not in `townsfolk.jsonc` or placed twice; a warp or door leading to a map that
  does not exist or to a cell that is not walkable; a thing's program that does not match its file.
- **Warnings:** a building door with no walkable cell in front
  of it; a door or warp unreachable from the map's start (a flood fill over walkable cells); a picture drawn for another
  footprint than the object's `size` (the world pipeline's `footprint`); water under a solid thing; a placeholder still
  waiting for its remake; a quest or talk that names something no longer on any map.

### 9.6 Writing files: the canonical format

- The header comment block (every line before the first `{`) is kept word for word.
- Numbers that are whole are written as integers (Godot's JSON parser returns floats; `[39.0, 40.0]` must never reach a
  file).
- Keys keep their order: the file's own order for existing objects, the schema's order for new ones.
- In maps, `ground` is one row per line and `objects` is one object per line (compact, `", "` and `": "`), like
  `lanternroot.jsonc` today. Other files (quests, talk, townsfolk) keep the two-space pretty form they have now; the
  writer's settings per file kind are listed in `jsonc_writer.gd`.
- **Round-trip test:** for every content file the Studio can write, reading and writing it unchanged gives back the
  same text. Files that do not round-trip today (`home.jsonc`, whose objects are pretty-printed) are canonicalized once,
  by a command run in S0, in a commit of its own, before any Studio edit touches them.
- A write goes to a temporary file in the same folder, then replaces the original (no half-written files).

### 9.7 Drafts, backups and conflicts

- A draft is `user://studio/drafts/<path with / as __>.json`: `{file, base_hash, base_text, data, saved_at, sids}`
  (sids are kept so a reopened session selects the same objects; they are never written to content files). It is saved two
  seconds after the last edit and when leaving Edit. Drafts survive restarts; **Revert draft** throws one away.
- **Publish** (S2): run every check over the whole world with all drafts applied; show the diff per file in words
  ("moved 3 barrels; added an oak at 12, 40; painted 18 cells path; the Inn's door now leads to inn-interior") and the
  problems; on confirm, copy each current file to `user://studio/backups/<date-time>/`, write the new files, reload the
  content, clear the published drafts, and say which files changed ("commit them with git when you are happy").
- **Conflicts:** if a content file changed on disk after its draft began (its hash differs, say after a git pull or a
  hand edit), the Studio says so and offers: keep the draft (overwrite the file's new changes), or rebase. Rebase is a
  three-way merge: the draft stores the text it began from (`base_text`), so the draft's changes are computed against
  that base (objects matched by `id` where they have one, else by kind, art and cell; an object whose cell changed is
  matched by kind and art to the nearest unmatched one) and re-applied to the new file, listing anything that no
  longer applies. Sids are session ids and play no part in matching.
- The Studio never commits. Git is the long-term history.

### 9.8 When the Studio exists

- Only when the game runs from the repository: `OS.has_feature("template")` is false and the content folder is writable
  (`StudioFiles.can_write()` tries a temporary file once at start).
- And the toggle is on: `Settings.studio` (a new setting, default off, shown in the settings only when the Studio can
  exist), or the environment variable `ROOTWARD_STUDIO=1` for one launch.
- F1 and F2 do nothing otherwise. Exported builds contain the code but never show it.

### 9.9 Input and rendering

- In Edit mode the Studio owns input: the overworld's `_unhandled_input` returns early while `studio.editing` is true,
  so no key walks, talks or opens a menu behind the editor. A scene test proves it (send the arrows, B, Space and X in
  Edit; the game state does not change: the player does not move, no talk, boots or thing editor opens).
- World-space overlays are a `Node2D` in the PixelView's viewport above `things`, drawn at the world's scale. Panels are
  full-resolution `Control`s in the game's UI theme, never inside the pixel viewport.
- Picking uses a spatial index (cell -> objects covering it), updated by each command; it never scans 1,600 objects per
  mouse move.
- `GroundLayer` gains `repaint(rect)` so a brush stroke rebakes a few tiles, not the 3,240 x 2,280 picture (the map's
  81 x 57 tiles: the dual grid reaches half a tile past each edge).

---

## 10. Build order, with acceptance checks

Each phase ends with: tests green headless (the phase's own and the full suite's baseline), lint clean, screenshots of
every visible change looked at, `docs/PLAN.md` ticked, the learning log updated, `WIP.md` written. AGENT.md asks
for a commit after each meaningful step; the player is deferring commits for now (much uncommitted work is theirs), so
commit only when the player says so, as small conventional commits, one per meaningful step.

### S0. Foundations: the toggle, the view, the document (no editing yet)

- `Settings.studio`, `ROOTWARD_STUDIO`, `StudioFiles.can_write()`; F1 and F2; Edit pauses play and shows the panels
  (empty catalog, read-only inspector); the camera (pan, whole-number zoom, overview, Home).
- Overlays: grid, footprints, solid, doors and warps, ids on hover.
- Click selects; the inspector shows the fields and the raw JSON of the selection.
- `StudioDoc`, `jsonc_writer.gd` with the round-trip test over every overworld content file; the one-time
  canonicalization of files that do not round-trip; `OverworldContent.load_world(root, drafts)`.
- ADR-0066.
- **Accept:** F2 in the town shows the same picture plus a grid (screenshot pair, overlays off identical to Play);
  clicking the Inn shows its fields; every content file round-trips byte for byte; F1 and F2 do nothing with the
  toggle off; keys pressed in Edit do not move the player (scene test).

### S1. Arrange: move, add, remove, duplicate, flip, edit fields

- Commands with undo and redo (tests: every command's apply then revert gives back the original doc, equal by value);
  the history panel.
- Select, box select, Tab cycling, drag with the snapped ghost and its reasons, Alt for free placement, nudging,
  duplicate, copy and paste, delete with confirmation for people and things, flip (`flip` in the schema and the
  renderer), the inspector editable.
- A plain list of every picture for placing (the full catalog is S3).
- Drafts saved and restored across a restart.
- **Accept:** move the noticeboard three cells, add two barrels, delete a bench, flip a tree, undo all four, redo them;
  quit and relaunch; the draft is there; the play view with Play draft shows the change; the content files are
  unchanged.

### S2. Publish

- The checks of section 9.5, live in the status bar and listed in a panel; the Publish dialog with the diff in words;
  backups; temp-file writes; reload after publishing; Revert draft; conflict detection and rebase.
- **Accept:** a scene test publishes into a temporary copy of the content and compares the written file to an expected
  one (a moved barrel changes exactly one line in git's view); an invalid draft (a warp to a missing map) cannot be
  published; a file changed under a draft is detected.

### S3. The catalog

- **Bounded slice requested separately:** compact Category/Subcategory/Location/Object kind filters with search and
  reset; docked asset preview; inspector Delete selected; right-click simple actions. Its acceptance checks are:
  Nature / Bushes and flowers / Outdoor shows matching props, Indoor + Furniture excludes outdoor assets, hover shows
  a picture without editing the map, and Copy/Delete/undo operate on the originally selected placed instances with
  protected-delete confirmation. This slice does not complete the rest of S3.
- `catalog.jsonc` for every existing picture (the tree of section 8.2; the player reviews the grouping), the catalog test,
  the bottom panel with categories, subcategories, thumbnails, search, filters, recently used and placed-on-this-map,
  the source badge.
- Place mode from the catalog, Shift-drag rows, the eyedropper.
- **Accept:** typing "barr" finds the barrel; the "old" filter lists exactly the pictures not yet remade at 40 px;
  placing ten fence pieces in a row is one Shift-drag; a picture without an entry fails the catalog test.

### S4. Resize: variants and remakes

- Families and variants in the catalog, `[` and `]`; footprint handles for world-pipeline pictures; the new spec and
  catalog entry; the placeholder; the remake queue and Run remakes, with progress; the swap when done.
- **Accept:** a cottage cycled to its 6 x 6 variant keeps its feet; a barrel dragged to 2 x 1 shows a hatched placeholder,
  `scripts/world.sh make` runs from the button, and the real picture replaces the placeholder without a restart.

### S5. Land

- Ground brushes, line, rectangle, fill; legend growth; `GroundLayer.repaint`; map size dialog.
- **Accept:** painting a 5-wide cobble road through grass redraws its rounded edges live within one frame per stroke;
  growing the map by 4 columns on the left moves every thing 4 cells right and the published file shows it.

### S6. People, doors, interiors

- Townsfolk placement and facing; door handles; Link door; Make interior with the two-way link; warps; the start marker;
  the map picker lists interiors.
- **Accept:** make an interior for Pell's cottage, furnish it from the Furniture category, walk in and out of it in Play
  draft, publish, and the new map file exists with the right links.

### S7. The developer inspector (the "see and poke" panel)

- **See:** a live state panel (flags, quests and their steps, lessons, each thing's fields, the boots' code); an event
  log (talk opened and closed, flags set, quest steps done, things used with their code's input, output, errors and
  sandbox time, warps taken); an overlay of triggers and talk links.
- **Poke:** teleport (Ctrl-click in Play), set and clear flags, complete or reopen a quest step, reset a thing, re-run a
  thing's code with chosen inputs, reload content when a file changes on disk.
- All through `OverworldState`'s pure functions, every poke logged; pokes change the play-test state only, never content.
- **Accept:** jumping the main quest to "Light the lane" and walking to the lane shows the lamps dark; the event log
  shows the cabbage gate's code run with its result.

### S8. Things that take code, and unlocks

- Make any prop a thing: give it an `id`, a hook (`on_use` now; `on_step` and `on_change` with the wiring work), fields,
  the flags it may raise, starter code in Python and JavaScript, hints; the files in `things/` are written by Publish.
- **Unlocks:** a thing's interaction is available only once a flag holds (a new optional `unlocked_by` condition, in the
  quests' condition language); locked things show nothing when used.
- Links between things (the wiring idea: a plate's weight opens a door) as the second half of this phase, with the
  rules in `game/core/overworld/` first.
- **Accept:** turn a barrel into a thing whose code answers when used, unlocked by `met-innkeeper`; it is silent before
  meeting Marta and answers after.

### S9. The quest editor (the main quest, all of it)

- The quests as a list in order (`order`, `after`), each quest's steps (text, hint, the done condition built from
  flags: flag, not, all, count), its giver; **where it happens** (pins on the map for each step: a person, a thing, a
  cell; a new optional `at` per step for the tracker to point at); **how it is shown** (the tracker and log's options);
  **how it is completed** and **its flags**: a flag browser listing every flag with where it is set (talk, things,
  lessons) and where it is read (quests, talk conditions, unlocks), with jump-to.
- Talk: a node editor for a person's talk (lines, moods, choices, sets, conditions), saved to `talk/<id>.jsonc`.
- **Accept:** add a step to "Hello, Lanternroot" that needs a new flag set by talking to Pip; play the draft; the tracker
  shows the step and completes it.

### S10. Heights

- An elevation layer (levels 0 to 2 per cell), cliff edges as a dual-grid ground like the terrain, stairs and ramps as
  things, walking rules (no stepping across a level change except on stairs) in `OverworldMap`, the art in
  `pipeline/pixel/terrain.py` or the world pipeline. Its own ADR.

### S11. The players' build mode

- A smaller Studio inside play: the player's house and yard only, the catalog limited to what they own and have
  unlocked, saved in the save file (an overlay on the map, never the content files), no Publish. Its own ADR, and the
  player decides when.

---

## 11. Instructions for agents

### Read order

1. `AGENT.md`, `CLAUDE.md`, `WIP.md` (top section).
2. This spec, all of it. Then the phase you are building, again.
3. The ADRs in the header; `docs/decisions/README.md` for the next number.
4. The code you touch: `game/scenes/overworld/overworld.gd`, `town_map_view.gd`, `ground_layer.gd`, `pixel_view.gd`,
   `overworld_art.gd`, `game/content/overworld_content.gd`, `game/core/overworld/overworld_map.gd`,
   `overworld_state.gd`, `town_things.gd`, `game/app/settings.gd`.
5. `git log --oneline -10` and `git status`. Much of the overworld is uncommitted work: never revert or reformat files
   you are not changing.

### Rules

- **Tests first for `game/core/studio/`**: write the test, see it fail, write the code. Pure code takes data and returns
  data; it never touches files, nodes or the clock.
- **File writes:** only `StudioFiles` writes, and only to `user://studio/` (drafts, backups, the remake queue) and, through Publish, the content files and `pipeline/world/objects/`. Tests use
  `OverworldContent.load_world(temp_root)` on a copy made in `user://` and never write `res://`.
- **Do not change the content files by hand** while building the Studio, except the S0 canonicalization (a commit of
  its own) and test fixtures.
- **Typed GDScript** everywhere (the project makes untyped declarations errors); `class_name` on scripts other code
  uses; small files; `# LEARN:` comments with a learning-log entry where a choice is not obvious.
- **Godot APIs:** verify against Godot 4.7.2 (the engine or its docs); do not guess. A throwaway probe runs with
  `< /dev/null`.
- **Look at everything visible:** add screenshot moments to `game/tools/overworld_shot.gd`:
  `ROOTWARD_LANTERNTOWN=studio` (Edit with overlays), `studio-plain` (Edit with overlays off, to compare with `town`),
  `studio-catalog`, `studio-publish`, `studio-land`. Take them at 2560 x 1440 (`SHOT_SIZE=2560x1440`) and look.
- **Performance:** measure the frame time while dragging on Lanternroot (`show_fps`); the budgets of section 4 are
  acceptance criteria.
- **UI:** English only while it is a developer tool; every string goes through one table so it can be translated if
  it becomes the players' build mode. Modern full-resolution panels in the game's theme, compact (the player finds
  big menus too big).
- **The GPU rule:** Run remakes calls `scripts/world.sh make`, which handles ComfyUI and Blender; never start either
  directly from the game.
- **Ask the player** only for what section 13 marks as theirs, or anything that changes what they see or play.

### Working in parallel (when the player asks for several agents)

| Lane | Owns | Starts after |
|---|---|---|
| A. Model | `game/core/studio/` and its tests | now |
| B. Shell and tools | `game/scenes/studio/` (studio, overlays, tools, panels except the catalog) | A's StudioDoc and commands interfaces are written |
| C. Catalog | `catalog.jsonc`, `studio_catalog.gd`, `catalog_panel.gd`, the catalog test, thumbnails | now (S3 content can be drafted in S0) |
| D. Files | `jsonc_writer.gd`, `studio_files.gd`, drafts, publish, backups, the round-trip test | now |

One Godot process at a time per machine for tests and screenshots (they share the import cache); the lead merges and
runs the full verification.

### Pitfalls already known

- Godot's JSON gives every number as a float: convert whole numbers back to integers before writing and before
  comparing `at` and `size`.
- Comments live only in each file's header today; keep them; do not add comments inside data.
- The map's `objects` array is drawn in y order by its feet, not in file order; file order is only for diffs.
- A building's footprint is its whole picture (ADR-0064); its door is in the footprint's bottom row.
- The ground is baked into one picture per ripple frame; repaint regions, or a brush stroke will stall.
- Older pictures are drawn enlarged (their index has no `tile`); a placed old picture is fine, but show its badge.
- The overworld's input handler must stop while editing, or keys leak into the game behind the editor.

---

## 12. Instructions for the player

### Turning it on

- Settings, Developer, **Studio** (shown only when the game runs from the repository), or launch with
  `ROOTWARD_STUDIO=1 scripts/play.sh`.
- In Lanternroot: **F2** to edit, **F1** to play. Esc leaves a tool, then Edit.

### Keys (Edit)

| Key | Does |
|---|---|
| F1 / F2 | Play / Edit |
| S, E, Del, F, R | Select, Eyedropper, Delete, Flip, Facing |
| Click, Shift-click, drag on ground | select, add to the selection, box select |
| Drag a selection | move it (green fits, red does not); hold **Alt** to place anyway |
| Arrows, Shift+arrows | nudge one or four cells |
| Ctrl+Z, Ctrl+Y | undo, redo |
| Ctrl+D, Ctrl+C, Ctrl+V | duplicate, copy, paste at the cursor |
| `[` and `]` | previous or next variant (another size or style) |
| Tab | cycle what is under the cursor; with nothing under it, hide or show the catalog |
| Wheel, middle-drag, WASD | zoom, pan |
| O, Home | overview of the whole map, back to the player |
| Ctrl+S | save the draft now (it also saves itself) |

### The loop

1. Edit (F2). Arrange, paint, resize. The draft saves itself.
2. **Play draft** to walk it. Nothing you do while play-testing touches your real save.
3. **Publish** when it is right: read the list of changes and problems, confirm. The game's files are now changed.
4. Commit with git when you are happy (`git add` the files Publish names; the Studio never commits).
5. Changed your mind after publishing? The backup of every published file is in
   `~/.local/share/godot/app_userdata/Rootward/studio/backups/`, and git has the rest.

### Remakes

Dragging a thing to a new size queues a remake. **Run remakes** draws the new pictures (a few minutes each; it stops
ComfyUI and Blender as needed). Until then the thing shows a hatched placeholder, which is never published as art.

---

## 13. Open questions (the player's to answer; agents ask before building the phase that needs the answer)

1. **The Godot map tool:** dropped; the Studio replaces it (section 2). Say so if you want it back.
2. **Studio from the title screen:** should the title offer "Open Studio" to edit any map without starting a game? (S0
   could add it cheaply.)
3. **Editing people's looks** in the Studio (their cast sheet is remade from the look, minutes per person): in scope, and
   in which phase?
4. **Flip and rotation:** art has one facing. Is flipping enough, or should some things (benches, carts, signs) get
   four-facing art from the pipeline?
5. **The catalog's tree** (section 8.2): the grouping to review once it exists (S3).
6. **Unlock rules** (S8): is "a flag holds" enough, or should unlocks also come from items the player owns? (Built in S8
   as a condition in the quests' language, so flags, not, all and counts; items owned can join it later.)
7. **Japanese:** stay English while it is a developer tool (assumed), translate when it becomes the players' build mode.
8. **Draft per map or per change set:** one draft per file is assumed; does the player want named drafts ("a new
   square", "the lane at night") to switch between?
