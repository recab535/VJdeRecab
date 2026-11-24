extends Node3D
class_name CameraRig

## Controla la rotación horizontal suave, zoom, navegación entre las 5 islas
## y enfoque cinematográfico (Tween) sobre cualquier entidad clicada.

signal focused_island_changed(island_id: int)

@export var rotation_step_deg: float = 45.0
@export var rotation_smooth_speed: float = 8.0
@export var move_smooth_speed: float = 6.5
@export var drag_sensitivity: float = 0.005
@export var zoom_min: float = 10.5
@export var zoom_max: float = 34.0
@export var zoom_step: float = 2.5
@export var default_zoom: float = 22.0
@export var island_spacing_z: float = 24.0
@export var total_islands: int = 5

@onready var camera: Camera3D = $Camera3D

var current_island_index: int = 0
var _target_yaw: float = 0.0
var _target_pos: Vector3 = Vector3.ZERO
var _target_distance: float = 22.0
var _is_dragging: bool = false
var _focus_tween: Tween = null
var _is_entity_focused: bool = false


func _ready() -> void:
	_target_yaw = rotation.y
	_target_pos = position
	if camera:
		_target_distance = clampf(camera.position.length(), zoom_min, zoom_max)
		default_zoom = _target_distance


func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(rotation_smooth_speed * delta, 0.0, 1.0))
	if _focus_tween == null or not _focus_tween.is_running():
		position = position.lerp(_target_pos, clampf(move_smooth_speed * delta, 0.0, 1.0))
		if camera:
			var dir: Vector3 = camera.position.normalized()
			if dir.is_zero_approx():
				dir = Vector3(0.0, 0.62, 0.78).normalized()
			var current_dist: float = camera.position.length()
			var next_dist: float = lerpf(current_dist, _target_distance, clampf(rotation_smooth_speed * delta, 0.0, 1.0))
			camera.position = dir * next_dist


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.keycode == KEY_LEFT:
			rotate_left()
		elif event.keycode == KEY_E or event.keycode == KEY_RIGHT:
			rotate_right()
		elif event.keycode == KEY_W or event.keycode == KEY_UP:
			focus_next_island()
		elif event.keycode == KEY_S or event.keycode == KEY_DOWN:
			focus_prev_island()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_stop_focus_tween()
			_target_distance = clampf(_target_distance - zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_stop_focus_tween()
			_target_distance = clampf(_target_distance + zoom_step, zoom_min, zoom_max)
	elif event is InputEventMouseMotion and _is_dragging:
		_target_yaw -= event.relative.x * drag_sensitivity


func _stop_focus_tween() -> void:
	if _focus_tween and _focus_tween.is_running():
		_focus_tween.kill()
	_focus_tween = null


func rotate_left() -> void:
	_target_yaw -= deg_to_rad(rotation_step_deg)


func rotate_right() -> void:
	_target_yaw += deg_to_rad(rotation_step_deg)


func focus_island(index: int) -> void:
	_stop_focus_tween()
	_is_entity_focused = false
	current_island_index = clampi(index, 0, total_islands - 1)
	_target_pos = Vector3(0.0, 0.0, -float(current_island_index) * island_spacing_z)
	_target_distance = default_zoom
	focused_island_changed.emit(current_island_index + 1)


func focus_on_target(world_pos: Vector3, zoom_dist: float = 13.5) -> void:
	_stop_focus_tween()
	_is_entity_focused = true
	var clamped_dist: float = clampf(zoom_dist, zoom_min, zoom_max)
	var dest_pos: Vector3 = Vector3(world_pos.x, maxf(0.0, world_pos.y * 0.4), world_pos.z)
	_target_pos = dest_pos
	_target_distance = clamped_dist

	_focus_tween = create_tween()
	_focus_tween.set_parallel(true)
	_focus_tween.tween_property(self, "position", dest_pos, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if camera:
		var dir: Vector3 = camera.position.normalized()
		if dir.is_zero_approx():
			dir = Vector3(0.0, 0.62, 0.78).normalized()
		_focus_tween.tween_property(camera, "position", dir * clamped_dist, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func clear_entity_focus() -> void:
	if not _is_entity_focused:
		return
	_stop_focus_tween()
	_is_entity_focused = false
	var dest_pos: Vector3 = Vector3(0.0, 0.0, -float(current_island_index) * island_spacing_z)
	_target_pos = dest_pos
	_target_distance = default_zoom

	_focus_tween = create_tween()
	_focus_tween.set_parallel(true)
	_focus_tween.tween_property(self, "position", dest_pos, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if camera:
		var dir: Vector3 = camera.position.normalized()
		if dir.is_zero_approx():
			dir = Vector3(0.0, 0.62, 0.78).normalized()
		_focus_tween.tween_property(camera, "position", dir * default_zoom, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func focus_next_island() -> void:
	focus_island(current_island_index + 1)


func focus_prev_island() -> void:
	focus_island(current_island_index - 1)
