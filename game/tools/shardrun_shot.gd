extends Control
## A run set up for a screenshot, then the run screen over it. ROOTWARD_SHOT picks the moment:
##   map (default), fight, cast, volley (the bolts, without the code), turn, reward, treasure, rest, forge, end, code
## It plays in its own save folder, so the player's run is never touched:
##   ROOTWARD_SHOT=cast scripts/screenshot.sh res://tools/shardrun_shot.tscn shots/cast.png 90

signal shot_ready

const SAVES := "user://shot-saves"


func _ready() -> void:
	var shot := OS.get_environment("ROOTWARD_SHOT")
	var language := OS.get_environment("ROOTWARD_SHOT_LANGUAGE")
	Game.reset(SAVES)
	Game.boot()
	var session := Game.session
	session.saves.delete_run("spellbook")
	session.start(language if language != "" else "python", "beginner", "screenshot")
	var bot := ShardrunBot.new(session)
	match shot:
		"fight", "cast", "volley", "turn", "code":
			await bot.play_until("battle")
		"reward":
			await bot.play_until("reward")
		"treasure":
			bot.prefer = "treasure"
			await bot.play_until("reward", 200)
			while session.in_progress() and not (session.state.get("reward", {}) as Dictionary).has("chest"):
				await bot.send(bot._reward_move(session.state))
				await bot.play_until("reward", bot.steps + 200)
		"rest", "forge":
			bot.prefer = shot
			await bot.play_until(shot, 200)
		"end":
			await bot.play(2000)
		"map":
			await bot.play_until("reward")
			await bot.send(bot._reward_move(session.state))
			await bot.play_until("map", 10)
	var screen: Control = (load(Game.SHARDRUN) as PackedScene).instantiate()
	add_child(screen)
	for i in 10:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()
	match shot:
		"cast":
			screen.call("send", {"type": "cast", "spell_id": "spell-1"})
		"volley":
			Settings.code_speed = "off"
			screen.call("send", {"type": "cast", "spell_id": "spell-1"})
		"turn":
			screen.call("send", {"type": "end-turn"})
		"code":
			screen.call("_explore", "spell-1")
