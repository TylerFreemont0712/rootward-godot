class_name Game
extends RefCounted
## What every screen shares, loaded once: the content, the options, and the run in progress. A screen calls
## `Game.boot()` first, so any scene can be opened on its own (the editor, a screenshot) and still find everything.
##
## LEARN: static variables live as long as the program, like an autoload, but without a node or a project setting;
## scenes can come and go (change_scene_to_file) and these stay.

const SAVES_ENV := "ROOTWARD_SAVES"
const TITLE := "res://scenes/title/title.tscn"
const SHARDRUN := "res://scenes/shardrun/shardrun.tscn"
const VERIFIER := "res://scenes/verifier/verifier.tscn"
## Each combat playstyle keeps its own run; Verifier is a saved code-reading course. The Shardrun is the program run
## (ADR-0012); the card Shardrun it grew from stays playable for a run already underway.
const PLAYSTYLES := {"program": "Shardrun", "deck": "Card Shardrun", "spellbook": "Spellforge", "verifier": "Verifier"}
const COMBAT: Array[String] = ["program", "deck", "spellbook"]

## The rules read English content (old ADR-0018); screens show the same catalog, translated later (phase "Later").
static var catalog: Dictionary = {}

## Content errors and warnings from loading, for a screen that cannot start without content.
static var diagnostics: Array[Dictionary] = []
## The run of the playstyle being played; `sessions` holds both, by playstyle.
static var session: ShardrunSession
static var sessions: Dictionary = {}
static var trial_session: ShardrunSession
static var trial_active := false
static var profiles: ProfileStore
static var profile: Dictionary = {}
static var _loaded := false


## Loads content, options and the saved run the first time; after that, does nothing. False when content is broken.
static func boot() -> bool:
	if _loaded:
		return diagnostics.all(func(d: Dictionary) -> bool: return d.severity != "error")
	_loaded = true
	Sandbox.sweep_stale()
	var loaded := ContentLoader.load_shardrun()
	catalog = loaded.catalog
	diagnostics = loaded.diagnostics
	Settings.load_file()
	var override_root := OS.get_environment(SAVES_ENV)
	profiles = ProfileStore.new(override_root.path_join("profiles") if override_root != "" else ProfileStore.ROOT)
	var existing := profiles.list_profiles()
	if existing.is_empty():
		var legacy := override_root if override_root != "" else SaveStore.ROOT
		var migrated := profiles.migrate_legacy(legacy, Settings.language, Settings.difficulty)
		if migrated.ok:
			profile = migrated.profile
		else:
			var created := profiles.create("Player 1")
			if created.ok:
				profile = created.profile
				profile.needs_name = true
				profiles.save_profile(profile)
	else:
		profile = profiles.active()
		if profile.has("migration_root") and not profile.get("migration_verified", false):
			profiles.confirm_migration(String(profile.id))
	if not profile.is_empty():
		select_profile(String(profile.id), false)
	else:
		_load_sessions(loaded.ok, SaveStore.new(override_root if override_root != "" else SaveStore.ROOT))
	Sound.set_volumes(Settings.music_volume, Settings.sound_volume)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.get_node_or_null("Lifecycle") == null:
		var lifecycle := Lifecycle.new()
		lifecycle.name = "Lifecycle"
		tree.root.add_child.call_deferred(lifecycle)
	return loaded.ok


static func select_profile(id: String, remember := true) -> bool:
	if profiles == null or not profiles.activate(id):
		return false
	profile = profiles.get_profile(id)
	Settings.character_skin = String(profile.get("avatar", "vesper"))
	Settings.loadout = Settings.clean_loadout(profile.get("loadout", {}))
	var overrides: Dictionary = profile.get("settings", {})
	Settings.language = String(overrides.get("language", SandboxJob.PYTHON))
	Settings.difficulty = String(overrides.get("difficulty", "beginner"))
	TranslationServer.set_locale(String(profile.get("preferred_language", "en")))
	_load_sessions(
		diagnostics.all(func(d: Dictionary) -> bool: return d.severity != "error"), SaveStore.new(profiles.run_root(id))
	)
	if remember:
		Settings.save_file()
	return true


static func remember_profile_settings() -> void:
	if profile.is_empty() or profiles == null:
		return
	profile.settings = {"language": Settings.language, "difficulty": Settings.difficulty}
	profiles.save_profile(profile)


static func remember_avatar() -> void:
	if profile.is_empty() or profiles == null:
		return
	profile.avatar = Settings.character_skin
	profile.loadout = Settings.loadout.duplicate()
	profiles.save_profile(profile)


static func display_catalog() -> Dictionary:
	if profile.get("preferred_language", "en") != "ja":
		return catalog
	var overlay := ContentLocale.load_overlay("ja")
	return ContentLocale.localize(catalog, overlay.strings)


static func _load_sessions(content_ok: bool, saves: SaveStore) -> void:
	sessions = {}
	for playstyle in COMBAT:
		var run_catalog := catalog
		if playstyle == "program" and content_ok:
			run_catalog = ProgramRules.catalog_for(catalog)
		var run := ShardrunSession.new(run_catalog, saves, playstyle)
		if content_ok:
			run.load_saved()
		sessions[playstyle] = run
	var trial_catalog := ProgramRules.catalog_for(catalog) if content_ok else catalog
	trial_session = ShardrunSession.new(trial_catalog, saves, "program", "trial")
	if content_ok:
		trial_session.load_saved()
	trial_session.changed.connect(_trial_changed)
	trial_active = false
	use(Settings.playstyle)
	# The card Shardrun is only offered while a run of it is underway (ADR-0012).
	if Settings.playstyle == "deck" and not (sessions.deck as ShardrunSession).in_progress():
		use("program")


## Forget everything, so the next `boot()` loads afresh (tests, and a tool that sets up its own run).
static func reset(save_root := "") -> void:
	_loaded = false
	catalog = {}
	diagnostics = []
	session = null
	sessions = {}
	trial_session = null
	trial_active = false
	profiles = null
	profile = {}
	if save_root != "":
		OS.set_environment(SAVES_ENV, save_root)


## Plays `playstyle` from now on (and remembers it as the player's choice).
static func use(playstyle: String) -> void:
	if playstyle == "verifier":
		session = sessions.program
		Settings.playstyle = playstyle
		return
	if not sessions.has(playstyle):
		playstyle = "program"
	session = sessions[playstyle]
	Settings.playstyle = playstyle


static func start_trial() -> bool:
	if trial_session == null or trial_session.trial_content.is_empty():
		return false
	trial_session.start(Settings.language, Settings.difficulty, String(trial_session.trial_content.seed))
	trial_active = true
	_trial_changed()
	return true


static func resume_trial() -> bool:
	if trial_session == null or not trial_session.has_run():
		return false
	if trial_session.state.get("trial", {}).get("done", false):
		return false
	trial_active = true
	return true


static func skip_trial() -> void:
	if profile.is_empty():
		return
	var tutorial: Dictionary = profile.get("tutorial", {})
	tutorial.trial_done = true
	tutorial.trial_skipped = true
	tutorial.trial_step = ""
	profile.tutorial = tutorial
	profiles.save_profile(profile)
	trial_active = false
	if trial_session != null:
		trial_session.saves.delete_run("trial")
		trial_session.state = {}


static func _trial_changed() -> void:
	if profile.is_empty() or trial_session == null or not trial_session.has_run():
		return
	var progress: Dictionary = trial_session.state.get("trial", {})
	if progress.is_empty():
		return
	var tutorial: Dictionary = profile.get("tutorial", {})
	tutorial.trial_step = String(progress.get("step_id", ""))
	if progress.get("done", false):
		tutorial.trial_done = true
	profile.tutorial = tutorial
	profiles.save_profile(profile)


## Whether sandbox runs and their dev tools are offered: always when the game runs from the Godot editor binary (as it
## does during development), or with ROOTWARD_DEV=1; never in an exported build.
static func dev_tools() -> bool:
	return OS.has_feature("editor") or OS.get_environment("ROOTWARD_DEV") == "1"


static func languages() -> Array[String]:
	var usable: Array[String] = []
	for language in SandboxJob.LANGUAGES:
		if Sandbox.is_available(language):
			usable.append(language)
	return usable


## Leaves the game tidily: running sandbox jobs finish, the music stops, and the audio server gets two frames to let go
## of its streams before the tree ends (quitting mid-song otherwise reports them as leaked).
static func quit() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	Background.finish_all()
	Sound.silence()
	await tree.process_frame
	await tree.process_frame
	tree.quit()


static func go(scene: String) -> void:
	ScreenTransition.go(scene)
