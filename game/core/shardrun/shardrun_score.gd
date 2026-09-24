class_name ShardrunScore
extends RefCounted
## The visible run score: progress matters most, while raw damage is deliberately softened. Square-root combat terms
## keep spectacular casts exciting without letting one multiplier chain outweigh clearing another layer.


static func score(state: Dictionary) -> Dictionary:
	var stats: Dictionary = state.stats
	var progress := int(stats.layers) * 1000 + int(stats.fights) * 100
	var combat := mini(3000, floori(sqrt(float(stats.damage)) * 12) + floori(sqrt(float(stats.best_cast)) * 15))
	var build := int(stats.shards) * 50 + int(stats.relics) * 100
	var survival := JsMath.js_round(float(state.integrity) / float(state.integrity_max) * 500)
	var turns := int(stats.turns)
	var tempo := JsMath.js_round(float(stats.fights) / turns * 400) if turns > 0 else 0
	var completion := 7500 if state.status == "won" else 0
	var penalties := mini(1000, int(stats.fizzled) * 2) + (250 if state.status == "abandoned" else 0)
	var total := maxi(0, progress + combat + build + survival + tempo + completion - penalties)
	var rank := "D"
	if total >= 12000:
		rank = "S"
	elif total >= 8000:
		rank = "A"
	elif total >= 5000:
		rank = "B"
	elif total >= 2500:
		rank = "C"
	return {
		"total": total,
		"rank": rank,
		"breakdown":
		{
			"progress": progress,
			"combat": combat,
			"build": build,
			"survival": survival,
			"tempo": tempo,
			"completion": completion,
			"penalties": penalties,
			"total": total,
		},
	}
