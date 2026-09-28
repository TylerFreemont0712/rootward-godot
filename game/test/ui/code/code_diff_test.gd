extends GdUnitTestSuite
## The forge's diff (ADR-0018): what a refactor removes and adds, line by line.


func _kinds(diff: Array[Dictionary]) -> Array:
	return diff.map(func(line: Dictionary) -> String: return "%s %s" % [line.kind, line.text])


func test_a_changed_line_is_one_removed_and_one_added() -> void:
	var diff := CodeDiff.lines("def f(x):\n    return x + 3\n", "def f(x):\n    return x + 4\n")
	assert_array(_kinds(diff)).is_equal(["same def f(x):", "removed     return x + 3", "added     return x + 4"])
	assert_dict(CodeDiff.changes(diff)).is_equal({"removed": 1, "added": 1})


func test_lines_added_in_the_middle_keep_the_rest_in_place() -> void:
	var diff := CodeDiff.lines("a\nb\nc", "a\nb\nx\ny\nc")
	assert_array(_kinds(diff)).is_equal(["same a", "same b", "added x", "added y", "same c"])


func test_the_same_code_has_no_changes() -> void:
	assert_dict(CodeDiff.changes(CodeDiff.lines("a\nb\n", "a\nb"))).is_equal({"removed": 0, "added": 0})
