extends Node3D
class_name CameraRig

## Controla la rotación horizontal suave, zoom y desplazamiento entre las 5 islas consecutivas (eje Z).

signal focused_island_changed(island_id: int)

@export var rotation_step_deg: float = 45.0
@export var rotation_smooth_speed: float = 8.0
@export var move_smooth_speed: float = 6.0
@export var drag_sensitivity: float = 0.005
@export var zoom_min: float = 12.0
@export var zoom_max: float = 34.0
@export var zoom_step: float = 2.5
@export var island_spacing_z: float = 24.0
@export var total_islands: int = 5

@onready var camera: Camera3D = $Camera3D

var current_island_index: int = 0
var _target_yaw: float = 0.0
var _target_z: float = 0.0
var _target_distance: float = 22.0
var _is_dragging: bool = false


func _ready() -> void:
	_target_yaw = rotation.y
	_target_z = position.z
	if camera:
		_target_distance = clampf(camera.position.length(), zoom_min, zoom_max)


func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(rotation_smooth_speed * delta, 0.0, 1.0))
	position.z = lerpf(position.z, _target_z, clampf(move_smooth_speed * delta, 0.0, 1.0))
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
			_target_distance = clampf(_target_distance - zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_target_distance = clampf(_target_distance + zoom_step, zoom_min, zoom_max)
	elif event is InputEventMouseMotion and _is_dragging:
		_target_yaw -= event.relative.x * drag_sensitivity


func rotate_left() -> void:
	_target_yaw -= deg_to_rad(rotation_step_deg)


func rotate_right() -> void:
	_target_yaw += deg_to_rad(rotation_step_deg)


func focus_island(index: int) -> void:
	current_island_index = clampi(index, 0, total_islands - 1)
	_target_z = -float(current_island_index) * island_spacing_z
	focused_island_changed.emit(current_island_index + 1)


func focus_next_island() -> void:
	focus_island(current_island_index + 1)


func focus_prev_island() -> void:
	focus_island(current_island_index - 1)
