# Card faces · v0.2

Open [index.html](index.html) in a browser to compare four card-face layouts. All four use the same real card and icon:
`import copy` (`IMPORT`, `O(1)`, a before-`STRIKE` hook).

| Concept | Footprint | Layout |
|---|---:|---|
| A · Console | 164 × 232 | Portrait; name, image, separate role/hook and complexity bands |
| B · Big-O first | 184 × 258 | Larger portrait; complexity is the main read |
| C · Terminal tile | 152 × 216 | Compact portrait; simplified copy, strong typographic labels |
| D · Wide cartridge | 224 × 184 | Landscape; a bounded image column beside the metadata |

These are visual proposals only. `object-fit: contain` and a fixed, clipped image viewport keep even edge-filling generated
art inside the card. Role and complexity have different labels and color treatments. The compact options omit the sentence
summary; the existing card detail can continue to carry the full summary and code on hover.

No live card UI or production assets are changed by this concept folder.
