extends GdUnitTestSuite
## The io grader against the old runners: the same submissions pass and fail the same cases, with the same output
## (fixture from tools/fixtures/challenges.ts).


func test_grades_match_the_old_runners() -> void:
	var fixture: Dictionary = Fixtures.load_json_gz("challenges")
	for challenge: Dictionary in fixture.challenges:
		for attempt: Dictionary in challenge.attempts:
			var files: Dictionary[String, String] = {}
			for path: String in attempt.files:
				files[path] = attempt.files[path]
			var results := IoGrader.grade(attempt.language, files, attempt.entry, challenge.cases, challenge.normalize)
			assert_int(results.size()).is_equal((attempt.tests as Array).size())
			for i in results.size():
				var want: Dictionary = attempt.tests[i]
				var got := results[i]
				var where := "%s %s %s %s" % [challenge.id, attempt.language, attempt.submission, want.id]
				assert_bool(got.passed).override_failure_message(where + " " + str(got)).is_equal(want.passed)
				assert_str(got.status).override_failure_message(where).is_equal(want.status)
				# Past the output cap the two runners cut the text at slightly different points (characters or bytes);
				# only the verdict matters there.
				if not (got.message as String).contains("printed more than"):
					assert_bool(got.actual == want.actual).override_failure_message(where + ": actual").is_true()
				assert_str(got.expected).override_failure_message(where).is_equal(want.expected)


func test_normalize() -> void:
	assert_str(IoGrader.normalize("a  \r\nb\t\n\n\n", true, true)).is_equal("a\nb")
	assert_str(IoGrader.normalize("a \n", false, true)).is_equal("a \n")
	assert_str(IoGrader.normalize("a\r\n", false, false)).is_equal("a\r\n")
