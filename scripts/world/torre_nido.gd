extends Node3D

## Torre Nido 3D detallada: mejorable de 1 a 4 ranuras (10 / 15 / 20 gemas).
## Muestra dinámicamente de 1 a 4 cunas/huevos elementales en la corona según el nivel y huevos activos.

signal torre_nido_clicked

@onready var base_torre: MeshInstance3D = get_node_or_null("BaseTorre") as MeshInstance3D
@onready var cesta_nido: MeshInstance3D = get_node_or_null("CestaNido") as MeshInstance3D
@onready var huevo_visual: MeshInstance3D = get_node_or_null("HuevoVisual") as MeshInstance3D
@onready var label_3d: Label3D = get_node_or_null("Label3D") as Label3D
@onready var area_click: Area3D = $AreaClick

const ELEM_COLORS: Dictionary = {
	1: Color(0.72, 0.50, 0.28),
	2: Color(0.96, 0.36, 0.16),
	3: Color(0.22, 0.66, 0.96),
	4: Color(0.28, 0.80, 0.36),
	5: Color(0.98, 0.86, 0.22),
	6: Color(0.60, 0.90, 0.98),
	7: Color(0.70, 0.74, 0.80),
	8: Color(0.50, 0.26, 0.72),
	9: Color(0.98, 0.76, 0.24)
}

var _time: float = 0.0
var _decor_root: Node3D = null
var _egg_nodes: Array[Node3D] = []


func _ready() -> void:
	if huevo_visual:
		huevo_visual.visible = false
	if area_click:
		area_click.input_event.connect(_on_area_input_event)

	_build_architectural_details()

	var core: Node = get_node_or_null("/root/GameCore")
	if core:
		if core.has_signal("nest_updated"):
			core.nest_updated.connect(_refresh_egg_visual)
		if core.has_signal("world_state_changed"):
			core.world_state_changed.connect(_refresh_egg_visual)
		_refresh_egg_visual()


func _build_architectural_details() -> void:
	var stone_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.62, 0.56, 0.48), Color(0.24, 0.22, 0.32), 0.32, 0.85)
	var wood_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.52, 0.34, 0.18), Color(0.22, 0.14, 0.12), 0.28, 0.88)
	var gold_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.95, 0.78, 0.28), Color(0.45, 0.30, 0.10), 0.55, 0.35, 0.35, Color(0.95, 0.74, 0.22), 0.25)

	if base_torre:
		base_torre.material_override = stone_mat
	if cesta_nido:
		cesta_nido.material_override = wood_mat

	_decor_root = Node3D.new()
	_decor_root.name = "DecorTorre"
	add_child(_decor_root)

	# Plinto escalonado de piedra
	var plinth: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 1.02
	pm.bottom_radius = 1.18
	pm.height = 0.28
	pm.radial_segments = 10
	plinth.mesh = pm
	plinth.material_override = stone_mat
	plinth.position = Vector3(0.0, 0.14, 0.0)
	_decor_root.add_child(plinth)

	# 4 contrafuertes / columnas de madera alrededor de la torre
	for i: int in range(4):
		var ang: float = float(i) * PI * 0.5 + PI * 0.25
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.09
		cm.bottom_radius = 0.13
		cm.height = 1.25
		cm.radial_segments = 6
		pillar.mesh = cm
		pillar.material_override = wood_mat
		pillar.position = Vector3(cos(ang) * 0.76, 0.68, sin(ang) * 0.76)
		_decor_root.add_child(pillar)

	# Aro dorado decorativo bajo el nido
	var collar: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.64
	tm.outer_radius = 0.76
	tm.rings = 14
	tm.ring_segments = 6
	collar.mesh = tm
	collar.material_override = gold_mat
	collar.position = Vector3(0.0, 1.12, 0.0)
	_decor_root.add_child(collar)


func _process(delta: float) -> void:
	_time += delta * 2.8
	for i: int in range(_egg_nodes.size()):
		var egg_node: Node3D = _egg_nodes[i]
		if is_instance_valid(egg_node):
			var base_y: float = float(egg_node.get_meta("base_y", 1.48))
			var ready_flag: bool = bool(egg_node.get_meta("ready", false))
			var amp: float = 0.08 if ready_flag else 0.035
			egg_node.position.y = base_y + sin(_time + float(i) * 1.4) * amp
			egg_node.rotation.z = sin(_time * 1.6 + float(i)) * (0.14 if ready_flag else 0.06)


func _refresh_egg_visual() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	var slots_max: int = clampi(int(core.get_nest_max_slots()), 1, 4)
	var huevos: Array = core.get_nest_eggs()

	for en: Node3D in _egg_nodes:
		if is_instance_valid(en):
			en.queue_free()
	_egg_nodes.clear()

	var slot_offsets: Array[Vector3] = [
		Vector3(0.0, 1.48, 0.0),
		Vector3(-0.34, 1.46, 0.20),
		Vector3(0.34, 1.46, 0.20),
		Vector3(0.0, 1.46, -0.34)
	]
	if slots_max >= 2:
		slot_offsets[0] = Vector3(0.0, 1.50, 0.0)

	var any_ready: bool = false
	for i: int in range(slots_max):
		var cradle_pos: Vector3 = slot_offsets[i]
		if i < huevos.size() and huevos[i] is Dictionary:
			var egg: Dictionary = huevos[i]
			var sp: Dictionary = core.get_species(int(egg.get("especie_id", 1)))
			var elem_id: int = int(sp.get("elemento_primario_id", 1))
			var col: Color = ELEM_COLORS.get(elem_id, Color(0.98, 0.88, 0.52))
			var is_ready: bool = bool(egg.get("listo", false))
			if is_ready:
				any_ready = true

			var egg_mi: MeshInstance3D = MeshInstance3D.new()
			var sm: SphereMesh = SphereMesh.new()
			sm.radius = 0.20 if slots_max > 1 else 0.27
			sm.height = sm.radius * 2.15
			sm.radial_segments = 12
			sm.rings = 8
			egg_mi.mesh = sm
			egg_mi.material_override = VisualShaders.make_toon(
				col,
				Color(0.24, 0.22, 0.36),
				0.55,
				0.28,
				0.08,
				Color(1.0, 0.88, 0.35) if is_ready else col,
				0.95 if is_ready else 0.35
			)
			egg_mi.position = cradle_pos
			egg_mi.set_meta("base_y", cradle_pos.y)
			egg_mi.set_meta("ready", is_ready)
			add_child(egg_mi)
			_egg_nodes.append(egg_mi)

	if label_3d:
		if any_ready:
			label_3d.text = "✨ Torre Nido (%d/%d)\n¡Huevo listo!" % [huevos.size(), slots_max]
			label_3d.modulate = Color(1.0, 0.90, 0.34, 1.0)
		else:
			label_3d.text = "Torre Nido (%d/%d)" % [huevos.size(), slots_max]
			label_3d.modulate = Color(0.96, 0.98, 1.0, 1.0)


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		torre_nido_clicked.emit()
