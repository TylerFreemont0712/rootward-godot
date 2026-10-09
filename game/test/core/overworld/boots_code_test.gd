extends GdUnitTestSuite
## Blocks as code (ADR-0061): each rule an `if` on the key, each change a `+=` or `-=`, the same in both languages, and
## an empty set of blocks still a function that loads.


func test_blocks_become_python() -> void:
	var blocks := [BootsCode.rule("right", "x", 1), {"key": "up", "do": [{"change": "y", "by": -1}]}]
	var expected := (
		'def on_key(key, player):\n    if key == "right":\n        player.x += 1\n'
		+ '    if key == "up":\n        player.y -= 1\n'
	)
	assert_str(BootsCode.source(blocks, "python")).is_equal(expected)


func test_blocks_become_javascript() -> void:
	var blocks := [BootsCode.rule("left", "x", -2)]
	assert_str(BootsCode.source(blocks, "javascript")).is_equal(
		'function onKey(key, player) {\n  if (key === "left") {\n    player.x -= 2;\n  }\n}\n'
	)


func test_no_blocks_is_still_a_function() -> void:
	assert_str(BootsCode.source([], "python")).is_equal("def on_key(key, player):\n    pass\n")
	assert_str(BootsCode.source([], "javascript")).is_equal("function onKey(key, player) {\n}\n")


func test_a_rule_with_an_unknown_key_or_no_change_is_left_out() -> void:
	var blocks := [{"key": "jump", "do": [{"change": "x", "by": 1}]}, BootsCode.rule("down", "y", 0)]
	assert_str(BootsCode.source(blocks, "python")).is_equal("def on_key(key, player):\n    pass\n")


func test_the_starter_names_the_function_and_moves_nothing() -> void:
	assert_str(BootsCode.starter("python")).contains("def on_key(key, player):").not_contains("+=")
	assert_str(BootsCode.starter("javascript")).contains("function onKey(key, player)").not_contains("+=")
