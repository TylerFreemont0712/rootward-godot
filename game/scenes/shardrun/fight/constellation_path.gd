class_name ConstellationPath
extends RefCounted
## The geometry of a constellation bolt (docs/LEGENDARY_LOOKS.md, "Geometry"): where its stars sit along the line from
## the orrery to the foe, how far each strays from that line, the route through them, and the point a head reaches at a
## given time. Pure static functions over numbers and vectors, with no nodes. Randomness comes only through
## `LegendaryLook.unit`, so the same seed draws the same constellation.

## The stars' places along the line lie in this range: 0 is the origin and 1 is the target.
const T_MIN := 0.12
const T_MAX := 0.88

## The least gap between two neighbouring stars' places.
const MIN_GAP := 0.06

## The share of its width that a star's lateral bound loses across the whole line. A star at the target may stray by
## 1 - CONVERGE of what one at the origin may, so the routes narrow and meet on the foe.
const CONVERGE := 0.6


## The stars of a route: `count` pairs `Vector2(t, s)`. `t` is a star's place along the line, sorted and kept apart by
## MIN_GAP. `s` is its signed lateral offset as a fraction of the line's length, within `lateral_bound(t, spread)`.
static func stars(seed: int, count: int, spread: float) -> PackedVector2Array:
	var n: int = maxi(count, 0)
	var places: PackedFloat64Array = _places(seed, n)
	var points := PackedVector2Array()
	for k in n:
		var lateral: float = (LegendaryLook.unit(seed, n + k) * 2.0 - 1.0) * lateral_bound(places[k], spread)
		points.append(Vector2(places[k], lateral))
	return points


## How far a star at place `t` may stray from the line, as a fraction of the line's length. It narrows as `t` grows,
## towards the target.
static func lateral_bound(t: float, spread: float) -> float:
	return absf(spread) * (1.0 - CONVERGE * t)


## The route a bolt flies: the origin, each star on the line from origin to target and pushed sideways by its
## offset, then the target. A zero-length line has no direction, so every star sits on the origin.
static func route(origin: Vector2, target: Vector2, stars: PackedVector2Array) -> PackedVector2Array:
	var length: float = origin.distance_to(target)
	var normal: Vector2 = _normal(target - origin)
	var points := PackedVector2Array()
	points.append(origin)
	for k in stars.size():
		var star: Vector2 = stars[k]
		points.append(origin.lerp(target, star.x) + normal * (star.y * length))
	points.append(target)
	return points


## The point a head reaches after fraction `p` of its flight along `route`. Each segment takes an equal share of the
## time, so star k (1-based) is reached at `p = k / (count + 1)`. `p` is clamped to 0..1.
static func point_on(route: PackedVector2Array, p: float) -> Vector2:
	if route.is_empty():
		return Vector2.ZERO
	var segments: int = route.size() - 1
	if segments < 1:
		return route[0]
	var along: float = clampf(p, 0.0, 1.0) * segments
	# LEARN: the segment index is capped at the last one, so p = 1 lands on the target with a weight of 1 rather than
	# reading past the end of the route.
	var k: int = mini(floori(along), segments - 1)
	return route[k].lerp(route[k + 1], along - k)


## The star places: `count` values from the seed, scaled into [T_MIN, T_MAX], sorted, and pushed apart by MIN_GAP. When
## the range cannot hold that many gaps, they are spaced evenly instead.
static func _places(seed: int, count: int) -> PackedFloat64Array:
	var places := PackedFloat64Array()
	for k in count:
		places.append(lerpf(T_MIN, T_MAX, LegendaryLook.unit(seed, k)))
	places.sort()
	if count < 2:
		return places
	# LEARN: a push up can run past T_MAX, and a pull down can run below T_MIN. Pushing up, then pulling down from the top,
	# gives every gap MIN_GAP and keeps the places inside the range exactly when (count - 1) * MIN_GAP fits in it. So the
	# fit is checked first, and even spacing is the fallback for a crowd that cannot fit.
	if (count - 1) * MIN_GAP > T_MAX - T_MIN:
		return _even_places(count)
	return _pull_down(_push_up(places))


## Evenly spaced places from T_MIN to T_MAX, for `count` of at least 2.
static func _even_places(count: int) -> PackedFloat64Array:
	var places := PackedFloat64Array()
	for k in count:
		places.append(lerpf(T_MIN, T_MAX, float(k) / float(count - 1)))
	return places


## Each place pushed up until it is at least MIN_GAP past the one before it. This can run past T_MAX.
static func _push_up(places: PackedFloat64Array) -> PackedFloat64Array:
	# LEARN: a packed array is passed by value, so the caller never sees a change made here. The changed array is returned.
	for k in range(1, places.size()):
		places[k] = maxf(places[k], places[k - 1] + MIN_GAP)
	return places


## Each place pulled down until it is at least MIN_GAP short of the one after it, starting from the last, which first
## comes down to T_MAX. With the gaps fitting, the first place then sits at T_MIN or above.
static func _pull_down(places: PackedFloat64Array) -> PackedFloat64Array:
	var last: int = places.size() - 1
	places[last] = minf(places[last], T_MAX)
	for k in range(last - 1, -1, -1):
		places[k] = minf(places[k], places[k + 1] - MIN_GAP)
	return places


## The unit perpendicular to a direction. A zero direction has none, so it gives `Vector2.RIGHT`.
static func _normal(direction: Vector2) -> Vector2:
	# LEARN: a zero direction has no unit perpendicular. A zero normal would pull every star onto the line, so the fallback
	# is checked here rather than left to whatever normalising returns.
	var normal: Vector2 = Vector2(-direction.y, direction.x).normalized()
	return normal if normal != Vector2.ZERO else Vector2.RIGHT
