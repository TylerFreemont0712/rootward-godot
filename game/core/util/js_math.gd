class_name JsMath
extends RefCounted
## JavaScript's rounding and logarithms, where GDScript's differ. The Shardrun rules were written against these, and
## the fixtures from the TypeScript engine pin them.


## Math.round: to the nearest integer, halves toward +infinity. GDScript's round() takes halves away from zero, so
## round(-2.5) is -3 where Math.round(-2.5) is -2.
static func js_round(value: float) -> int:
	var down := floorf(value)
	return int(down + 1.0) if value - down >= 0.5 else int(down)


## Math.log2 for a whole number, exact at powers of two. LEARN: log(8) / log(2) is 2.0794415416798357 /
## 0.6931471805599453 = 3.0000000000000004 in floating point, and ceil() of a value built on it would be off by one.
static func log2_whole(value: int) -> float:
	if value > 0 and (value & (value - 1)) == 0:
		var exponent := 0
		while value > 1:
			value >>= 1
			exponent += 1
		return float(exponent)
	return log(float(value)) / log(2.0)


## A number as JavaScript's template strings print it: "3" for 3.0, "1.5" for 1.5, "null" for null.
static func text(value: Variant) -> String:
	if value == null:
		return "null"
	if value is float:
		return JsJson.number(value)
	return str(value)
