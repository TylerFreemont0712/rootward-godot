class_name CharacterCard
extends RefCounted
## What the character screen and a character's progress say about a saved character (ADR-0061), as words: the name,
## "Tinker · Python · Builder", when they last played and for how long. Pure helpers over a saved state; the screen's
## look is CharacterSelect and its lineup (CharacterSelectLineup).


## A character's name as the town knows it; "Tinker" before they chose one.
static func name_of(saved: Dictionary) -> String:
	var chosen := String(saved.get("name", "")).strip_edges()
	return chosen if chosen != "" else Text.t("Tinker")


## "Tinker · Python · Builder": the class, the boots' language and how they build.
static func class_line(saved: Dictionary) -> String:
	var boots: Dictionary = saved.get("boots", {}) if saved.get("boots", {}) is Dictionary else {}
	var language := BootsCodePanel.language_name(String(saved.get("language", BootsCode.PYTHON)))
	return (
		"%s · %s · %s"
		% [
			class_name_of(saved),
			language,
			style_name(String(boots.get("style", OverworldState.BUILDER)))
		]
	)


## "Python · Builder · 1 h 20 min": the character screen's one line (v0.4: no class, no counts), the boots' language,
## how they build and the time they have played.
static func detail_line(saved: Dictionary) -> String:
	var boots: Dictionary = saved.get("boots", {}) if saved.get("boots", {}) is Dictionary else {}
	var language := BootsCodePanel.language_name(String(saved.get("language", BootsCode.PYTHON)))
	var style := style_name(String(boots.get("style", OverworldState.BUILDER)))
	return "%s · %s · %s" % [language, style, played_for(saved)]


## The character's class. Every character is a Tinker for now; disciplines come later, as the Shardrun's classes did.
static func class_name_of(_saved: Dictionary) -> String:
	return Text.t("Tinker")


static func style_name(style: String) -> String:
	return Text.t("Scribe") if style == OverworldState.SCRIBE else Text.t("Builder")


## When they last played, in a child's words: today, yesterday, three days ago, or the date.
static func last_played(saved: Dictionary) -> String:
	var then := float(saved.get("saved_at", 0.0))
	if then <= 0.0:
		return Text.t("Not played yet")
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var days := CharacterDigest.days_ago(then, Time.get_unix_time_from_system(), bias)
	if days == 0:
		return Text.t("Played today")
	if days == 1:
		return Text.t("Played yesterday")
	if days < 7:
		return Text.f("Played %d days ago", [days])
	return Text.f("Played on %s", [Time.get_date_string_from_unix_time(int(then) + bias * 60)])


## Time in the town: "2 h 5 min", "12 min", or "A few minutes" under one.
static func played_for(saved: Dictionary) -> String:
	var played := CharacterDigest.played(saved)
	if played.x > 0:
		return Text.f("%d h %d min", [played.x, played.y])
	if played.y > 0:
		return Text.f("%d min", [played.y])
	return Text.t("A few minutes")
