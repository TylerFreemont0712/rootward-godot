extends GdUnitTestSuite
## Talking with the townspeople (ADR-0061): the opening picked by what the town remembers, choices shown only when
## their condition holds, flags set by reaching a node, and a broken talk found before anyone plays it.

const TALK := {
	"id": "innkeeper",
	"start": [{"if": {"flag": "met-marta"}, "goto": "again"}, {"goto": "hello"}],
	"nodes":
	{
		"hello":
		{
			"lines": [{"text": "Welcome!", "mood": "happy"}, {"text": "Mind the stew.", "speaker": "hotaru"}],
			"choices": [{"text": "Any news?", "goto": "news"}, {"text": "Secret", "goto": "news", "if": {"flag": "x"}}],
			"set": ["met-marta"],
		},
		"news": {"lines": [{"text": "Pell went to the Foundry."}], "next": ""},
		"again": {"lines": [{"text": "Back again?"}]},
	},
}


func test_the_opening_follows_what_the_town_remembers() -> void:
	assert_str(Talk.opening(TALK, {})).is_equal("hello")
	assert_str(Talk.opening(TALK, {"met-marta": true})).is_equal("again")


func test_lines_carry_their_speaker_and_mood() -> void:
	var lines := Talk.lines(TALK, "hello")
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0].mood).is_equal("happy")
	assert_str(lines[1].speaker).is_equal("hotaru")


func test_a_choice_shows_only_when_its_condition_holds() -> void:
	assert_int(Talk.choices(TALK, "hello", {}).size()).is_equal(1)
	assert_int(Talk.choices(TALK, "hello", {"x": true}).size()).is_equal(2)


func test_reaching_a_node_sets_its_flags() -> void:
	assert_dict(Talk.remember(TALK, "hello", {})).contains_key_value("met-marta", true)


func test_conditions_combine() -> void:
	assert_bool(Talk.holds({"all": [{"flag": "a"}, {"not": "b"}]}, {"a": true})).is_true()
	assert_bool(Talk.holds({"all": [{"flag": "a"}, {"not": "b"}]}, {"a": true, "b": true})).is_false()


func test_a_good_talk_has_no_problems_and_a_broken_one_is_found() -> void:
	assert_array(Talk.problems(TALK)).is_empty()
	var broken := TALK.duplicate(true)
	broken.nodes.hello.choices[0].goto = "nowhere"
	broken.nodes["lonely"] = {"lines": [{"text": "..."}]}
	var found := Talk.problems(broken)
	assert_array(found).contains(["hello leads to nowhere, which is not a node", "nothing leads to lonely"])
