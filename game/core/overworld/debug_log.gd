class_name DebugLog
extends RefCounted
## The developer debug panel's event log (Lanternroot, ADR-0061): what the town did, kept as a plain Dictionary so it
## saves and tests easily. The newest LIMIT entries are kept. Pure: times are passed in, nothing reads a clock.
##
##   var book := DebugLog.add(DebugLog.empty(), "flag", "set first-step", {"flag": "first-step"}, at_msec)
##   DebugLog.latest(book, 10, ["flag", "quest"])   # the newest ten of those kinds, newest first
##   DebugLog.clock(at_msec, since_msec)            # "1:15.4"
##   DebugLog.value_text(data, 40)                  # one short line of a value, for the panel

const LIMIT := 200
## The kinds the panel shows: talk, flag, quest, thing, warp, poke, content.
const KINDS: Array[String] = ["talk", "flag", "quest", "thing", "warp", "poke", "content"]


## A book with nothing in it yet.
static func empty() -> Dictionary:
	return {"entries": [], "next": 1}


## A new book with one entry added at the end: {id, kind, text, data, at}. The data is copied, so changing it later
## changes nothing in the book. Only the newest LIMIT entries are kept.
static func add(book: Dictionary, kind: String, text: String, data: Dictionary, at_msec: int) -> Dictionary:
	var out := book.duplicate(true)
	var entries: Array = out.get("entries", [])
	var number := int(out.get("next", 1))
	entries.append({"id": number, "kind": kind, "text": text, "data": data.duplicate(true), "at": at_msec})
	if entries.size() > LIMIT:
		entries = entries.slice(entries.size() - LIMIT)
	out["entries"] = entries
	out["next"] = number + 1
	return out


## The newest `count` entries, newest first. With `kinds`, only entries of those kinds count; with none, every kind does.
## The entries returned are copies.
static func latest(book: Dictionary, count: int, kinds: Array[String] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var entries: Array = book.get("entries", [])
	var i := entries.size() - 1
	while i >= 0 and out.size() < count:
		var entry: Dictionary = entries[i]
		if kinds.is_empty() or kinds.has(String(entry.get("kind", ""))):
			out.append(entry.duplicate(true))
		i -= 1
	return out


## "m:ss.t" for the time from `since_msec` to `at_msec`: 75400 ms later is "1:15.4". A time before the start reads as
## "0:00.0".
@warning_ignore("integer_division")
static func clock(at_msec: int, since_msec: int) -> String:
	var tenths := maxi(at_msec - since_msec, 0) / 100
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


## A short one-line text of any value for the log: JSON with the keys in their own order. Longer text is cut to `limit`
## characters, the last of them "…".
static func value_text(value: Variant, limit: int = 80) -> String:
	var text := JSON.stringify(value, "", false)
	if text.length() <= limit:
		return text
	return text.substr(0, maxi(limit - 1, 0)) + "…"
