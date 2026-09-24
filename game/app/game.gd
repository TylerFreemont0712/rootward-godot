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

## The rules read English content (old ADR-0018); screens show the same catalog, translated later (phase "Later").
static var catalog: Dictionary = {}
## Content errors and warnings from loading, for a screen that cannot start without content.
static var diagnostics: Array[Dictionary] = []
static var session: ShardrunSession
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
	var root := OS.get_environment(SAVES_ENV)
	session = ShardrunSession.new(catalog, SaveStore.new(root if root != "" else SaveStore.ROOT))
	if loaded.ok:
		session.load_saved()
	Sound.set_volumes(Settings.music_volume, Settings.sound_volume)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root.get_node_or_null("Lifecycle") == null:
		var lifecycle := Lifecycle.new()
		lifecycle.name = "Lifecycle"
		tree.root.add_child.call_deferred(lifecycle)
	return loaded.ok


## Forget everything, so the next `boot()` loads afresh (tests, and a tool that sets up its own run).
static func reset(save_root := "") -> void:
	_loaded = false
	catalog = {}
	diagnostics = []
	session = null
	if save_root != "":
		OS.set_environment(SAVES_ENV, save_root)


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
	(Engine.get_main_loop() as SceneTree).change_scene_to_file.call_deferred(scene)
