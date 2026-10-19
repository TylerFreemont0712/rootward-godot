class_name GlowJudges
extends RefCounted
## The judge of Hotaru's glow(t) (task glow: Concept/v0.4/05, 2.2): glow_pattern. It takes the whole stage's cases and
## results and gives one verdict per case ({ok, reason, ...details}); TaskJudges.judge sends the name "glow_pattern" here.
##
## Every answer must be a number from 0.0 (dark) to 1.0 (bright), and the glow must blink: one answer at or below
## LOW_LEVEL (dim) and one at or above HIGH_LEVEL (bright). A case whose call failed is judged by Tasks, so it is skipped.

## A brightness at or below LOW_LEVEL is dim; at or above HIGH_LEVEL it is bright.
const LOW_LEVEL := 0.3
const HIGH_LEVEL := 0.7


## Reasons: "not-number" (got) on the first answer that is not a number; "out" (got) on each number below 0.0 or above
## 1.0; "no-blink" (got) on the first case, when no answer is dim or none is bright. A case gets one verdict, the first
## that holds, so the first case keeps a reason it already has.
static func glow_pattern(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var first_not_number := -1
	var dim := false
	var bright := false
	for i in cases.size():
		out.append(TaskJudges.right())
		if not _answered(results, i):
			continue
		var got: Variant = TaskJudges.value_of(results, i)
		if not Tasks.is_number(got):
			if first_not_number < 0:
				first_not_number = i
			continue
		var brightness := float(got)
		if brightness < -Tasks.TOLERANCE or brightness > 1.0 + Tasks.TOLERANCE:
			out[i] = {"ok": false, "reason": "out", "got": got}
		dim = dim or brightness <= LOW_LEVEL + Tasks.TOLERANCE
		bright = bright or brightness >= HIGH_LEVEL - Tasks.TOLERANCE
	if first_not_number >= 0:
		out[first_not_number] = {"ok": false, "reason": "not-number", "got": TaskJudges.value_of(results, first_not_number)}
	if not cases.is_empty() and not (dim and bright) and bool((out[0] as Dictionary).get("ok", false)):
		out[0] = {"ok": false, "reason": "no-blink", "got": TaskJudges.value_of(results, 0)}
	return out


## Whether result `i` is an answer: its call did not fail.
static func _answered(results: Array, i: int) -> bool:
	return i < results.size() and results[i] is Dictionary and bool((results[i] as Dictionary).get("ok", false))
