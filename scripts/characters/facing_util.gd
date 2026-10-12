class_name FacingUtil
extends RefCounted
## Shared helpers for animation facing names and simple cardinal snaps.


## Maps a facing/movement vector to an animation suffix.
static func dir_name(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "front" if v.y >= 0.0 else "back"


## Snaps a vector to a cardinal unit direction (no diagonals).
## Returns Vector2.ZERO if below deadzone.
static func snap_to_cardinal(v: Vector2, deadzone: float = 0.01) -> Vector2:
	if v.length() < deadzone:
		return Vector2.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))
