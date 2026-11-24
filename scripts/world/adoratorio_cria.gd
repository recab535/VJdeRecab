extends Node3D

## Adoratorio de Cría 3D detallado: altar místico escalonado con cristales brillantes,
## anillo rúnico giratorio y motas mágicas flotantes. Al clicar abre el panel de Cruce.

signal adoratorio_clicked

@onready var base_altar: MeshInstance3D = get_node_or_null("BaseAltar") as MeshInstance3D
@onready var cristal_central: MeshInstance3D = get_node_or_null("CristalCentral") as MeshInstance3D
@onready var cristal_izq: MeshInstance3D = get_node_or_null("CristalIzq") as MeshInstance3D
@onready var cristal_der: MeshInstance3D = get_node_or_null("CristalDer") as MeshInstance3D
@onready var label_3d: Label3D = get_node_or_null("Label3D") as Label3D
@onready var area_click: Area3D = $AreaClick

var _time: float = 0.0
var _base_y: float = 1.18
var _rune_ring: MeshInstance3D = null
var _motes: Array[Node3D] = []


func _ready() -> void:
	if cristal_central:
		_base_y = cristal_central.position.y
	if area_click:
		area_click.input_event.connect(_on_area_input_event)
	_build_sanctuary_details()


func _build_sanctuary_details() -> void:
	var is_extra: bool = name.contains("Extra")
	var stone_col: Color = Color(0.50, 0.44, 0.58) if is_extra else Color(0.46, 0.46, 0.56)
	var crystal_col: Color = Color(1.0, 0.72, 0.28) if is_extra else Color(0.92, 0.36, 0.96)
	var stone_mat: ShaderMaterial = VisualShaders.make_toon(stone_col, Color(0.20, 0.18, 0.30), 0.34, 0.85)
	var crystal_mat: ShaderMaterial = VisualShaders.make_toon(crystal_col, Color(0.28, 0.14, 0.36), 0.65, 0.18, 0.15, crystal_col, 1.15)
	var gold_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.96, 0.80, 0.30), Color(0.42, 0.28, 0.12), 0.5, 0.3, 0.4, Color(0.96, 0.80, 0.30), 0.35)

	if base_altar:
		base_altar.material_override = stone_mat
	if cristal_central:
		cristal_central.material_override = crystal_mat
	if cristal_izq:
		cristal_izq.material_override = crystal_mat
	if cristal_der:
		cristal_der.material_override = crystal_mat

	# Escalón inferior del altar
	var step: MeshInstance3D = MeshInstance3D.new()
	var sm: CylinderMesh = CylinderMesh.new()
	sm.top_radius = 1.18
	sm.bottom_radius = 1.32
	sm.height = 0.20
	sm.radial_segments = 8
	step.mesh = sm
	step.material_override = stone_mat
	step.position = Vector3(0.0, 0.10, 0.0)
	add_child(step)

	# Anillo rúnico flotante giratorio
	_rune_ring = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.56
	tm.outer_radius = 0.68
	tm.rings = 16
	tm.ring_segments = 6
	_rune_ring.mesh = tm
	_rune_ring.material_override = gold_mat
	_rune_ring.position = Vector3(0.0, 0.64, 0.0)
	add_child(_rune_ring)

	# 3 motas de energía orbitando
	_motes.clear()
	for i: int in range(3):
		var mote: MeshInstance3D = MeshInstance3D.new()
		var spm: SphereMesh = SphereMesh.new()
		spm.radius = 0.08
		spm.height = 0.16
		mote.mesh = spm
		mote.material_override = crystal_mat
		add_child(mote)
		_motes.append(mote)

	if label_3d and is_extra:
		label_3d.text = "Adoratorio Extra"
		label_3d.modulate = Color(1.0, 0.90, 0.46, 1.0)


func _process(delta: float) -> void:
	_time += delta
	if cristal_central:
		cristal_central.rotation.y += delta * 1.4
		cristal_central.position.y = _base_y + sin(_time * 2.2) * 0.09
	if _rune_ring:
		_rune_ring.rotation.y -= delta * 0.9
	for i: int in range(_motes.size()):
		var ang: float = _time * 1.8 + float(i) * (TAU / 3.0)
		_motes[i].position = Vector3(cos(ang) * 0.65, 1.05 + sin(_time * 2.6 + float(i)) * 0.16, sin(ang) * 0.65)


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		adoratorio_clicked.emit()
