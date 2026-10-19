# Luna execution guide

## 1. Read before editing

1. Read root `AGENT.md`, `CLAUDE.md`, current `WIP.md`, and the Studio entries in `docs/PLAN.md`.
2. Read this folder's README, then the entire specification for the packet being implemented. Follow its linked
   contracts before coding. Do not implement the whole release in one unreviewable change.
3. Read ADR-0066, ADR-0076 and ADR-0077 in `docs/decisions/`, and relevant current implementation/tests.
4. Inspect `git status --short` and recent history. The working tree contains substantial prior code/art changes.
   Preserve them. Current player preference: **do not commit until asked**, and never commit `WIP.md`.
5. Write a brief progress message naming the packet, files being touched and expected observable result.

The paths in these documents are relative to the repository root unless they are Markdown links. A file marked
**NEW** is a proposed addition, not an existing API. Read actual signatures before calling existing methods.

## 2. Source map

| Concern | Existing implementation to inspect |
|---|---|
| Tab state, layout, signals, map switching | `game/scenes/studio/studio.gd`, `studio_top_bar.gd`, `studio_tools.gd`, `studio_keys.gd` |
| Shared catalog and filtering | `game/scenes/studio/studio_place_panel.gd`, `studio_catalog_card.gd`; `game/core/studio/studio_catalog_filter.gd`, `studio_catalog.gd` |
| Placement, selection, sizing | `game/scenes/studio/studio_arrange.gd`, `studio_selection.gd`, `studio_fit.gd`, `studio_ghost.gd`; `game/core/studio/studio_resize.gd` |
| People, links, rooms | `game/core/studio/studio_doors.gd`; `game/scenes/studio/studio_link.gd`, `studio_inspector.gd`, `studio_work.gd` |
| Dialogue and quest documents | `game/scenes/studio/studio_quest_panel.gd`, `studio_quest_work.gd`, `studio_talk_editor.gd` |
| Terrain and map resizing | `game/core/studio/studio_land.gd`; `game/scenes/studio/studio_land_tool.gd`, `studio_land_panel.gd`, `studio_map_size.gd` |
| Fence topology | `game/core/studio/studio_boundary.gd`; `StudioWork.boundary_plan` / `place_boundary` |
| Documents, commands, history, JSONC | `game/core/studio/studio_doc.gd`, `studio_commands.gd`, `studio_history.gd`, `jsonc_writer.gd` |
| Sessions, drafts and Publish | `game/scenes/studio/studio_session.gd`, `studio_files.gd`, `studio_work.gd`, `studio_publish.gd`, `studio_publish_tools.gd` |
| Content schema and map compilation | `game/content/overworld_content.gd`, `game/core/overworld/overworld_map.gd` |
| Actual rendering | `game/scenes/overworld/town_map_view.gd`, `pixel_view.gd`, `ground_layer.gd` |
| Save/load and world rules | `game/app/overworld_store.gd`; locate callers and map transitions before extending save handling |
| Authoritative data | `game/content/packs/core/overworld/` including `maps/`, `catalog.jsonc`, `places.jsonc`, `schedules.jsonc`, `quests.jsonc` |

## 3. Non-negotiable implementation contracts

- Typed GDScript. Pure algorithms/validation return data from `game/core/`; scene nodes draw it and dispatch commands.
- Disk map ground is an array of character rows with a legend. Runtime map ground is a flattened array of terrain
  IDs, with derived width/height. Never serialize runtime map dictionaries over raw documents.
- A map object's SID belongs to its editing session and is not persisted. Never put SIDs into inter-map files.
- One user gesture produces one history entry. Mouse movement, ghost previews, search and hovering produce none.
- Cancel restores the pre-gesture state. Validation failure changes no documents. A failed downstream build cannot
  leave half of a cross-map edit applied.
- Canonical source writes occur only through Publish. Drafts, source conflict hashes, backups and isolated Play
  draft apply to every new document type. Never call FileAccess from a core rule.
- Keep existing art optional. Missing modules get deterministic visible placeholders and diagnostics, not crashes.
- Keep terrain's coordinate-based variation and shared seams. No random tile IDs stored just to vary appearances.
- Preserve both Shardrun and Spellforge; no unrelated runtime, art or language-system rewrites.
- New visible text uses `StudioText`/the project's translation mechanism with English and Japanese coverage.
- Preserve known legacy content. New optional schema fields need defaults; no mass content rewrite on load.

## 4. F01 — Shared workspace routing (before P01)

**Goal:** make tabs own one lower shelf and one active world tool, so enabling more tabs cannot leak input.

1. Read `StudioMode.set_tab`, `_bottom`, `_dock_view`, `set_place_list`, `_place_before_land`, and `StudioKeys.handle`.
   Record existing selection, focus and modal behavior in the packet handoff before changing it.
2. Introduce an explicit internal tab descriptor (new helper or small constants table): stable ID, title key, shelf
   owner, allowed world tools, history owner and whether the ordinary inspector applies. IDs are `objects`, `land`,
   `people`, `build`, `quests`. Use existing `people`/`build` translation titles rather than inventing near-duplicates.
3. Route shelf visibility and viewport insets through one function. At 1920 × 1080, reserve the existing 300px shelf,
   176px left tools, 304px inspector, top/status bars. Objects and scoped Build catalog retain two complete card rows.
   People can use cards plus filters within the same height. At smaller windows, use scrolling, not overlapping docks.
4. Tab transition sequence: settle valid text edits through their current editor; cancel incomplete gestures;
   dismiss context menus; cancel linking with its existing return-to-origin behavior; release stale focus; set tab;
   show its one shelf; recompute camera viewport; refresh inspector/overlay/hint. Do not clear another tab's filters.
5. Retain per-tab search/category/scroll/filter state in memory. Objects' catalog visibility preference must survive
   Objects → Land → People → Build → Objects. None of this UI state is written into a map file.
6. Allow only one world gesture at a time: idle/select, place, boundary-stroke, land-stroke, link, modular-preview,
   region-rectangle. These are conceptual states; adapt existing controllers instead of replacing all with a new framework.
7. Input priority: modal dialog → focused text editor → active gesture → active workspace → global navigation.
   Text focus consumes Delete/R/arrows/Space. Escape closes/cancels the highest-priority active operation only.
   Switching tabs never places an object, commits a partial stroke, triggers Play or mutates the prior selection.
8. Define selection policy: keep compatible world selection for Objects/Build/People; show an explanatory inspector
   for an incompatible selected object rather than silently editing it with the active tool. Land/Quests can retain
   their existing clear-selection behavior. A link-target map switch is temporary, not a generic tab reset.
9. Enable `people` only when P01 mounts a real view; enable `build` only when B01 does. Unfinished modular tools
   remain hidden until M03; no enabled button that says “coming later.”
10. Add routing regressions to `game/test/scenes/studio_mode_test.gd` and relevant catalog tests during implementation.
    Cover repeated switches, hidden shelf clicks, focus, Escape, active-link cancellation and resize of the window.

**Exit:** existing three tabs behave as before, only one shelf receives mouse events, switching during every active
gesture is safe, and the shared implementation accepts the People/Build views without another layout rewrite.

## 5. Multi-document transaction contract

Existing cross-map operations use `elsewhere` metadata and individual session histories; this does not by itself
prove atomic world transactions. Inspect actual behavior, then implement the following where a packet needs it.
Do not claim that separate successful writes constitute rollback support.

For paired routes, modular/interior updates, coordinate migrations and any cross-map person move touched by this work:

1. Build a pure plan containing affected document keys, before hashes, after data, inverse data and human summaries.
   Use stable file paths/document keys for persisted references, never scene Nodes or SIDs from another session.
2. Resolve all sessions, validate all post-change documents/world references, and check plan versions before applying.
3. Stage every changed in-memory document, history entry and draft payload. Apply as a single coordinated action with
   one transaction ID and one primary history owner. Other affected histories expose the same action, not an
   independent inverse that could undo only half. Histories must reject stale undo when a dependent document changed.
4. On error, restore every original document, history cursor and draft. Inject failures to prove this behavior.
5. Save a draft transaction manifest with before/after hashes and staged payloads through `StudioFiles`. Restart
   recovery completes a committed draft transaction or restores the originals; it never guesses from file order.
6. Undo/redo is coordinated and idempotent. A new edit after undo invalidates dependent redo entries together.
   Revert a participating document offers the transaction impact and reverts the coordinated change or cancels.
7. Publish reviews the complete dependency group. Validate/conflict-check everything before writing. Use the existing
   backup/temp-write system, adding a recoverable group manifest/rollback if needed; per-file atomic rename alone
   is not atomic across multiple files. Fault-injection must cover failure after the first canonical file rename.

Implement this as a small shared scene/service layer with pure plan helpers, **not** a global rewrite of command
history. NEW suggested paths: `game/core/studio/studio_world_plan.gd` and
`game/scenes/studio/studio_world_transaction.gd`. P02 must use it if its cross-map move currently fails the contract;
M01 and W01 must establish it before adding their coordinated writes. Existing single-map commands keep their APIs.

## 6. Packet workflow and evidence

For every packet:

1. List the exact contract and existing calls it reuses. Identify any proposed helper as NEW.
2. Implement model/schema/serialization before UI that writes those fields. Add targeted implementation tests when
   requested by the implementing session; acceptance cases here define expected behavior, not evidence of execution.
3. Mount UI and wire both input and refresh paths. Trace draft, reload, undo, redo, Play draft, Publish and Revert.
4. Review a native screenshot for visible work, following root project instructions. Add a deterministic temporary
   fixture/helper when the actual feature needs interaction; a startup screenshot alone proves no interaction.
5. Update the packet checkbox only when its acceptance cases actually pass. Record exact commands, outputs, failing
   case names, screenshot paths and residual limitations. Do not copy old test totals as current results.
6. Update `docs/PLAN.md`, `WIP.md` and appropriate decisions/learning notes. Architectural decisions start as proposed
   until implemented. Keep generated source art and prompts attributable; do not rewrite unrelated content.

Relevant existing test commands (run from repo root during implementation/verification):

```bash
scripts/test.sh -a res://test/core/studio/studio_doors_test.gd
scripts/test.sh -a res://test/scenes/studio_people_test.gd
scripts/test.sh -a res://test/scenes/studio_rooms_test.gd
scripts/test.sh -a res://test/scenes/studio_mode_test.gd
scripts/test.sh -a res://test/scenes/studio_catalog_panel_test.gd
scripts/test.sh -a res://test/scenes/studio_resize_test.gd
scripts/test.sh -a res://test/scenes/studio_land_test.gd
scripts/test.sh -a res://test/scenes/studio_publish_test.gd
```

New helper tests mirror their source paths. These commands are examples for targeted checks, not permission to
claim the full suite passed. Ask for verification scope only if the implementing session's instructions require it.

## 7. Handoff format

```text
Packet: P01 / B02 / M04 / W03
Status: complete | in progress | blocked by <specific dependency>
Observable result:
Files changed:
Existing APIs reused / new APIs added:
Schema and compatibility effects:
Evidence: exact commands + results + native screenshots, or explicitly not run
Known failures and whether pre-existing:
Draft/undo/redo/reload/Play draft/Publish/Revert checks:
Next packet and first concrete action:
No commit made (unless the player requested one).
```

Do not omit a packet because its happy path “mostly works.” Name the missing acceptance case and keep it open.
