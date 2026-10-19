# Delivery checklist and Luna kickoff

All implementation items start unchecked. This document is a tracking/acceptance artifact, not evidence that any
feature has shipped. Check a packet only after its detailed spec and the evidence requirements are satisfied.

## 1. Dependency order

```text
F01 shared workspace routing
 └─ P01 → P02 → P03 → P04 → P05 → P06     People & Doors
     └─ B01 → B02 → B03 → B04 → B05 → B06     Build with current assets
         └─ M01 → M02 → M03 → M04 → M05 → M06 → M07 → M08     Modular buildings
             └─ W01 → W02 → W03 → W04 → W05 → W06 → W07     Areas & expansion
```

Sequence the work as numbered. Dependencies on shared primitives can pull the **primitive** forward: P02 may add
the schedules adapter/transaction helper; M05 needs a conservative reference scan. W01 then extends/reuses these.
Do not pull the entire Areas UI ahead of People/Build or maintain two competing adapters. A packet may discover a
small correction needed in an earlier one; implement and record that correction before proceeding.

## 2. Implementation checklist

- [x] F01 — Shared shelf, tab state, input/focus priority and safe gesture cancellation. Evidence: mode suite `report_1313`, catalog suite `report_1312`, and mounted People screenshots listed in the README/WIP.
- [x] P01 — People/entrance/start panels and draft-aware indexes. Evidence: People suite `report_1311`, including live edits, filter counts, undo/redo, draft reload, map changes, room creation and unchanged canonical source.
- [x] P02 — Unique person placement, coordinated cross-map moves, scheduled-work anchors and map start. Final review/acceptance: 189 cases/15 suites, zero errors/failures (`shots/studio-review/rootward-studio-review-acceptance.log`); fault rollback/restart, grouped history/Revert/Publish and unchanged character save covered. See README for final evidence.
- [x] P03 — Link states, valid arrival/facing, cancel/navigation and unlink semantics. Mounted link shelf, source/arrival markers, stale revalidation, input isolation, cancel from all stages, Play draft and published arrival tested; native EN/JA and 1280×720 review in `shots/studio-review/`; included in the final 189-case acceptance run.
- [x] P04 — Existing room creation/opening/furnishing and unlinked room handling. Linked interiors open through **Furnish room**; unlinked new-room drafts stay discoverable, offer Locate and only uniquely safe Reconnect, and cannot be reverted while incoming links remain. Focused verification: `scripts/test.sh -a res://test/scenes/studio_rooms_test.gd` (25/25) and `scripts/test.sh -a res://test/core/studio/studio_people_index_test.gd` (4/4); scoped GDScript lint passes.
- [x] P05 — In-game dialogue/quest jumps, Back to person and structured entrance problems. Person references read current quest/talk drafts and retain quest/step IDs; return resolves authored placements afresh. Header Undo/Redo follows the active document. Missing/unreadable dialogue is disabled; entrance problems locate their exact source and share link-state codes with Publish. Focused People acceptance: 18/18; doors/index/mode/quests: 49/49 in the earlier affected run. EN/JA native views, including 1280×720 problem navigation, reviewed in `shots/studio-p05/`. See README for commands, initial test-fixture correction and limits.
- [x] P06 — People & Doors acceptance, regression and native screenshot evidence. Mounted delivery A verifies fixture Publish plus empty-draft reload, with a second linked-building slide/resize/return case. Effective targeted coverage: 120 distinct cases/10 suites across named runs; three Rooms runtime errors were corrected and its 25 cases pass in the final rerun. Native placed/unplaced People, link/facing, furnished return and 1280×720 Japanese views reviewed. Exact commands, prior failures, aggregate accounting and session-local geometry history limit: `shots/studio-p06/evidence.txt`.
- [x] B01 — Shared scoped construction catalog, two rows and explicit classification. Build is enabled with Buildings, Boundaries, Gates and Floors & furniture over canonical entries; independent search/scroll, scoped Recent/On this map and a separate Paint floor action into Land. Metadata fixture/classifier 3/3, mounted Build 7/7, existing filter/catalog panels 45/45 across named runs (55 distinct cases). EN/JA native two-row views reviewed. Logs in `shots/studio-b01/`; README records commands, corrected fixture assumptions and limits.
- [ ] B02 — Legacy building placement/sizing, door/return link preservation and baseline metadata.
- [ ] B03 — Boundary/gate preview, connection topology, replacement and protected things.
- [ ] B04 — Room navigation, furniture/floor controls and protected exit/arrival.
- [ ] B05 — Shared map controls, safety guard before W03, focus/hints/localization.
- [ ] B06 — Build acceptance with current assets and isolated Publish/reload.
- [ ] M01 — Proposed ADR, optional schemas, IDs/ownership and shared world transactions.
- [ ] M02 — Deterministic exterior/roof compiler, runtime renderer and collision/fallbacks.
- [ ] M03 — Draw shell, edit dimensions/materials, fresh-ID copy and dedicated ghost.
- [ ] M04 — Owned interior projection, floor payload, exit and paired owner link.
- [ ] M05 — Partitions/openings/floors, reachability, synchronized resize and detach.
- [ ] M06 — Complete fitted first wall/roof pack and source/provenance.
- [ ] M07 — Whole-world Publish checks, backward compatibility and transaction recovery.
- [ ] M08 — Modular acceptance matrix, native art review and performance evidence.
- [ ] W01 — Reference index, places/schedules adapters and coordinated world-document history.
- [ ] W02 — Outdoor-area dialog, unique map ID, draft/restart and safe Revert.
- [ ] W03 — All-edge safe resizing, reference transforms and saved-coordinate revisions.
- [ ] W04 — Paired routes, departure/arrival validation and one-action edits/removal.
- [ ] W05 — District authoring, nonoverlap, runtime labels and document persistence.
- [ ] W06 — Full-world validation, grouped Publish/conflicts/recovery and existing-save compatibility.
- [ ] W07 — New-area story, old-save migration, published reload and evidence.

## 3. Acceptance walkthroughs

These are exact author-facing scenarios, not replacements for the individual specifications' negative cases.
Prepare isolated fixture content/drafts/saves. Do not permanently edit the player's actual town for acceptance.

### A. People and a door

1. Open F2 → People & Doors. Find one static NPC card; Locate centers their existing placement.
2. Place them elsewhere on the same map facing left. Confirm one placement. Undo and redo once.
3. Move to an existing second map; Place here; cancel the move confirmation. Confirm both maps unchanged.
4. Repeat and accept. Confirm both maps update; undo restores source exactly. Restart and check draft consistency.
5. On the exterior choose an unlinked building → Make interior → Open room. Confirm picker and source target.
6. Set a valid custom target and facing; try a water/blocked/transition cell and verify rejection.
7. Cancel linking after switching target maps; confirm source map and selection restore without an accidental edit.
8. Play draft, enter room and leave. No bounce, blocked landing or wrong-facing arrival.
9. Edit selected NPC's talk through Quests, then return. Confirm correct NPC and correct undo owner.
10. Publish to the fixture and reload without drafts. Record files and actual result, not just a success toast.

### B. Build with existing assets

1. Open Build; verify two complete rows and independent Objects/Build searches.
2. Place/resize an existing cottage. Check door position, masks and source art unchanged.
3. Draw two joined fence strokes; make a corner/tee; insert matching gate on a straight segment.
4. Try insertion at a junction and over a programmed object; verify it refuses without deleting anything.
5. Make/open room, paint floor, place a table/chair/rug; attempts to block the exit must be clear and safe.
6. Move cottage and slide door; return target follows. Undo/redo across map navigation restores both sides.
7. Play draft and walk both ways; gate still behaves as its existing definition specifies.
8. Restart, then isolated Publish/reload. Recheck Objects and Land, including meadow/path joins.

### C. Modular cottage with two connected rooms

1. Build → Draw building; drag 8×6 and choose cream timber/warm shingles. Move door to x=3.
2. Cancel once; confirm no object/history/file created. Draw again and Apply.
3. Reveal roof: inspect perimeter, south facade and door. Show roof: inspect all edges and ridge.
4. Switch to 9×7, then 8×6; no stretched detail, missing ridge row or drift. Undo restores exact data.
5. Make managed interior. Confirm its size 10×9, arrival `[4,7]`, exit `[4,8]` and owner ID.
6. Draw a vertical partition at local x=4 from y=0..5, with a doorway at local `[4,3]` in the same pending plan.
   Preview must reject sealing the room without that opening; Apply with opening must allow both sides.
7. Paint floors and furnish both sides while keeping arrival free. Play draft and walk through internal doorway.
8. Enlarge shell; furniture/paint/partition stay anchored; exit moves consistently. Try shrinking across furniture
   and a quest pin; verify blocked impact preview and no silent deletion. Undo/redo across owner/room.
9. Restart; publish to fixture; reload without drafts. Check exterior/interior collision and materials.
10. Duplicate shell: fresh ID, no shared owned room. Detach original interior: contents/link remain, future shell
    changes no longer overwrite it. Undo detach restores coordinated ownership.
11. Inject a failed second-document apply/write; confirm no half owner/room update survives or publishes.

### D. Add East Meadow and expand town

1. Areas → New outdoor area → name East Meadow, ID `east-meadow`, 40×30, meadow, start `[2,2]`.
   Choose a whole-map place. Create; confirm draft only and new map in picker.
2. Paint a dirt route and a water patch. Existing coordinate-based terrain variants remain stable on reload.
3. Add paired route between town and meadow with separate departure/arrival cells on each side. Walk both ways
   in Play draft. Neither side immediately triggers return; correct facing is used.
4. Add a nonoverlapping district rectangle. Attempt an overlap and verify a clear rejection, preserving both places.
5. Grow town north by 4 and west by 6. Review every affected door, start, NPC, schedule anchor, district, pin and
   managed-room return. Apply once, undo once, redo once; verify each coordinate shifted exactly once.
6. Attempt shrink through a scheduled NPC, owner room entrance and pin; verify blocked impact list. Cancel it.
7. Restart; verify draft ledger/references. Publish to isolated content; reload with no draft overlay.
8. Load a pre-expansion character save. Position follows transforms once; inventory/flags/tasks unchanged. Load
   it again after save; no second shift. Current-revision save remains unchanged.
9. Simulate a canonical write failure after the first file replacement; recover whole group. Source conflicts in
   places/schedules/ledger must stop publish even if map source did not change.
10. Revert a separate unpublished connected area and verify dependency handling leaves no dangling route halves.

## 4. Shared regression checks

- [ ] Objects/Land/Quests behavior, editing pause and Play/F1/F2 still correct.
- [ ] 300px shelf/two rows, scrolling, narrow windows and English/Japanese fit.
- [ ] One input owner; hidden shelf clicks never place; focused text does not nudge/delete/rotate world objects.
- [ ] Draft recovery, coordinated undo/redo, source hash conflicts, Publish backups and Revert checked.
- [ ] Old unmodified maps, legacy sprites, ordinary rooms and missing-art fallbacks remain readable/playable.
- [ ] Learning tasks/quest progress, Shardrun and Spellforge not affected by unrelated refactors.
- [ ] Known pre-existing warning/failures recorded separately; no unexplained “all green” claim.
- [ ] Evidence file list, exact commands/results, screenshots and next packet documented.

## 5. Ready-to-use kickoff prompt for Luna

```text
Implement Rootward Studio v0.35 from Concept/v0.35/README.md.

Read AGENT.md, CLAUDE.md, WIP.md, docs/PLAN.md, the v0.35 execution guide and relevant ADRs first.
Respect the existing dirty working tree. Do not commit unless I ask.

Start with the first unchecked packet in Concept/v0.35/05-delivery-checklist.md (currently B02).
Read the entire corresponding spec and the existing implementation before editing. Reuse current
StudioWork, StudioDoors, StudioLink, catalog, draft and Publish paths. Proposed NEW APIs in the spec
must actually be implemented; do not call them as if they already exist.

Work through one bounded packet at a time, leaving the game launchable. Complete its input, model,
UI, history, draft/reload and failure paths before marking it done. Follow the implementing session's
test instructions; provide exact evidence and native screenshots for visible work. No placeholder
buttons, invented successful test results or silent loss of furniture/references.

Keep People/Build/Land in the same lower workspace with two asset rows. Modular v1 means rectangular
single-story shells, fitted wall/roof modules and managed partitioned interiors. New areas/map growth
are step 4, with reference safety and old-save coordinate handling. Do not skip them by treating
the current resize dialog as the whole feature.

At each handoff update the checklist, PLAN and uncommitted WIP with actual completion status,
changed files, evidence, failures and the next concrete action. Continue in dependency order.
```

To resume later, read the checklist and begin with its first genuinely unfinished packet. If a checked item lacks
evidence, inspect the implementation and mark it incomplete until its acceptance gap is resolved.
