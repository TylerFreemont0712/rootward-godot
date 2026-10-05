# ADR-0054: Keep scheduler-rest provenance on Program bolts

Accepted 2026-10-06.

## Context

`Task Scheduler` inserts a low-power spacer when no element can meet its one-step cooldown. A later card can turn those rests into block, but power and element cannot reliably identify a rest: ordinary cards can create identical neutral bolts.

## Decision

- Add an optional `idle` boolean to Program bolt data and carry it through schema validation, normalization, and the C++ bridge.
- Only `Task Scheduler` marks inserted spacers with `idle`.
- `Handoff Ward` checks the explicit marker and clears it whether or not that spacer fits its block cap.
- Do not infer scheduler provenance from a bolt's power, element, or position.

## Consequences

This lets a general card cooperate with the scheduler without changing ordinary attacks that happen to resemble a spacer. The marker is transient Program metadata, not a combat status or saved run resource. New transformations should preserve metadata when copying bolts, while cards that consume a marker should remove it deliberately.
