extends GdUnitTestSuite
## The menu task (Concept/v0.4/01, 5.2) holds everything a task must (TaskCheck): its reference passes, its
## starter and its Builder's start do not, each block answer passes its stage, and no text gives the answer away.


func test_the_menu_task_holds_together() -> void:
	var found := TaskCheck.problems("menu")
	assert_array(found).override_failure_message("\n".join(found)).is_empty()
