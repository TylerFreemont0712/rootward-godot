class_name ShardrunCatalog
extends RefCounted
## Everything from content and balance the Shardrun rules read:
##   {config, shards: {id: shard}, foes: {id: foe}, relics: {id: relic}, balance}
## Content keeps its file shape (snake_case, schema defaults applied). Numbers from JSON are floats; the rules convert
## with int() where the old schema said integer.


## The values of an {id: item} Dictionary, ordered by id. LEARN: the old engine sorted with localeCompare. For ids of
## lowercase letters, digits, '.' and '-', Unicode collation and plain code-point order agree (punctuation before
## digits before letters), which the fixture's own sorted lists confirm.
static func sorted_values(items: Dictionary) -> Array:
	var ids: Array = items.keys()
	ids.sort()
	return ids.map(func(id: String) -> Dictionary: return items[id])
