extends GdUnitTestSuite
## The boots editor's unrun work (ADR-0061): the draft is read before the program, programs compare by what they say,
## and code nobody typed (the blocks' code, the starter) never counts as typed or turns the blocks into code.

const RIGHT := {"key": "right", "do": [{"change": "x", "by": 1}]}


func _program(mode: String, blocks: Array, code: Dictionary = {}) -> Dictionary:
	return {"mode": mode, "blocks": blocks, "code": code}


func test_the_draft_is_read_before_the_program_and_as_a_copy() -> void:
	var boots := _program("blocks", [RIGHT])
	boots.draft = _program("code", [], {"python": "def on_key(key, player):\n    player.y += 1\n"})
	var read := BootsDraft.of(boots)
	assert_str(read.mode).is_equal("code")
	(read.code as Dictionary).python = "changed"
	assert_str(String(boots.draft.code.python)).contains("player.y += 1")
	assert_str(BootsDraft.of(_program("blocks", [RIGHT])).mode).is_equal("blocks")


func test_programs_compare_by_what_they_say() -> void:
	var saved := _program("blocks", [{"key": "right", "do": [{"change": "x", "by": 1.0}]}])
	assert_bool(BootsDraft.same(_program("blocks", [RIGHT]), saved)).is_true()
	var starter := {"python": BootsCode.starter("python")}
	assert_bool(BootsDraft.same(_program("code", [], starter), _program("code", []))).is_true()
	assert_bool(BootsDraft.same(_program("blocks", [RIGHT]), _program("blocks", []))).is_false()
	assert_bool(BootsDraft.same(_program("code", [RIGHT]), _program("blocks", [RIGHT]))).is_false()


func test_code_nobody_typed_is_not_kept_as_typed() -> void:
	var blocks := [RIGHT]
	assert_str(BootsDraft.typed(BootsCode.starter("python"), blocks, "python")).is_empty()
	assert_str(BootsDraft.typed(BootsCode.source(blocks, "javascript") + "\n", blocks, "javascript")).is_empty()
	assert_str(BootsDraft.typed("   ", blocks, "python")).is_empty()
	var mine := "def on_key(key, player):\n    player.x -= 1\n"
	assert_str(BootsDraft.typed(mine, blocks, "python")).is_equal(mine)


func test_the_code_tab_counts_only_once_something_is_typed() -> void:
	assert_str(BootsDraft.mode_of("code", {"python": "def on_key(key, player):\n    pass\n"}, "python")).is_equal(
		"code"
	)
	assert_str(BootsDraft.mode_of("code", {"python": ""}, "python")).is_equal("blocks")
	assert_str(BootsDraft.mode_of("code", {"python": "x = 1"}, "javascript")).is_equal("blocks")
	assert_str(BootsDraft.mode_of("blocks", {"python": "x = 1"}, "python")).is_equal("blocks")


func test_a_broken_program_reads_as_empty_rather_than_failing() -> void:
	var read := BootsDraft.program_of({"mode": "code", "blocks": "broken", "code": 3})
	assert_array(read.blocks).is_empty()
	assert_dict(read.code).is_empty()
	assert_array(BootsDraft.plain_blocks([RIGHT, "nonsense"])).has_size(1)
