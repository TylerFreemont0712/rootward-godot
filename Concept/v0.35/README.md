# v0.35 — Build the town, connect its places

Written 2026-10-19. **Status: implementation in progress; F01, P01–P06 and B01 are complete.**

The player requested detailed instructions for Luna to implement the editor's next three steps, plus creating new
areas and expanding the map. This folder is that implementation package. It is a new version of the **Studio plan**;
it does not replace the learning content already documented in `Concept/v0.4` or copy the game into another folder.

## The outcome

An author can place and inspect people, connect doors, assemble and furnish a building, create an outdoor area,
and connect that area to Lanternroot without editing JSONC by hand. Every persistent change remains a draft until
Publish. Play draft uses the same rendering, collision and transitions that published content uses.

## The next steps, in order

| Step | Deliverable | Completion means |
|---|---|---|
| 1. People & Doors | A working dedicated workspace over the existing people, entrance and room tools | Place/move a known NPC, inspect their dialogue/quests, make a room, link a door, and walk both ways |
| 2. Build | A construction workspace using current buildings, boundaries, gates and furniture | Build and resize a cottage, connect its fence/gate, furnish its room, and reach existing Map size controls |
| 3. Modular buildings | Real grid construction with material modules, partitioned interiors and assembled roofs | Draw a building shell, change its dimensions/materials, divide its interior, and enter/leave it |
| 4. Areas & expansion | Outdoor-map creation, district authoring, safe growth and paired routes | Add a meadow area, connect it to town, expand town without stranding references, and publish the whole change |

Step 4 is part of this plan, not a vague future suggestion. Step 2 exposes resizing that already exists; step 4 adds
the missing reference safety and world-authoring workflow. Heights, bridges across levels and player-owned housing
remain later work (old Studio S10/S11). They must not delay these four steps.

## Read and implement

| File | Purpose |
|---|---|
| [00-luna-execution-guide.md](00-luna-execution-guide.md) | Read order, repository contracts, shared integration work, task protocol and recovery rules |
| [01-people-and-doors.md](01-people-and-doors.md) | Step 1: UX, state transitions, concrete implementation packets and acceptance cases |
| [02-build-workspace.md](02-build-workspace.md) | Step 2: scoped catalogs, existing construction tools, sizes, rooms and boundaries |
| [03-modular-buildings.md](03-modular-buildings.md) | Step 3: proposed schema, compiler, art sockets, roofs, interior ownership and edit transactions |
| [04-areas-and-expansion.md](04-areas-and-expansion.md) | Step 4: new maps, named places, resize/reference migration, routes, saves and Publish |
| [05-delivery-checklist.md](05-delivery-checklist.md) | Dependency order, executable acceptance stories, evidence and a ready-to-use Luna kickoff prompt |

Shared routing **F01**, People & Doors **P01–P06**, and the initial Build workspace **B01** are complete.
Construction continues with **B02–B06**, then M01–M08 and W01–W07 one packet at a time. Definitions of done are cumulative: publishing an area must still preserve people,
doors, room editing and terrain variety.

## Current implementation handoff

**P06 — People & Doors acceptance complete (2026-10-19).** The new mounted delivery story follows F2, person
Locate/Place, map pickers, cross-map confirmation/cancel, coordinated undo/redo after restart, Make interior,
furnishing, rejected arrivals, chosen facing, link cancellation, runtime room transitions, dialogue editing and
Back to person. It confirms Publish through the mounted review dialog, checks the three written fixture files
(`maps/lanternroot.jsonc`, `maps/cottage-pell.jsonc`, `talk/pell.jsonc`), then restarts with a new empty draft directory.
A second case checks sliding/resizing an existing linked building, exact paired room-return undo/redo across map
navigation, and consistent saved geometry after restart. The real town/Home files remain unchanged. Runtime
transitions invoke the callback used on arrival; the test does not simulate player-authored boots movement.

The targeted regression exposed an untyped empty history list while removing a room or loading a missing saved map;
the fallback is now explicitly `Array[String]`. Native Japanese room review also exposed numbered translation slots
in the entrance inspector; both link formats now use `StudioText.f`. Effective coverage is **120 distinct cases in
10 suites across named runs**: the nine-suite 118-case run had three Rooms errors, its corrected 25-case rerun is
green, and the final new acceptance suite passes 2/2. Exact commands, prior failed cases, native screenshot list
and timing are in `shots/studio-p06/evidence.txt`. Ordinary geometry Undo history remains local to its session;
saved paired geometry survives restart. Coordinated NPC transaction history survives restart and is tested.

**B01 — Build workspace mounted (2026-10-19).** F2 → **Build** now owns the shared lower shelf. Its thin wrapper
reuses `StudioPlacePanel`, canonical entries/cards/previews and existing Arrange placement. It exposes Buildings,
Boundaries, Gates and Floors & furniture, with its own search and scroll. Caller scope intersects user filters, so
Recent, On this map, search and Reset cannot leak trees/people into construction. Passive refresh and replacement
art updates retain scroll. Unsupported area-selection state is cleared on tab change; Tab in Build cannot change
Objects' catalog visibility. Changing construction groups cancels pending placement/strokes. Objects stays unrestricted.

The inventory fixture was written before the classifier. Current categories/families are complete enough to reuse:

| Group | Existing classification | Entries |
|---|---|---:|
| Buildings | `kind: building` | 30 |
| Boundaries | `street/fences_and_gates`, excluding the declared gate families | 51 |
| Gates | Same category and exact families `gate`, `gate-wide-2`, `gate-wide-3`, `gate-wide-2-v`, `expand-gate` | 9 |
| Floors & furniture | Indoor props in `furniture` | 37 |

No asset-name substring guessing, optional schema field, duplicated asset definitions or map-format changes are
needed. Paint floor is a separate action, enabled indoors, that opens the existing Land floor brush; rugs remain
nonsolid ground-layer props and furniture keeps its catalog collision. Full room navigation/protection is B04;
the new workspace does not imply modular buildings, advanced gate insertion or reference-safe expansion.

B01 evidence: core classification/scoping **3/3** (`shots/studio-b01/build-final.log`), mounted Build **7/7**
(`scene-final.log`), existing filter **27/27** and catalog panel **18/18** (`acceptance.log`). This is **55 distinct
cases across named runs**, not one new all-green 55-case invocation. The initial new tests had two faulty assumptions:
search also matches category IDs, and the bounded Recent list fits without scrolling at this width. The corrected
fixtures use an excluded search term and genuinely scrollable On this map content. Earlier failed logs are retained.

```bash
scripts/test.sh -a res://test/core/studio/studio_build_catalog_test.gd -a res://test/scenes/studio_build_test.gd -a res://test/core/studio/studio_catalog_filter_test.gd -a res://test/scenes/studio_catalog_panel_test.gd
# Initial affected run: shots/studio-b01/acceptance.log
scripts/test.sh -a res://test/core/studio/studio_build_catalog_test.gd -a res://test/scenes/studio_build_test.gd
# Core classification green; earlier scroll-fixture failure retained in build-final.log
scripts/test.sh -a res://test/scenes/studio_build_test.gd
# Final mounted cases all green: shots/studio-b01/scene-final.log
```

Scoped lint passes; native `buildings-en.png`, `boundaries-en.png` and `furniture-ja-small.png` under
`shots/studio-b01/` show two complete rows and fit at 1920×1080 / 1280×720. Reproduce with
`ROOTWARD_LANTERNTOWN=studio-catalog[-ja] ROOTWARD_BUILD_GROUP=building|boundary|gate|furniture
scripts/screenshot.sh res://tools/studio_build_shot.tscn <output.png> 45`; set `SHOT_SIZE=1280x720` for the smaller
view. Existing schedule warnings and older untranslated Studio chrome remain. The full-project suite was not rerun;
earlier unrelated failures remain recorded below. No new art, town-map publication or commit was made. **B02 is next.**

**P05 — Dialogue, quests and readable diagnostics complete (2026-10-19).** The person inspector shows authored
map/cell/facing and reads quest references from current quest/talk documents, including unpublished edits. References
retain quest IDs and step indexes; clicking one opens the existing quest editor at that step. Edit dialogue uses the
existing Talk editor, validates readable dialogue before navigating, and retains Back to person. Returning commits
focused text, re-resolves the person on the remembered map, and restores map history ownership. Unplaced people
return to their roster card; ambiguous placements remain unselected with a duplicate warning. Search/filter state
stays in memory, so an active filter can still hide the returned card. Both header and keyboard undo use the active
editor's history. No new document format or source-map writes are introduced.

Entrance rows carry structured link problems with exact source map/index/snapshot. Their problem action locates
that source, and Repair link opens the existing link editor. The map overlay distinguishes closed, valid and broken
entrances with labels and dashed/arrow/cross markers, using the same link-state checks as Publish. Destination
coordinates remain visible; generated-room return labels retain their start-marker spacing. Approach/reachability
warnings continue to appear in Publish's existing diagnostics; they are not additional entrance-row status codes.

Evidence: `scripts/test.sh -a res://test/scenes/studio_people_test.gd` — **18/18**, zero errors/failures/skips/orphans,
log `shots/studio-p05/people-final.log`. The earlier five-suite affected run additionally passed doors **27**, index
**4**, mode **12**, and quests **6**; exact command and log below. Its initial People run failed one newly added test
because the fixture was already facing left and the test called a nonexistent focus helper. Those test mistakes
were corrected, and the final People run above passes. The earlier failed log is retained, not presented as green.

```bash
scripts/test.sh -a res://test/scenes/studio_people_test.gd -a res://test/core/studio/studio_doors_test.gd -a res://test/core/studio/studio_people_index_test.gd -a res://test/scenes/studio_mode_test.gd -a res://test/scenes/studio_quests_test.gd
# Earlier affected run: shots/studio-p05/acceptance.log
```

Scoped lint passes for the 12 changed/added scripts (`shots/studio-p05/lint.log`). Native review:
`people-return-en.png`, `people-return-ja.png`, `dialogue-en.png`, and `entrance-problem-ja-small.png` under
`shots/studio-p05/`. Reproduce with `ROOTWARD_LANTERNTOWN=studio-people-doors[-ja] scripts/screenshot.sh
res://tools/studio_people_navigation_shot.tscn <output.png> 45`; use `ROOTWARD_P05_VIEW=talk|quest|problem`
for each navigation view and `SHOT_SIZE=1280x720` for the narrow review. These use isolated drafts/saves and do not
publish. Screenshot logs retain the existing schedule-anchor warnings. Existing English Studio chrome and raw
authored prose remain partly untranslated; new P05 formats and composite quest-reference labels are localized.
The full project suite was not rerun during P05; its previously recorded failures below remain unresolved. P06's
later mounted acceptance and B01 implementation are recorded above. No commit made.

**F01 and P01 complete (2026-10-19).** F01 routes each active workspace through one descriptor and one shelf/layout
path. Regression coverage includes tab cycling, hidden-shelf input, focus and Escape priority, active-link, land-stroke
and placement cancellation, and window resize. P01 mounts People, Entrances and Player start on the shared lower shelf.
Its read-only index reflects draft maps, sorts the inventory, preserves search/filter/subview state, surfaces
missing/unknown data, and refreshes on edits, undo/redo, reload, map switch and room creation. Filter counts update
with edits; browsing and room creation leave the canonical source map unchanged. The panel retains existing
locate/actions, start controls, inspector context, dialogue jumps, entrance status and Place-transition flow. English
and Japanese native screenshots were reviewed.

**P02 — placement, move and start actions complete; P03 — Link editor and arrival preview complete (2026-10-19).**
The implementation was reviewed directly before continuing to the next packet. Cross-map undo had compared the
monotonic SID allocator with its earlier value, rejecting a valid inverse; transaction versions now compare authored
text and live IDs. Earlier allocator-based draft records are verified and restored compatibly. Cancellation of a
provisional transition removes its history entry, preventing accidental resurrection through Redo. Unknown NPC IDs
are rejected at the work API.

P03 gives linking the shared lower shelf, with a persistent source summary, destination picker, Cancel, instructions
and validity. Source/arrival markers and an arrival-facing arrow remain visible while choosing facing. Temporary
map navigation retains the original source; final commit rechecks its session/SID/object snapshot and the destination
through the Publish validator. Mutation controls and shortcuts are isolated while linking. Go to destination is
validated, read-only navigation with an arrival marker. Links remain one-way and Unlink retains the room/furniture.
Both Japanese reading editions format the source name through `StudioText.f`.

The review also removed hidden People-card rebuilds from Objects/Land edits and indexed all person placements in
one world scan. On the 1,609-object town, median barrel placement fell from **34.18 to 16.55 ms**, and cottage placement
from **39.01 to 18.66 ms** (`ROOTWARD_BENCH_SCALE=0.4`, headless command timings). The complete roster takes 668 µs
median versus 6,488 µs for the old repeated lookups alone. This is a substantial reduction, not a 60-fps certification:
individual edits can still exceed the 16.7 ms frame budget. Evidence logs and the roster probe are in
`shots/studio-review/`; `game/tools/studio_place_bench.gd` reproduces the edit workload.

Acceptance covers SID/facing history, cancelled/stale cross-map confirmation, invalid candidate maps, all four
transaction fault points, prepared/committed restart recovery, dependent undo/redo and Revert, shared redo
invalidation, schedule work/home/inn preservation, grouped Publish/cleanup, map start without character-save changes,
link cancellation at all stages, target/source revalidation, actual Play draft arrival/facing and published reload.
The earlier room test now explicitly uses a static Pell fixture, with scheduled Pell tested separately.

**P04 — Interior workflow complete (2026-10-19).** A linked building's valid interior now opens from Entrances with
the explicit **Furnish room** action and leaves Objects active. A newly created interior that loses its link through
Undo remains discoverable as an **unlinked room draft** in the map picker and Entrances. Locate opens that draft;
Reconnect is offered only when its single return warp uniquely matches one unlinked building. The action checks both
room and building snapshots again after navigation before restoring the entrance. Revert protects a new room while
any outside entrance still points to it; after unlinking, it confirms and removes the room draft and its furniture.
Returning from Revert uses the draft room's saved outside warp when its original building has already been unlinked.
The mounted room workflow passes 25/25 cases, and the focused draft-index suite passes 4/4. The final People & Doors
acceptance packet P06 was still open at that handoff, along with P05 and the Build packets. P05/P06 and B01 are now
complete as recorded above; modular construction and full area authoring remain open.

Review evidence: the affected 11-suite regression passed **144 cases** (`report_1319`); the later transaction/recovery
checks passed **4 cases** (`report_1320`), and the subsequent five-suite acceptance passed **50 cases** (`report_1321`).
Final expanded acceptance: **189 cases in 15 suites, zero errors/failures/flaky/skips/orphans**, in 2 min 46 s.
The authoritative log is `shots/studio-review/rootward-studio-review-acceptance.log`; XML/HTML are preserved at
`shots/studio-review/gdunit-final/report_1/`. This includes the corrected static Arrange/context fixtures and fence
row expectations (posts/ends, ghost lookup by cell). The connected-fence placement result no longer disappears on
the next hover update; `boundary-result.png` shows the retained “Placed 6 of 7” result. Reproduce it with
`ROOTWARD_BOUNDARY_RESULT=1 ROOTWARD_LANTERNTOWN=studio-catalog scripts/screenshot.sh
res://tools/studio_boundary_shot.tscn shots/studio-review/boundary-result.png 55`.
Earlier concurrent runner processes reused a numeric report folder; the preserved named logs retain their results.
Full-project run: **2,097 cases in 224 suites, 5 errors, 33 assertion failures, 58 orphan nodes**, exit 100
(`shots/studio-review/rootward-studio-review-full-tests.log`, 12 min 57 s). It started before the final fixture/fence
corrections: its nine failing Arrange/context/row cases subsequently pass in the final 189-case acceptance. The full
suite was not rerun after those corrections. It remains red outside those fixes: Shardrun loot, missing upgrades,
quest-debug step assumptions, quest/command serialization expectations, one reading-caption assertion, a stale well
translation, and catalog/remake checks. In particular, **24 existing generated `*-update-*` world pictures have no
catalog entry**. This review neither regenerates nor silently adopts those pending replacement pictures. The full
failed-case list is preserved in `shots/studio-review/full-failed-cases.txt`. All 21 edited scripts parse and pass scoped lint; whitespace checks pass. Native
English/Japanese link and People screenshots were reviewed under `shots/studio-review/`. No commit was made.

F01/P01 evidence: `scripts/test.sh -a res://test/scenes/studio_mode_test.gd` (`report_1313`, 11 passed),
`scripts/test.sh -a res://test/scenes/studio_people_test.gd` (`report_1311`, 12 passed), and
`scripts/test.sh -a res://test/scenes/studio_catalog_panel_test.gd` (`report_1312`, 18 passed). Native screenshots:
`shots/studio-people-doors-2026-10-19.png` and `shots/studio-people-doors-ja-2026-10-19.png` (1920 × 1080).
The catalog suite and screenshot helper report the known `overworld/schedules.jsonc` compiler warning that home at
`(39, 44)` is not a free cell. The test suites otherwise passed with zero errors/failures. No full suite or lint was run.
No commit was made.

## Baseline observed in the repository

- At the specification baseline, Objects, Land and Quests were active while Build and People & Doors were disabled.
  The current implementation now mounts People & Doors and Build; B02 onward extends the construction workflows.
- People placement, uniqueness checks, facing, door linking, door-handle movement and Make interior already exist.
  They are currently accessed through Objects and the inspector. Existing rooms are ordinary maps, usually 11 × 8.
- Buildings/props resize with art and collision; connected timber fences and several boundary/gate assets exist.
  Scaling a whole building sprite is **not** modular room/roof construction.
- The shared bottom workspace is 300 design pixels high and shows two object-card rows. Land occupies the same area.
- Map growth/shrink already changes ground rows and moves objects, starts and incoming door targets. Districts,
  schedules and quest pins require additional coordinated reference handling.
- `StudioDoc.KINDS` currently supports map/catalog/quests/talk. Places and schedules do not yet have equivalent
  dedicated Studio document editors. Generic outdoor map creation has a core/session entry point, but no complete UI.

These are code observations, not a claim that every existing regression passes. Preserve the current WIP's known
failures and report any new ones separately. Do not mark an implementation checkbox complete because this spec exists.

## Decisions for this release

1. Reuse the current command, draft, JSONC, Play draft and Publish paths. No second world format or second editor.
2. Share one lower workspace across tabs. Keep world navigation and inspection visible; avoid another permanent dock.
3. Keep object/asset identities stable. Catalog filters change discoverability, never rewrite existing placements.
4. First modular buildings are rectangular, one story, with editable interior partitions and flat/gabled roofs.
   L-shaped shells, courtyards and multiple floors have an extension contract in step 3; they are not implied features.
5. New outdoor areas are separate maps reached by explicit routes. A named district is a rectangle within a map.
   Enlarging an existing map is a third distinct operation, with an impact preview.
6. Art modules must match the game's established camera and exact tile sockets. Use existing art or deterministic
   placeholders while implementing; new bitmap art uses ChatGPT ImageGen when needed, with mechanically fitted joins.
   The player's request to stop generating replacement object pictures still applies.

## Relationship to earlier plans

Read [the original Studio design](../v0.3/10-lanternroot-studio.md) and ADR-0066 for the existing editor contract.
ADR-0076 governs sizing/asset reviews; ADR-0077 governs land variety/area selection. This plan prioritizes workspaces,
construction and world authoring before heights/player housing. Historical S0–S11 status stays historical; completion
of this plan is tracked with F/P/B/M/W packet IDs to avoid silently redefining an old completed phase.
