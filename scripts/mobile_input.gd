class_name MobileInput
extends Control
## Movement begins only after GUI controls have had a chance to consume input.
signal movement_released
const NONE: int = -99
var enabled: bool = false
var pointer: int = NONE
var target_world := Vector2.ZERO
var has_target: bool = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func release() -> void:
	pointer = NONE
	has_target = false
	movement_released.emit()

func screen_to_world(point: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * point

func _set_target(point: Vector2) -> void:
	target_world = screen_to_world(point)
	has_target = true

func _input(event: InputEvent) -> void:
	if not enabled or pointer == NONE:
		return
	if event is InputEventScreenTouch and event.index == pointer and not event.pressed:
		release()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == pointer:
		_set_target(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and pointer == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		release()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer == -1:
		_set_target(event.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or pointer != NONE:
		return
	if event is InputEventScreenTouch and event.pressed:
		pointer = event.index
		_set_target(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pointer = -1
		_set_target(event.position)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release()

func movement(player_position: Vector2, island: PackedVector2Array) -> Vector2:
	if not enabled:
		return Vector2.ZERO
	var keyboard := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if keyboard.length_squared() > 0:
		return keyboard.normalized()
	if not has_target:
		return Vector2.ZERO
	var target: Vector2 = IslandGeometry.clamp_inside(island, target_world)
	var distance: float = player_position.distance_to(target)
	return player_position.direction_to(target) * minf(1.0, distance / 20.0) if distance > 7 else Vector2.ZERO
