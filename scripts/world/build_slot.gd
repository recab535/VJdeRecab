extends Marker3D
class_name BuildSlot

## Slot construible en una isla: se ilumina y pulsa en verde durante el modo colocación y detecta clics.

signal slot_clicked(slot_node: BuildSlot)

@export var island_id: int = 1
@export var slot_index: int = 0

var _pad_mesh: MeshInstance3D = null
var _area: Area3D = null
var _default_mat: StandardMaterial3D = null
var _highlight_mat: StandardMaterial3D = null
var _is_highlighted: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			_pad_mesh = child as MeshInstance3D
			break

	_default_mat = StandardMaterial3D.new()
	_default_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_default_mat.albedo_color = Color(0.95, 0.92, 0.55, 0.32)

	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color = Color(0.18, 0.96, 0.42, 0.88)
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = Color(0.18, 0.96, 0.42, 1.0)
	_highlight_mat.emission_energy_multiplier = 1.5

	_area = Area3D.new()
	_area.input_ray_pickable = false
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 0.4
	col.shape = shape
	_area.add_child(col)
	add_child(_area)
	_area.input_event.connect(_on_area_input_event)

	if _pad_mesh:
		_pad_mesh.material_override = _default_mat


func _process(delta: float) -> void:
	if _is_highlighted and _pad_mesh:
		_pulse_time += delta * 4.5
		var s: float = 1.0 + sin(_pulse_time) * 0.07
		_pad_mesh.scale = Vector3(s, 1.0, s)
	elif _pad_mesh and _pad_mesh.scale != Vector3.ONE:
		_pad_mesh.scale = Vector3.ONE


func set_placement_highlight(active: bool, is_free: bool) -> void:
	_is_highlighted = active and is_free
	if _area:
		_area.input_ray_pickable = _is_highlighted
	if _pad_mesh == null:
		return
	_pad_mesh.visible = is_free
	if _is_highlighted:
		_pad_mesh.material_override = _highlight_mat
	else:
		_pad_mesh.material_override = _default_mat


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(self)
