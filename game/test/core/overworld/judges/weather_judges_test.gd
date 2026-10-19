extends GdUnitTestSuite
## Fern's weather_week and Hollis's hours judges (Concept/v0.4/05, 2.7 and 2.8): each reason they give, and the answers
## that pass.


## The 28 days of the weather table, each a case with its words.
func day_cases() -> Array:
	var cases: Array = []
	for day in range(28):
		cases.append({"args": [day], "say": "day %d" % day})
	return cases


## One result per answer, the way a run gives them (ok, with its value).
func answers(values: Array) -> Array:
	var results: Array = []
	for value: Variant in values:
		results.append({"ok": true, "value": value})
	return results


## The same answer on every one of the 28 days.
func same_days(answer: String) -> Array:
	var values: Array = []
	for _day in range(28):
		values.append(answer)
	return values


## Rain on every 4th day, cloud on the days 2 past those, sun otherwise: every week of 7 holds rain and sun.
func reference_days() -> Array:
	var values: Array = []
	for day in range(28):
		if day % 4 == 0:
			values.append("rain")
		elif day % 4 == 2:
			values.append("cloud")
		else:
			values.append("sun")
	return values


## The people and hours of the hours task: for each of two people, hours 3, 10, 20 (wanted) and 7, 23 (any spot).
func hours_cases() -> Array:
	var cases: Array = []
	for person: String in ["innkeeper", "pip"]:
		cases.append({"args": [person, 3], "want": "home", "say": "%s at hour 3" % person})
		cases.append({"args": [person, 10], "want": "work", "say": "%s at hour 10" % person})
		cases.append({"args": [person, 20], "want": "inn", "say": "%s at hour 20" % person})
		cases.append({"args": [person, 7], "say": "%s at hour 7" % person})
		cases.append({"args": [person, 23], "say": "%s at hour 23" % person})
	return cases


func reason_at(verdicts: Array, index: int) -> String:
	return String((verdicts[index] as Dictionary).get("reason", ""))


func detail_at(verdicts: Array, index: int, key: String) -> Variant:
	return (verdicts[index] as Dictionary).get(key)


func is_right_at(verdicts: Array, index: int) -> bool:
	return bool((verdicts[index] as Dictionary).get("ok", false))


func all_right(verdicts: Array) -> bool:
	for verdict: Variant in verdicts:
		if not bool((verdict as Dictionary).get("ok", false)):
			return false
	return true


# --- weather_week ---------------------------------------------------------------------------------------------------


func test_weather_week_passes_a_pattern_with_rain_and_sun_in_every_week() -> void:
	assert_bool(all_right(WeatherJudges.weather_week(day_cases(), answers(reference_days())))).is_true()
	# Rain on every 7th day and sun on the rest passes too: each week of 7 holds one rain day.
	var weekly: Array = []
	for day in range(28):
		weekly.append("rain" if day % 7 == 0 else "sun")
	assert_bool(all_right(WeatherJudges.weather_week(day_cases(), answers(weekly)))).is_true()


func test_weather_week_gives_not_weather_for_an_answer_that_is_not_one_of_the_three() -> void:
	var values: Array = reference_days()
	values[5] = "Rain"
	values[9] = null
	var verdicts := WeatherJudges.weather_week(day_cases(), answers(values))
	assert_str(reason_at(verdicts, 5)).is_equal("not-weather")
	assert_str(String(detail_at(verdicts, 5, "got"))).is_equal("Rain")
	assert_str(reason_at(verdicts, 9)).is_equal("not-weather")
	assert_bool(detail_at(verdicts, 9, "got") == null).is_true()
	# The other days are fine: the weeks that hold day 5 or day 9 wait until those days are weather.
	for index in range(28):
		if index != 5 and index != 9:
			assert_bool(is_right_at(verdicts, index)).override_failure_message("day %d should be right" % index).is_true()


func test_weather_week_gives_no_rain_on_the_first_day_of_a_week_without_rain() -> void:
	var verdicts := WeatherJudges.weather_week(day_cases(), answers(same_days("sun")))
	# The weeks are 0 to 6, 1 to 7 and so on up to 21 to 27. Each starts with a day that gives the verdict, and names its week.
	assert_str(reason_at(verdicts, 0)).is_equal("no-rain")
	assert_str(String(detail_at(verdicts, 0, "name"))).is_equal("0–6")
	assert_str(reason_at(verdicts, 1)).is_equal("no-rain")
	assert_str(reason_at(verdicts, 21)).is_equal("no-rain")
	assert_str(String(detail_at(verdicts, 21, "name"))).is_equal("21–27")
	# Day 22 starts no week of 7 days inside 0 to 27, so it is right.
	assert_bool(is_right_at(verdicts, 22)).is_true()


func test_weather_week_gives_no_sun_on_the_first_day_of_a_week_without_sun() -> void:
	var verdicts := WeatherJudges.weather_week(day_cases(), answers(same_days("rain")))
	assert_str(reason_at(verdicts, 0)).is_equal("no-sun")
	assert_str(String(detail_at(verdicts, 0, "name"))).is_equal("0–6")
	# Rain every 4th day and cloud on the rest: every week has rain, and none has sun.
	var rain_cloud: Array = []
	for day in range(28):
		rain_cloud.append("rain" if day % 4 == 0 else "cloud")
	var no_sun := WeatherJudges.weather_week(day_cases(), answers(rain_cloud))
	assert_str(reason_at(no_sun, 0)).is_equal("no-sun")
	assert_str(reason_at(no_sun, 21)).is_equal("no-sun")


func test_weather_week_says_no_rain_before_no_sun_when_a_week_has_neither() -> void:
	var verdicts := WeatherJudges.weather_week(day_cases(), answers(same_days("cloud")))
	assert_str(reason_at(verdicts, 0)).is_equal("no-rain")


func test_weather_week_leaves_the_weeks_with_a_day_that_is_not_weather_for_later() -> void:
	var values: Array = same_days("sun")
	values[3] = null
	var verdicts := WeatherJudges.weather_week(day_cases(), answers(values))
	# Day 3 is not weather. The weeks that hold it (those starting at 0 to 3) are not judged yet.
	assert_bool(is_right_at(verdicts, 0)).is_true()
	assert_str(reason_at(verdicts, 3)).is_equal("not-weather")
	# The week from day 4 to day 10 holds no rain: the verdict is on day 4.
	assert_str(reason_at(verdicts, 4)).is_equal("no-rain")


# --- hours ----------------------------------------------------------------------------------------------------------


func test_hours_passes_the_right_spots_and_any_spot_at_hours_7_and_23() -> void:
	# Innkeeper: 3 home, 10 work, 20 inn, and 7 and 23 are any spot. Pip's hours are the same, with 7 and 23 any spot too.
	var values := ["home", "work", "inn", "inn", "home", "home", "work", "inn", "work", "home"]
	assert_bool(all_right(WeatherJudges.hours(hours_cases(), answers(values)))).is_true()


func test_hours_gives_not_spot_for_an_answer_that_is_not_home_work_or_inn() -> void:
	var values := ["home", "work", "inn", "inn", "home", "Home", "work", "inn", null, "home"]
	var verdicts := WeatherJudges.hours(hours_cases(), answers(values))
	assert_str(reason_at(verdicts, 5)).is_equal("not-spot")
	assert_str(String(detail_at(verdicts, 5, "got"))).is_equal("Home")
	# A case with no wanted spot (hour 7 for pip) still has to give a spot.
	assert_str(reason_at(verdicts, 8)).is_equal("not-spot")
	assert_bool(detail_at(verdicts, 8, "got") == null).is_true()


func test_hours_gives_wrong_for_a_wanted_spot_that_is_not_given() -> void:
	var values := ["work", "work", "inn", "inn", "home", "home", "work", "home", "work", "home"]
	var verdicts := WeatherJudges.hours(hours_cases(), answers(values))
	assert_str(reason_at(verdicts, 0)).is_equal("wrong")
	assert_str(String(detail_at(verdicts, 0, "want"))).is_equal("home")
	assert_str(String(detail_at(verdicts, 0, "got"))).is_equal("work")
	# Pip at hour 20 gives home, and should give inn.
	assert_str(reason_at(verdicts, 7)).is_equal("wrong")
	assert_str(String(detail_at(verdicts, 7, "want"))).is_equal("inn")
	for index: int in [1, 2, 3, 4, 5, 6, 8, 9]:
		assert_bool(is_right_at(verdicts, index)).override_failure_message("case %d should be right" % index).is_true()
