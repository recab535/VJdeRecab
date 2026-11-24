extends Node3D

## Estructura especial 3D detallada clicable en la isla:
## Mina de Gemas (10 gemas / 1 gema cada 24h por isla), Portal de Historia,
## Campo de Entrenamiento y Guardería de Crías (4 espacios).

signal structure_clicked(kind: String, island_id: int)

@export var kind: String = "portal_historia"
@export var island_id: int = 1
@export var spin_node_path: NodePath = NodePath("")

@onready var area_click: Area3D = $AreaClick
@onready var label_3d: Label3D = get_node_or_null("Label3D") as Label3D

var _spin_node: Node3D = null
var _pulse_nodes: Array[Node3D] = []
var _time: float = 0.0


func _ready() -> void:
	if not spin_node_path.is_empty():
		_spin_node = get_node_or_null(spin_node_path) as Node3D
	if area_click:
		area_click.input_event.connect(_on_area_input_event)

	_apply_detailed_visuals()

	var core: Node = get_node_or_null("/root/GameCore")
	if core and core.has_signal("world_state_changed"):
		core.world_state_changed.connect(_refresh_status_label)
	_refresh_status_label()


func _apply_detailed_visuals() -> void:
	match kind:
		"mina_gemas":
			_enrich_gem_mine()
		"portal_historia":
			_enrich_story_portal()
		"campo_entrenamiento":
			_enrich_training_camp()
		"guarderia_crias":
			_enrich_nursery()


func _enrich_gem_mine() -> void:
	var rock_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.36, 0.38, 0.48), Color(0.16, 0.18, 0.28), 0.30, 0.90)
	var wood_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.54, 0.34, 0.18), Color(0.22, 0.14, 0.10), 0.28, 0.86)
	var gem_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.24, 0.90, 1.0), Color(0.12, 0.34, 0.56), 0.70, 0.15, 0.2, Color(0.22, 0.84, 1.0), 1.35)

	var base_m: MeshInstance3D = get_node_or_null("BaseMina") as MeshInstance3D
	if base_m:
		base_m.material_override = rock_mat
	var gem_c: MeshInstance3D = get_node_or_null("GemaCentral") as MeshInstance3D
	if gem_c:
		gem_c.material_override = gem_mat
		_pulse_nodes.append(gem_c)

	# Marco de madera de entrada de mina + cristales secundarios
	for sx: float in [-0.45, 0.45]:
		_add_box(Vector3(sx, 0.42, 0.72), Vector3(0.14, 0.82, 0.14), wood_mat)
	_add_box(Vector3(0.0, 0.84, 0.72), Vector3(1.12, 0.15, 0.18), wood_mat)
	# Cristales laterales brotando de la roca
	_add_crystal(Vector3(-0.52, 0.88, -0.22), 0.14, 0.48, Vector3(0.2, 0.0, 0.35), gem_mat)
	_add_crystal(Vector3(0.54, 0.82, 0.18), 0.12, 0.42, Vector3(-0.15, 0.0, -0.32), gem_mat)


func _enrich_story_portal() -> void:
	var stone_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.76, 0.72, 0.62), Color(0.28, 0.26, 0.36), 0.34, 0.82)
	var gold_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.96, 0.80, 0.30), Color(0.44, 0.28, 0.12), 0.55, 0.28, 0.45, Color(0.96, 0.80, 0.30), 0.35)

	for n_name: String in ["PilarIzq", "PilarDer", "Dintel"]:
		var n: MeshInstance3D = get_node_or_null(n_name) as MeshInstance3D
		if n:
			n.material_override = stone_mat
	var vortice: MeshInstance3D = get_node_or_null("Vortice") as MeshInstance3D
	if vortice:
		vortice.material_override = VisualShaders.make_astral_flow()
		_pulse_nodes.append(vortice)

	# Base escalonada + clave dorada + anillo rúnico giratorio
	_add_box(Vector3(0.0, 0.10, 0.0), Vector3(2.1, 0.20, 1.15), stone_mat)
	_add_box(Vector3(0.0, 1.92, 0.0), Vector3(0.52, 0.26, 0.50), gold_mat)

	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.58
	tm.outer_radius = 0.68
	tm.rings = 16
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = gold_mat
	ring.position = Vector3(0.0, 0.95, 0.0)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(ring)
	_spin_node = ring


func _enrich_training_camp() -> void:
	var sand_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.84, 0.72, 0.46), Color(0.36, 0.28, 0.20), 0.26, 0.88)
	var wood_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.52, 0.32, 0.16), Color(0.22, 0.14, 0.10), 0.30, 0.86)
	var banner_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.88, 0.22, 0.22), Color(0.36, 0.12, 0.16), 0.42, 0.65)
	var gold_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.95, 0.78, 0.28), Color(0.40, 0.26, 0.10), 0.5, 0.3, 0.35)

	# Re-estilizar mallas existentes
	for c: Node in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = sand_mat

	# 4 postes con banderines de torneo alrededor de la arena de entrenamiento
	for i: int in range(4):
		var ang: float = float(i) * PI * 0.5 + PI * 0.25
		var px: float = cos(ang) * 0.92
		var pz: float = sin(ang) * 0.92
		_add_cylinder(Vector3(px, 0.58, pz), 0.06, 0.08, 1.16, wood_mat)
		_add_box(Vector3(px, 1.02, pz), Vector3(0.06, 0.32, 0.28), banner_mat)
		_add_sphere(Vector3(px, 1.22, pz), 0.09, gold_mat)

	# Muñeco / blanco de entrenamiento en el centro
	_add_cylinder(Vector3(0.0, 0.55, 0.0), 0.08, 0.10, 0.95, wood_mat)
	_add_box(Vector3(0.0, 0.75, 0.0), Vector3(0.68, 0.12, 0.12), wood_mat)
	_add_sphere(Vector3(0.0, 1.05, 0.0), 0.20, banner_mat)


func _enrich_nursery() -> void:
	var wood_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.62, 0.42, 0.24), Color(0.24, 0.16, 0.12), 0.30, 0.85)
	var roof_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.28, 0.74, 0.62), Color(0.14, 0.34, 0.38), 0.42, 0.70)
	var cushion_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.98, 0.84, 0.44), Color(0.42, 0.30, 0.16), 0.35, 0.80)

	for c: Node in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = wood_mat

	# 4 cunas acogedoras (capacidad 4 crías) + techo cónico de guardería
	var crib_pos: Array[Vector3] = [
		Vector3(-0.42, 0.32, -0.38),
		Vector3(0.42, 0.32, -0.38),
		Vector3(-0.42, 0.32, 0.38),
		Vector3(0.42, 0.32, 0.38)
	]
	for cp: Vector3 in crib_pos:
		_add_cylinder(cp, 0.24, 0.26, 0.16, cushion_mat)

	# 4 columnas y techado elegante
	for sx: float in [-0.72, 0.72]:
		for sz: float in [-0.72, 0.72]:
			_add_cylinder(Vector3(sx, 0.66, sz), 0.07, 0.08, 1.12, wood_mat)
	_add_cylinder(Vector3(0.0, 1.48, 0.0), 0.08, 1.18, 0.65, roof_mat)


func _refresh_status_label() -> void:
	if label_3d == null:
		return
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	match kind:
		"mina_gemas":
			var mines: Dictionary = core.player_state.get("minas_gemas", {})
			var m: Dictionary = mines.get(str(island_id), {})
			if not bool(m.get("construida", false)):
				label_3d.text = "Mina de Gemas\n(Construir: 10 💎)"
				label_3d.modulate = Color(0.76, 0.90, 1.0, 0.92)
			elif bool(m.get("lista", false)):
				label_3d.text = "✨ Mina de Gemas ✨\n¡+1 Gema lista!"
				label_3d.modulate = Color(0.35, 1.0, 0.85, 1.0)
			else:
				var rem: int = int(ceil(float(m.get("restante_seg", 86400.0))))
				label_3d.text = "Mina de Gemas\n%dh %02dm" % [rem / 3600, (rem % 3600) / 60]
				label_3d.modulate = Color(0.88, 0.96, 1.0, 1.0)
		"campo_entrenamiento":
			var tr: Dictionary = core.player_state.get("entrenamiento", {})
			if bool(tr.get("activo", false)):
				var rem: int = int(ceil(float(tr.get("restante_seg", 0.0))))
				label_3d.text = "⚔ Entrenando\n%02d:%02d" % [rem / 60, rem % 60]
				label_3d.modulate = Color(1.0, 0.86, 0.36, 1.0)
			else:
				label_3d.text = "Campo de Entrenamiento"
				label_3d.modulate = Color(1.0, 0.96, 0.90, 1.0)
		"guarderia_crias":
			var g: Array = core.player_state.get("guarderia", [])
			label_3d.text = "Guardería (%d/4)" % g.size()
			label_3d.modulate = Color(0.92, 1.0, 0.92, 1.0)
		"portal_historia":
			var camp: Dictionary = core.player_state.get("campana", {})
			var cap: int = int(camp.get("capitulo_desbloqueado", 1))
			label_3d.text = "Portal de Historia\nCap. %d / 50" % cap
			label_3d.modulate = Color(0.74, 0.92, 1.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	if _spin_node:
		if kind == "portal_historia":
			_spin_node.rotation.z += delta * 1.1
		else:
			_spin_node.rotation.y += delta * 1.35
	for p: Node3D in _pulse_nodes:
		if is_instance_valid(p):
			var s: float = 1.0 + sin(_time * 2.8) * 0.05
			p.scale = Vector3(s, s, s)


func _add_box(pos: Vector3, sz: Vector3, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _add_cylinder(pos: Vector3, top_r: float, bot_r: float, h: float, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _add_sphere(pos: Vector3, r: float, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _add_crystal(pos: Vector3, r: float, h: float, rot: Vector3, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		structure_clicked.emit(kind, island_id)
