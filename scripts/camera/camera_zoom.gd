extends RefCounted
## Shared mouse-wheel zoom for Camera2D (Overworld + Fight).
## Preload as script; call CameraZoomScript.handle_wheel(...).


## Apply wheel event to cam. Returns true if handled.
## Godot: smaller zoom = farther out; larger = closer in.
static func handle_wheel(
	cam: Camera2D,
	event: InputEvent,
	zoom_min: float,
	zoom_max: float,
	step: float = 0.08
) -> bool:
	if cam == null or not is_instance_valid(cam) or not cam.enabled:
		return false
	if not (event is InputEventMouseButton) or not event.pressed:
		return false
	var mb := event as InputEventMouseButton
	var factor := 1.0
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		factor = 1.0 + step
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		factor = 1.0 - step
	else:
		return false
	var z := clampf(cam.zoom.x * factor, zoom_min, zoom_max)
	cam.zoom = Vector2(z, z)
	return true
