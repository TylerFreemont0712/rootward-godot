extends GdUnitTestSuite
## The bag task (Concept/v0.4/01, 5.6) holds everything a task must (TaskCheck): its reference passes both stages, its
## starter and its Builder's start do not, each block answer passes its stage, and no text gives the answer away.


func test_the_bag_task_holds_together() -> void:
	var found := TaskCheck.problems("bag")
	assert_array(found).override_failure_message("\n".join(found)).is_empty()
