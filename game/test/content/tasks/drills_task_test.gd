extends GdUnitTestSuite
## The drills task (Concept/v0.4/05, 2.3) holds everything a task must (TaskCheck): its reference passes all three stages,
## its starter and its Builder's start do not, each block answer passes its stage, and no text gives the answer away.


func test_the_drills_task_holds_together() -> void:
	var found := TaskCheck.problems("drills")
	assert_array(found).override_failure_message("\n".join(found)).is_empty()
