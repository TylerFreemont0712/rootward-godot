class_name CodeDiff
extends RefCounted
## A line diff of two versions of a card's code (ADR-0018): what a refactor at the forge removes and adds, the way `git
## diff` shows it. The longest common subsequence of lines is kept; everything else is a removal or an addition.
##
##   CodeDiff.lines("a\nb\n", "a\nc\n")   # [{kind: "same", text: "a"}, {kind: "removed", text: "b"},
##                                        #  {kind: "added", text: "c"}]


static func lines(before: String, after: String) -> Array[Dictionary]:
	var was := before.strip_edges(false, true).split("\n")
	var now := after.strip_edges(false, true).split("\n")
	# LEARN: longest[i][j] is the length of the longest common subsequence of was[i..] and now[j..]; filling it from
	# the ends lets a walk from the front pick "same" whenever the lines match and the cheaper side otherwise.
	var longest: Array[PackedInt32Array] = []
	for i in was.size() + 1:
		var row := PackedInt32Array()
		row.resize(now.size() + 1)
		longest.append(row)
	for i in range(was.size() - 1, -1, -1):
		for j in range(now.size() - 1, -1, -1):
			if was[i] == now[j]:
				longest[i][j] = longest[i + 1][j + 1] + 1
			else:
				longest[i][j] = maxi(longest[i + 1][j], longest[i][j + 1])
	var out: Array[Dictionary] = []
	var i := 0
	var j := 0
	while i < was.size() and j < now.size():
		if was[i] == now[j]:
			out.append({"kind": "same", "text": was[i]})
			i += 1
			j += 1
		elif longest[i + 1][j] >= longest[i][j + 1]:
			out.append({"kind": "removed", "text": was[i]})
			i += 1
		else:
			out.append({"kind": "added", "text": now[j]})
			j += 1
	while i < was.size():
		out.append({"kind": "removed", "text": was[i]})
		i += 1
	while j < now.size():
		out.append({"kind": "added", "text": now[j]})
		j += 1
	return out


## How many lines a diff changes: {removed, added}.
static func changes(diff: Array[Dictionary]) -> Dictionary:
	var removed := diff.filter(func(line: Dictionary) -> bool: return line.kind == "removed").size()
	var added := diff.filter(func(line: Dictionary) -> bool: return line.kind == "added").size()
	return {"removed": removed, "added": added}
