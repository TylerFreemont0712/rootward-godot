# ADR-0066: Lanternroot Studio, the town's editor inside the game

Accepted 2026-10-13. The spec is `Concept/v0.3/10-lanternroot-studio.md`; built in phases S0 to S11.

Updated 2026-10-18: ADR-0076 supersedes the resize-by-remake restriction below. Buildings and props can be sized
directly; art remakes remain a separate option. Right-click asset feedback is kept in a persistent review list.

## Context

Lanternroot is data: its maps, people, quests and things are JSONC under `game/content/packs/core/overworld/`
(ADR-0004, ADR-0061, ADR-0062). The outdoor map is 80 x 56 tiles with about 1,600 objects, and placing one means
typing its cell into a file. The player wants to arrange the town by hand, in the view they play, play-test a change
before keeping it, and have the change become part of the game. The model is The Sims' Build and Buy modes: arranging
a place should feel like play.

The order is the player's: scene editing first (S0 to S6), then the developer inspector (S7), things that take code
(S8), the quest editor (S9), heights (S10) and a build mode for players (S11). The spec holds the full design; this
record keeps the decisions a later reader could question.

## Decision

- **A toggle, and only where it can write.** The Studio exists only when the game runs from the repository and
  `Settings.studio` is on, or `ROOTWARD_STUDIO=1` for one launch. Exported builds contain the code but never show it.
  F1 and F2 do nothing otherwise, so children's normal play never sees it.
- **Play and Edit in one view.** F1 plays and F2 edits the same town. Edit draws the map with the game's own
  `TownMapView`, `GroundLayer` and `PixelView`. The grid, footprints, doors and markers are overlays on top, and all of
  them can be hidden. The check is a screenshot pair in S0: Edit with overlays off should match Play.
- **Content files are the source of truth.** The Studio reads and writes the JSONC that `OverworldContent` loads, and
  it invents no other format for published data. Play draft loads drafts through `OverworldContent.load_world(root,
  drafts)`; nothing else in the game changes for them.
- **Drafts, then Publish.** A draft is a copy of one content file in `user://studio/drafts/`, outside the repository.
  It is saved two seconds after the last edit and survives restarts. Publish runs every check over the whole world with
  the drafts applied (errors stop it; warnings may be accepted), shows the change in words, copies each current file to
  `user://studio/backups/`, and writes the new files through a temporary file in the same folder. A file changed on
  disk after its draft began is a conflict, offered as keep or rebase. The Studio never commits; git keeps the history.
- **A pure model, tested first.** The document, commands, rules, catalog model, diff and JSONC writer live in
  `game/core/studio/` with no nodes and no file access, and are tested headless before the code is written. Only
  `StudioFiles` touches files. Nodes in `game/scenes/studio/` draw state and send commands; they never decide an
  outcome.
- **Every edit is a command with an inverse.** A command's `apply` and `revert` return a new document and never change
  their input. Undo and redo cover every tool, and the history panel names each command.
- **A canonical writer, round-tripped.** `jsonc_writer.gd` keeps each file's header comment and key order, writes whole
  numbers as integers (Godot's JSON parser returns floats), and puts map rows and objects one per line. A test reads
  and writes every file the Studio can write and expects the same text. Map objects have no ids in the file, so the
  Studio gives each one a session id, kept in the draft. New objects are appended, so a git diff shows what moved.
- **Snapped by default, free by choice.** Positions and sizes are whole tiles (`OverworldScale.TILE`, 40 px). A ghost
  snaps to the grid and shows green where it fits and red, with the reason, where it does not. Holding Alt places it
  anyway and marks it as a problem. A picture is never stretched: a new size is a new picture.
- **The catalog is content.** `catalog.jsonc` holds the category tree and one entry per picture: kind, place, tags,
  defaults, `flippable`, and a `family` of variants. A test fails when a picture has no entry, or an entry names a
  picture that does not exist. Thumbnails are cached in `user://studio/thumbs/`.
- **Resize by variant or by remake.** A variant is another entry in the same family, swapped in place with `[` and `]`,
  keeping its feet where they stand. A thing with a world-pipeline spec can be dragged to a new footprint. The draft
  then holds the new spec, a catalog entry for it, and the new size with a hatched placeholder, which is never
  published as art, and the id joins the remake queue. Run remakes writes the spec into `pipeline/world/objects/` (an
  input to the art pipeline, not game content) and calls `scripts/world.sh make`, which owns the GPU rule; the game
  never starts ComfyUI or Blender itself. Publish writes the catalog entry and the map change.
- **Later phases are panels on the same tool.** The inspector (S7) reads and pokes the play-test state through
  `OverworldState` and logs every poke, and it never changes content. Things that take code and unlocks (S8), the quest
  editor (S9), heights (S10) and the players' build mode (S11) each get their own rules. S10 and S11 get their own ADRs.

### Modular boundaries (2026-10-16)

Walls, fences, railings and gates may declare a catalog `line` pair (`horizontal` and `vertical`, both 1 × 1 props).
An ordinary drag previews a straight run along its dominant axis, chooses that orientation, and places on release
as one undo step. A click retains the explicitly chosen orientation. Other objects retain Shift-drag rows. The
instance's properties survive orientation changes; programmed things keep their own placement and footprint.
`[` and `]` choose a variant before placement, during a pending row, or on an existing selection.

The four material wall sets have thin straight pieces and four directional corners. The corners join at cell centers,
and the art accounts for the camera's foreshortened depth. Gates have separate horizontal and vertical geometry.
Modular geometry can bypass restyling (`restyle: false`) while still using Blender, the shared palette cut, index and
review pipeline: diffusion can close the gate openings or change the ends that must meet exactly.

These pieces still occupy whole cells for collision. Allowing independent edges to share a square requires a separate
movement, pathfinding and interaction model; reducing a picture's thickness alone must not change walking rules.

## Alternatives

- **A Godot editor plugin, or the Godot map tool.** Its view would be the editor's, not the game's, so it would drift
  from play. The spec drops it and asks the player to confirm (concept section 13).
- **Editing the JSONC by hand.** This is the present state: coordinates typed into a file of 1,600 objects, with no
  view, no undo, and no check before a change reaches the game.
- **Autosaving into the content files.** Every stroke would land in the game's files, and an unfinished draft would
  play in the real game. Drafts and one checked Publish keep the content honest.
- **A separate editor app.** It would need its own renderer, so its edit view would drift from play, and its rules would
  be a second copy of the game's.

## Consequences

- Only Publish writes content files, so a bug in the Studio can damage a file, but the temporary file, the backups and
  git limit the damage to one change.
- The Studio's strings stay in one English table while it is a developer tool, so the players' build mode (S11) can
  translate them.
- Tests over the content and the pictures keep the catalog, the files and the art in step.
- The spec's performance budgets (60 frames a second while dragging on Lanternroot at 2560 x 1440; a pick under a
  millisecond from a spatial index that each command updates) are acceptance criteria. Measured 2026-10-13 on the
  1,592-object town (headless): a pick p95 19 µs; an edit about 15 ms of main-thread work (it was about 830 ms before
  the town changed only the changed objects' nodes and kept its baked ground), the frames after it under 9 ms (the
  live check runs on a worker thread); the player reports the desktop smooth.
- Until a remake is done, the thing shows its placeholder (its source's picture stretched, hatched in Edit), it and
  its catalog entry review as warnings, and the catalog's "old" filter lists what still needs remaking. Only a
  picture with a blockout spec can be remade at another size; an adopted re-cut offers its variants instead.
- The catalog is published through the same Publish as the maps, from its own draft (`StudioCatalogSession`).
- The ground is painted in place (S5): `GroundLayer` bakes in 320 px pieces and repaints the ring round changed cells,
  byte-equal to a whole bake, so a brush stamp costs about 1.5 ms. A map resize is one change in its own map's history;
  the doors of other maps that lead into it follow as changes in those maps' drafts, applied again on every undo and
  redo of the resize (the batch's `shift`), so the histories stay separate and the links stay right. A player's save
  made before a published resize keeps its old cell (the town loads it shifted); the map's header comment, which names
  cells, is not rewritten. The Land brush, ground swatches and Map size share the lower workspace with the Objects
  catalog, which shows two rows of asset cards; the left column remains for selection and overlays.
- Maps can be made in the Studio (S6, Make interior): a new room is 11 x 8 by default (the player's call, 2026-10-14;
  Map size changes it), named after its building's picture, and exists only as a draft until Publish creates its file.
  A new map's draft began from no text, so its base hash is the hash of "", which is what the disk gives while nobody
  has made the file: a file made meanwhile is a conflict, and a failed batch removes a file it created. Revert throws a
  new map away. Leaving Edit while standing in one plays the draft, so the real save never names a map that is not
  there; and the overworld now sends a save whose map is missing to the start map instead of starting over.
- A change can reach into other maps (S6): a batch's `elsewhere` (with `elsewhere_undo`, swapped by its undo) lists
  commands for other maps' drafts, applied after the batch, its undo and its redo. A person placed from another map
  leaves it in the same step, and a door slid along its row takes the room's way out with it. Undoing Make interior
  only takes the door's link away; the room is kept, and Publish warns that no door leads into it.
- The developer inspector (S7) is a Play panel (F3), not an Edit tab: the state it shows moves only in Play. Its pokes
  change only the play-test state (Play draft); without it the panel only looks, so a debug session never reaches the
  real save. The event log is derived from the state frame by frame (flags, quest steps, the map, a talk) plus one
  signal from the things' runner (`ThingHost.ran`), so the overworld needed no logging calls of its own.
- Things (S8): `unlocked_by` sits on the program (it is about the interaction) in the quests' condition language, and a
  locked thing is a plain prop rather than a silent one with a prompt. A program answers one hook (on_use, on_step or
  on_change); `links` names the things its changes reach. A chain of links runs one sandbox job after another (a queue
  in `ThingHost`), at most 8 deep and each thing once, so a loop of links ends. A new thing's file and starters are plain
  file drafts (`drafts/files.json`, with the hash of the text they began from) that Publish creates; the quest editor
  (S9) drafts quests.jsonc and the talk files the same way, so one mechanism covers every file that is not a map.
- The model carries more machinery than phase S0 needs (commands, session ids, the canonical writer). The round-trip
  test and the pure tests are what make it safe to grow into the later phases.

### v0.35 People & Doors review (2026-10-19)

- Cross-map person moves and scheduled work-anchor edits use `StudioWorldPlan` and `StudioWorldTransaction`.
  Every participating history and draft is staged together, with before/after hashes, coordinated undo/redo and
  an explicit prepared/committed recovery manifest. A dependent later edit blocks partial undo/Revert; publishing
  both sides clears the group. Existing single-document commands retain their API.
- A document version includes authored text and its live session IDs. The SID allocator remains monotonic and is
  excluded from version equality. Legacy allocator-based transaction records are verified before restoration;
  the next durable transition updates their hashes. No canonical content format changes.
- Link editing owns the shared shelf while active, with a source summary, destination picker, cancellation,
  validity and arrival-facing preview. Other shelves, editing controls and mutation shortcuts cannot act on the
  temporary target map. A final commit validates the original source snapshot and current destination again.
  Links remain one-way; Make interior continues to own its explicitly paired return. Go to destination validates
  and marks an arrival without editing it. Cancelled provisional transitions cannot return through Redo.
- People indexes group placements in one world scan. Hidden shelves invalidate without rebuilding cards, then
  refresh on opening. Link hover checks reuse results only for the same cell and exact runtime map version.

Evidence and remaining packets are recorded in `Concept/v0.35/README.md` and its delivery checklist. The changes
were implemented and reviewed directly; no replacement art was generated and no canonical town edits were published.

### v0.35 person/editor navigation (P05, 2026-10-19)

- Quest references derive from current quest/talk drafts and retain quest IDs and step indexes beside translated
  labels. Existing `mentions()` prose remains compatible. Navigation opens the existing Quests/Talk editor and
  settles focused edits; header and keyboard Undo agree on the active document.
- Back to person remembers map/person identity, re-resolves placements and refuses ambiguous selection. Unplaced
  people return to the roster. Missing/unreadable dialogue is diagnosed before navigation, avoiding the Talk editor's
  fallback to another available file. No new content schema or alternate dialogue editor is introduced.
- Entrance diagnostics retain source map/index/object snapshot and shared link-state codes. Their click locates the
  source through existing snapshot validation; overlays use the same states with text and geometric markers.
  Existing Publish approach/reachability warnings remain separate from destination link validity.

### v0.35 initial Build workspace (B01, 2026-10-19)

- Build owns one lower shelf and a separate instance of the existing catalog component. Cards, asset IDs, templates,
  preview caching, generation/review records and map commands stay shared. Caller scope intersects user filters,
  including Recent and On this map; it survives Reset without rewriting a catalog or placement.
- Existing kind/category and exact gate-family metadata classify the four views; asset names/tags are not parsed.
  No `build_group` field is needed for this inventory. Future ambiguous content should add explicit metadata before
  changing its discoverability, preserving legacy unset entries in Objects.
- Search/scroll remain independent per catalog. Passive refresh and art reload preserve scroll; unsupported area
  selection is cleared on workspace changes. Catalog-visibility shortcuts follow the destination's declared tools.
- Floors & furniture places ordinary indoor props with their current collision/draw-layer defaults. Paint floor
  navigates to the existing Land brush on interior maps. Dedicated room navigation/protection is B04; rectangular
  modular shells and roofs remain the M packets.
- P06 verifies mounted People/door/dialogue navigation through isolated Publish and draft-free reload. Ordinary
  geometry history remains session-local while paired draft geometry survives restart; coordinated NPC transaction
  history retains its existing restart recovery. Evidence and residual full-project failures are recorded in v0.35.
