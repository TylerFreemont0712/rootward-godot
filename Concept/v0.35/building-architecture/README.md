# Lanternroot building architecture

The selected camera is panel 4, the lower-right image in [`home-angle-study.png`](home-angle-study.png), refined in
[`home-front-plane-v4.png`](concepts/home-front-plane-v4.png). It keeps the front facade broad and nearly flat, turns it
slightly toward the camera, and lets the roof recede toward the back. No building shows a side wall. The shared frame,
palette, building roster, tile sizes, and door coordinates are in
[`BUILDING_ART_SPEC.md`](BUILDING_ART_SPEC.md).

ChatGPT ImageGen sources are preserved in [`imagegen-candidates/`](imagegen-candidates/), and the cut pipeline writes
active sprites to `game/assets/overworld/world/`. The placed town buildings now use the selected architecture style;
the builder catalog gains six service/weathered options and eight distinct fantasy designs. The observatory's star
chamber grows from the roof ridge, so the upper tower and gable read as one silhouette.

The gallery beside the person-scale reviews is [`expansion-imagegen.png`](../../../shots/studio/expansion-imagegen.png).
Individual fit and door checks are in `Concept/v0.3/world/`. Earlier rejected ComfyUI candidates and angle studies stay
in this concept folder for comparison; they are not used for the active cut.
