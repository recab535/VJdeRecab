extends Node3D

## Isla Flotante 3D orgánica y estratificada (archipiélago de 5 islas consecutivas en eje Z).
## Cuadrícula de 14x14 dividida en 4 parcelas comprables (0..3) con biomas diferenciados,
## cascadas/flujos shader 2.5D, rocas flotantes satélite y obstáculos temporizados.

signal island_locked_clicked(island_info: Dictionary)
signal parcel_locked_clicked(island_id: int, parcel_index: int, info: Dictionary)
signal slot_clicked_on_island(island_id: int, global_slot_index: int, slot_node: Node3D)
signal obstacle_clicked_on_island(obstacle_node: Node3D)

const OBSTACLE_SCENE_PATH: String = "res://scenes/world/obstaculo_isla.tscn"
const BUILD_SLOT_SCRIPT: Script = preload("res://scripts/world/build_slot.gd")

var _obstacle_scene_cache: PackedScene = null

const ISLAND_CONFIGS: Dictionary = {
	1: {
		"nombre": "Isla 1 — Santuario Verde",
		"color": Color(0.30, 0.78, 0.34),
		"rim_color": Color(0.24, 0.64, 0.28),
		"rock_top": Color(0.56, 0.42, 0.30),
		"rock_mid": Color(0.44, 0.33, 0.25),
		"rock_deep": Color(0.32, 0.24, 0.20),
		"accent": Color(0.95, 0.82, 0.24),
		"flow_type": "water",
		"costo_oro": 0,
		"nivel_req": 1,
		"elementos": "Tierra / Fuego"
	},
	2: {
		"nombre": "Isla 2 — Bruma Volcánica",
		"color": Color(0.68, 0.34, 0.22),
		"rim_color": Color(0.42, 0.20, 0.16),
		"rock_top": Color(0.34, 0.24, 0.22),
		"rock_mid": Color(0.24, 0.17, 0.17),
		"rock_deep": Color(0.16, 0.11, 0.12),
		"accent": Color(1.0, 0.45, 0.12),
		"flow_type": "lava",
		"costo_oro": 2500,
		"nivel_req": 3,
		"elementos": "Fuego / Agua"
	},
	3: {
		"nombre": "Isla 3 — Atolón Cristalino",
		"color": Color(0.24, 0.70, 0.84),
		"rim_color": Color(0.18, 0.56, 0.72),
		"rock_top": Color(0.68, 0.62, 0.48),
		"rock_mid": Color(0.46, 0.50, 0.56),
		"rock_deep": Color(0.26, 0.34, 0.46),
		"accent": Color(0.58, 0.96, 1.0),
		"flow_type": "water",
		"costo_oro": 8000,
		"nivel_req": 6,
		"elementos": "Agua / Planta"
	},
	4: {
		"nombre": "Isla 4 — Cumbre Tormenta",
		"color": Color(0.46, 0.44, 0.78),
		"rim_color": Color(0.34, 0.32, 0.62),
		"rock_top": Color(0.36, 0.38, 0.52),
		"rock_mid": Color(0.26, 0.28, 0.42),
		"rock_deep": Color(0.18, 0.20, 0.32),
		"accent": Color(0.54, 0.92, 1.0),
		"flow_type": "storm",
		"costo_oro": 20000,
		"nivel_req": 10,
		"elementos": "Eléctrico / Hielo"
	},
	5: {
		"nombre": "Isla 5 — Bastión Astral",
		"color": Color(0.32, 0.26, 0.54),
		"rim_color": Color(0.22, 0.18, 0.42),
		"rock_top": Color(0.28, 0.22, 0.40),
		"rock_mid": Color(0.20, 0.15, 0.30),
		"rock_deep": Color(0.12, 0.09, 0.20),
		"accent": Color(1.0, 0.82, 0.36),
		"flow_type": "astral",
		"costo_oro": 45000,
		"nivel_req": 15,
		"elementos": "Metal / Oscuro / Legendario"
	}
}

const PARCEL_OFFSETS: Array[Vector3] = [
	Vector3(-3.5, 0.0, -3.5),
	Vector3(3.5, 0.0, -3.5),
	Vector3(-3.5, 0.0, 3.5),
	Vector3(3.5, 0.0, 3.5)
]

@export var island_id: int = 1

var is_island_unlocked: bool = false
var unlocked_parcels: Array = []
var parcel_meshes: Array[MeshInstance3D] = []
var parcel_trim_meshes: Array[MeshInstance3D] = []
var parcel_lock_labels: Array[Label3D] = []
var parcel_areas: Array[Area3D] = []
var slot_nodes: Array[Node3D] = []
var obstacle_nodes: Dictionary = {}
var floor_tile_root: Node3D = null
var _floating_satellites: Array[Node3D] = []
var _island_title_label: Label3D = null

var _base_y: float = 0.0
var _bob_time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_bob_time = float(island_id) * 1.15
	_build_island_geometry()


func _process(delta: float) -> void:
	_bob_time += delta * 1.05
	position.y = _base_y + sin(_bob_time) * 0.14
	for i: int in range(_floating_satellites.size()):
		var sat: Node3D = _floating_satellites[i]
		if is_instance_valid(sat):
			var base_sy: float = float(sat.get_meta("base_y", sat.position.y))
			sat.position.y = base_sy + sin(_bob_time * 1.4 + float(i) * 1.7) * 0.22
			sat.rotation.y += delta * (0.18 + float(i % 2) * 0.12)


func _build_island_geometry() -> void:
	var cfg: Dictionary = ISLAND_CONFIGS.get(island_id, ISLAND_CONFIGS[1])
	var rock_top_mat: ShaderMaterial = VisualShaders.make_toon(cfg["rock_top"], Color(0.22, 0.24, 0.36), 0.28, 0.88)
	var rock_mid_mat: ShaderMaterial = VisualShaders.make_toon(cfg["rock_mid"], Color(0.18, 0.20, 0.32), 0.22, 0.92)
	var rock_deep_mat: ShaderMaterial = VisualShaders.make_toon(cfg["rock_deep"], Color(0.14, 0.16, 0.26), 0.18, 0.95)
	var rim_mat: ShaderMaterial = VisualShaders.make_toon(cfg["rim_color"], Color(0.20, 0.26, 0.38), 0.36, 0.78)

	# 1. Plataforma estratificada orgánica (3 estratos + estalactitas colgantes)
	_add_rock_stratum(Vector3(0.0, -0.42, 0.0), 10.2, 9.5, 1.05, 12, rock_top_mat)
	_add_rock_stratum(Vector3(0.15, -1.65, -0.1), 8.8, 5.4, 1.85, 10, rock_mid_mat)
	_add_rock_stratum(Vector3(-0.1, -3.55, 0.12), 5.0, 1.35, 2.55, 8, rock_deep_mat)

	# Cornisa orgánica perimetral bajo el césped
	var rim_ring: MeshInstance3D = MeshInstance3D.new()
	var rim_mesh: CylinderMesh = CylinderMesh.new()
	rim_mesh.top_radius = 10.35
	rim_mesh.bottom_radius = 9.95
	rim_mesh.height = 0.42
	rim_mesh.radial_segments = 12
	rim_ring.mesh = rim_mesh
	rim_ring.material_override = rim_mat
	rim_ring.position = Vector3(0.0, 0.02, 0.0)
	add_child(rim_ring)

	# Estalactitas asimétricas y rocas satélite flotantes
	var stalactite_offsets: Array[Vector3] = [
		Vector3(-5.8, -2.2, -3.4),
		Vector3(5.6, -2.5, -2.8),
		Vector3(-4.6, -2.8, 4.9),
		Vector3(4.8, -2.1, 4.2),
		Vector3(0.4, -4.7, -0.3)
	]
	for idx: int in range(stalactite_offsets.size()):
		var st_r: float = 1.65 - float(idx % 3) * 0.32
		var st_h: float = 2.6 + float(idx % 2) * 0.9
		_add_rock_stratum(stalactite_offsets[idx], st_r, 0.25, st_h, 6, rock_mid_mat if idx % 2 == 0 else rock_deep_mat)

	_floating_satellites.clear()
	var sat_positions: Array[Vector3] = [
		Vector3(-10.8, -1.4, -4.5),
		Vector3(10.6, -0.9, 3.2),
		Vector3(-9.4, -2.6, 6.2),
		Vector3(9.8, -2.1, -6.4)
	]
	for s_idx: int in range(sat_positions.size()):
		var sat_root: Node3D = Node3D.new()
		sat_root.position = sat_positions[s_idx]
		sat_root.set_meta("base_y", sat_positions[s_idx].y)
		var sat_top: MeshInstance3D = MeshInstance3D.new()
		var sat_cap: CylinderMesh = CylinderMesh.new()
		sat_cap.top_radius = 1.05 - float(s_idx % 2) * 0.25
		sat_cap.bottom_radius = 0.22
		sat_cap.height = 1.35
		sat_cap.radial_segments = 6
		sat_top.mesh = sat_cap
		sat_top.material_override = rock_mid_mat
		sat_root.add_child(sat_top)

		var grass_cap: MeshInstance3D = MeshInstance3D.new()
		var g_mesh: CylinderMesh = CylinderMesh.new()
		g_mesh.top_radius = sat_cap.top_radius * 1.04
		g_mesh.bottom_radius = sat_cap.top_radius * 0.96
		g_mesh.height = 0.22
		g_mesh.radial_segments = 6
		grass_cap.mesh = g_mesh
		grass_cap.material_override = rim_mat
		grass_cap.position = Vector3(0.0, 0.68, 0.0)
		sat_root.add_child(grass_cap)

		add_child(sat_root)
		_floating_satellites.append(sat_root)

	# 2. Detalles de bioma diferenciados (cascada/lava/cristal/flujo astral + ornamentos perimetrales)
	_build_biome_features(cfg)

	# 3. Puente de piedras flotantes hacia la siguiente isla en el eje -Z
	if island_id < 5:
		_build_inter_island_bridge(rock_top_mat, rim_mat)

	# 4. 4 Parcelas de 7x7 conformando la cuadrícula 14x14
	parcel_meshes.clear()
	parcel_trim_meshes.clear()
	parcel_lock_labels.clear()
	parcel_areas.clear()
	slot_nodes.clear()

	for p_idx: int in range(4):
		var p_root: Node3D = Node3D.new()
		p_root.name = "Parcela_%d" % p_idx
		p_root.position = PARCEL_OFFSETS[p_idx]
		add_child(p_root)

		var slab: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(6.72, 0.56, 6.72)
		slab.mesh = box
		slab.position = Vector3(0.0, 0.28, 0.0)
		p_root.add_child(slab)
		parcel_meshes.append(slab)

		# Borde biselado sutil por parcela + retícula visual 7x7 (14x14 total)
		var trim: MeshInstance3D = MeshInstance3D.new()
		var trim_box: BoxMesh = BoxMesh.new()
		trim_box.size = Vector3(6.86, 0.16, 6.86)
		trim.mesh = trim_box
		trim.position = Vector3(0.0, 0.12, 0.0)
		trim.material_override = rim_mat
		p_root.add_child(trim)
		parcel_trim_meshes.append(trim)

		_add_parcel_grid_lines(p_root)

		# Etiqueta de parcela bloqueada (solo visible cuando la isla está abierta pero la parcela cerrada)
		var p_lbl: Label3D = Label3D.new()
		p_lbl.text = "Parcela %d\nClick para expandir" % (p_idx + 1)
		p_lbl.position = Vector3(0.0, 1.05, 0.0)
		p_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p_lbl.font_size = 24
		p_lbl.outline_size = 6
		p_lbl.modulate = Color(1.0, 0.92, 0.55, 0.95)
		p_lbl.visible = false
		p_root.add_child(p_lbl)
		parcel_lock_labels.append(p_lbl)

		var p_area: Area3D = Area3D.new()
		var col: CollisionShape3D = CollisionShape3D.new()
		var bshape: BoxShape3D = BoxShape3D.new()
		bshape.size = Vector3(6.72, 0.85, 6.72)
		col.shape = bshape
		p_area.add_child(col)
		p_area.position = Vector3(0.0, 0.36, 0.0)
		var captured_p: int = p_idx
		p_area.input_event.connect(func(_cam: Node, ev: InputEvent, _pos: Vector3, _n: Vector3, _s: int) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_parcel_area_clicked(captured_p)
		)
		p_root.add_child(p_area)
		parcel_areas.append(p_area)

		# 2 Slots construibles por parcela (8 por isla -> 40 en las 5 islas)
		var local_offsets: Array[Vector3] = [Vector3(-1.55, 0.58, -1.2), Vector3(1.55, 0.58, 1.3)]
		for s_local: int in range(local_offsets.size()):
			var slot: Marker3D = Marker3D.new()
			slot.name = "Slot_%d_%d" % [p_idx, s_local]
			slot.position = local_offsets[s_local]
			var pad: MeshInstance3D = MeshInstance3D.new()
			var pad_mesh: CylinderMesh = CylinderMesh.new()
			pad_mesh.top_radius = 1.35
			pad_mesh.bottom_radius = 1.35
			pad_mesh.height = 0.04
			pad_mesh.radial_segments = 16
			pad.mesh = pad_mesh
			slot.add_child(pad)
			p_root.add_child(slot)

			slot.set_script(BUILD_SLOT_SCRIPT)
			slot._ready()
			var global_slot_idx: int = (island_id - 1) * 8 + p_idx * 2 + s_local
			slot.set("island_id", island_id)
			slot.set("slot_index", global_slot_idx)
			slot.set_meta("parcel_index", p_idx)
			slot.connect("slot_clicked", func(sn: Node3D) -> void:
				slot_clicked_on_island.emit(island_id, global_slot_idx, sn)
			)
			slot_nodes.append(slot)

	floor_tile_root = Node3D.new()
	floor_tile_root.name = "FloorTiles"
	add_child(floor_tile_root)

	# Etiqueta flotante de la isla
	_island_title_label = Label3D.new()
	_island_title_label.text = str(cfg["nombre"])
	_island_title_label.position = Vector3(0.0, 3.0, -7.4)
	_island_title_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_island_title_label.font_size = 36
	_island_title_label.outline_size = 9
	add_child(_island_title_label)


func _add_rock_stratum(pos: Vector3, top_r: float, bot_r: float, height: float, segs: int, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = height
	cm.radial_segments = segs
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _add_parcel_grid_lines(p_root: Node3D) -> void:
	# Líneas sutiles divisorias para evidenciar la cuadrícula 7x7 de cada parcela (14x14 total)
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.12)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var step: float = 6.72 / 7.0
	for i: int in range(1, 7):
		var offset: float = -3.36 + float(i) * step
		var lx: MeshInstance3D = MeshInstance3D.new()
		var bx: BoxMesh = BoxMesh.new()
		bx.size = Vector3(6.64, 0.012, 0.028)
		lx.mesh = bx
		lx.material_override = line_mat
		lx.position = Vector3(0.0, 0.568, offset)
		p_root.add_child(lx)

		var lz: MeshInstance3D = MeshInstance3D.new()
		var bz: BoxMesh = BoxMesh.new()
		bz.size = Vector3(0.028, 0.012, 6.64)
		lz.mesh = bz
		lz.material_override = line_mat
		lz.position = Vector3(offset, 0.568, 0.0)
		p_root.add_child(lz)


func _build_biome_features(cfg: Dictionary) -> void:
	var flow_type: String = str(cfg.get("flow_type", "water"))
	var flow_mat: ShaderMaterial
	match flow_type:
		"lava":
			flow_mat = VisualShaders.make_lava()
		"storm":
			flow_mat = VisualShaders.make_water(
				Color(0.28, 0.72, 0.98, 0.90),
				Color(0.12, 0.24, 0.68, 0.95),
				Color(0.86, 0.96, 1.0, 1.0),
				0.95,
				0.05
			)
		"astral":
			flow_mat = VisualShaders.make_astral_flow()
		_:
			flow_mat = VisualShaders.make_water()

	# Estanque / fuente de borde + cascada animada cayendo por el acantilado lateral
	var pool: MeshInstance3D = MeshInstance3D.new()
	var pool_mesh: CylinderMesh = CylinderMesh.new()
	pool_mesh.top_radius = 1.65
	pool_mesh.bottom_radius = 1.55
	pool_mesh.height = 0.14
	pool_mesh.radial_segments = 14
	pool.mesh = pool_mesh
	pool.material_override = flow_mat
	pool.position = Vector3(7.35, 0.42, -1.2)
	add_child(pool)

	var fall: MeshInstance3D = MeshInstance3D.new()
	var fall_mesh: BoxMesh = BoxMesh.new()
	fall_mesh.size = Vector3(0.45, 5.4, 1.35)
	fall.mesh = fall_mesh
	fall.material_override = flow_mat
	fall.position = Vector3(8.75, -2.25, -1.2)
	fall.rotation_degrees = Vector3(0.0, 0.0, 8.0)
	add_child(fall)

	# Cristales / pilares / ornamentos perimetrales según bioma
	var accent_col: Color = cfg["accent"]
	var accent_mat: ShaderMaterial = VisualShaders.make_toon(
		accent_col,
		Color(0.2, 0.22, 0.36),
		0.55,
		0.35,
		0.15,
		accent_col,
		0.35 if flow_type != "water" else 0.08
	)
	var decor_angles: Array[float] = [0.42, 1.15, 2.28, 3.65, 4.82, 5.65]
	for a_idx: int in range(decor_angles.size()):
		var ang: float = decor_angles[a_idx]
		var px: float = cos(ang) * 8.65
		var pz: float = sin(ang) * 8.65
		var spire: MeshInstance3D = MeshInstance3D.new()
		var sm: CylinderMesh = CylinderMesh.new()
		if island_id == 1:
			# Arbustos florales en el perímetro del Santuario Verde
			sm.top_radius = 0.48
			sm.bottom_radius = 0.62
			sm.height = 0.65
			sm.radial_segments = 7
			spire.material_override = VisualShaders.make_toon(Color(0.20, 0.68, 0.26), Color(0.14, 0.30, 0.22), 0.4)
			spire.position = Vector3(px, 0.52, pz)
		else:
			# Cristales / obeliscos elementales según el bioma
			sm.top_radius = 0.06
			sm.bottom_radius = 0.42
			sm.height = 1.4 + float(a_idx % 2) * 0.55
			sm.radial_segments = 5
			spire.material_override = accent_mat
			spire.position = Vector3(px, 0.72 + float(a_idx % 2) * 0.2, pz)
			spire.rotation_degrees = Vector3(float((a_idx % 3) - 1) * 10.0, float(a_idx) * 35.0, float((a_idx % 2) * 8 - 4))
		spire.mesh = sm
		add_child(spire)


func _build_inter_island_bridge(rock_mat: Material, rim_mat: Material) -> void:
	# 3 piedras flotantes puente hacia la siguiente isla en Z = -24
	var bridge_z: Array[float] = [-10.2, -12.0, -13.8]
	for i: int in range(bridge_z.size()):
		var stone: MeshInstance3D = MeshInstance3D.new()
		var sm: CylinderMesh = CylinderMesh.new()
		sm.top_radius = 1.15 - absf(float(i - 1)) * 0.15
		sm.bottom_radius = 0.65
		sm.height = 0.68
		sm.radial_segments = 7
		stone.mesh = sm
		stone.material_override = rock_mat
		stone.position = Vector3(sin(float(i) * 1.3) * 0.45, -0.1 + float(i % 2) * 0.12, bridge_z[i])
		add_child(stone)

		var cap: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = sm.top_radius * 1.03
		cm.bottom_radius = sm.top_radius * 0.98
		cm.height = 0.14
		cm.radial_segments = 7
		cap.mesh = cm
		cap.material_override = rim_mat
		cap.position = Vector3(0.0, 0.36, 0.0)
		stone.add_child(cap)


func apply_state(island_unlocked: bool, unlocked_parcel_list: Array, obstacles_data: Array) -> void:
	is_island_unlocked = island_unlocked
	unlocked_parcels = unlocked_parcel_list.duplicate()
	var cfg: Dictionary = ISLAND_CONFIGS.get(island_id, ISLAND_CONFIGS[1])
	var active_color: Color = cfg["color"]

	if _island_title_label:
		if is_island_unlocked:
			_island_title_label.text = str(cfg["nombre"])
			_island_title_label.modulate = Color(1.0, 0.98, 0.92, 1.0)
		else:
			_island_title_label.text = "🔒 %s (%d Oro · Nv.%d)" % [str(cfg["nombre"]), int(cfg["costo_oro"]), int(cfg["nivel_req"])]
			_island_title_label.modulate = Color(0.76, 0.84, 0.96, 0.88)

	for p_idx: int in range(4):
		var parcel_open: bool = is_island_unlocked and unlocked_parcels.has(p_idx)
		if parcel_open:
			parcel_meshes[p_idx].material_override = VisualShaders.make_toon(
				active_color,
				Color(0.20, 0.28, 0.40),
				0.34,
				0.82
			)
		elif is_island_unlocked:
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = active_color.darkened(0.55)
			mat.albedo_color.a = 0.72
			mat.roughness = 0.92
			parcel_meshes[p_idx].material_override = mat
		else:
			var locked_mat: StandardMaterial3D = StandardMaterial3D.new()
			locked_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			locked_mat.albedo_color = Color(0.20, 0.22, 0.32, 0.56)
			locked_mat.roughness = 0.95
			parcel_meshes[p_idx].material_override = locked_mat

		if p_idx < parcel_lock_labels.size():
			parcel_lock_labels[p_idx].visible = is_island_unlocked and not parcel_open

		# Solo capturar clic en el área de parcela cuando está bloqueada (o isla bloqueada)
		parcel_areas[p_idx].input_ray_pickable = not parcel_open

	_sync_obstacles(obstacles_data)


func _sync_obstacles(obstacles_data: Array) -> void:
	var seen: Dictionary = {}
	for obs_var: Variant in obstacles_data:
		if not (obs_var is Dictionary):
			continue
		var obs: Dictionary = obs_var
		if int(obs.get("island_id", 1)) != island_id:
			continue
		var oid: String = str(obs.get("id", ""))
		if bool(obs.get("limpiado", false)):
			if obstacle_nodes.has(oid):
				var existing: Node3D = obstacle_nodes[oid]
				if is_instance_valid(existing):
					existing.queue_free()
				obstacle_nodes.erase(oid)
			continue
		seen[oid] = true
		if obstacle_nodes.has(oid) and is_instance_valid(obstacle_nodes[oid]):
			obstacle_nodes[oid].call("sync_state", obs)
		else:
			var p_idx: int = clampi(int(obs.get("parcela", 0)), 0, 3)
			if _obstacle_scene_cache == null:
				_obstacle_scene_cache = load(OBSTACLE_SCENE_PATH) as PackedScene
			if _obstacle_scene_cache == null:
				continue
			var node: Node3D = _obstacle_scene_cache.instantiate() as Node3D
			var p_offset: Vector3 = PARCEL_OFFSETS[p_idx]
			var ox: float = float(obs.get("x", 0.0))
			var oz: float = float(obs.get("z", 0.0))
			node.position = p_offset + Vector3(ox, 0.56, oz)
			add_child(node)
			node.call("configure", obs)
			node.connect("obstacle_clicked", func(onode: Node3D) -> void:
				obstacle_clicked_on_island.emit(onode)
			)
			obstacle_nodes[oid] = node

	for oid: String in obstacle_nodes.keys():
		if not seen.has(oid):
			if is_instance_valid(obstacle_nodes[oid]):
				obstacle_nodes[oid].queue_free()
			obstacle_nodes.erase(oid)


func set_slots_placement_mode(active: bool, built_habitats: Dictionary) -> void:
	for sn: Node3D in slot_nodes:
		var g_idx: int = int(sn.get("slot_index"))
		var p_idx: int = int(sn.get_meta("parcel_index", 0))
		var parcel_open: bool = is_island_unlocked and unlocked_parcels.has(p_idx)
		var is_free: bool = parcel_open and not built_habitats.has(g_idx)
		sn.call("set_placement_highlight", active and parcel_open, is_free)


func add_decorative_tile(tile_color: Color, count_idx: int) -> void:
	if floor_tile_root == null:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.08, 0.06, 1.08)
	mi.mesh = box
	mi.material_override = VisualShaders.make_toon(tile_color, Color(0.24, 0.28, 0.42), 0.25, 0.62)
	var col: int = count_idx % 5
	var row: int = count_idx / 5
	mi.position = Vector3(-5.0 + col * 1.25, 0.6, -5.2 + row * 1.25)
	floor_tile_root.add_child(mi)


func _on_parcel_area_clicked(parcel_idx: int) -> void:
	var cfg: Dictionary = ISLAND_CONFIGS.get(island_id, ISLAND_CONFIGS[1])
	if not is_island_unlocked:
		island_locked_clicked.emit({
			"id": island_id,
			"nombre": cfg["nombre"],
			"costo_oro": cfg["costo_oro"],
			"nivel_req": cfg["nivel_req"],
			"slots": 8,
			"elementos": cfg["elementos"]
		})
		return

	var parcel_cost: int = 450 * island_id + parcel_idx * 350
	var parcel_lvl: int = maxi(1, int(cfg["nivel_req"]) + parcel_idx - 1)
	parcel_locked_clicked.emit(island_id, parcel_idx, {
		"island_id": island_id,
		"parcel_index": parcel_idx,
		"nombre": "%s — Parcela %d" % [str(cfg["nombre"]), parcel_idx + 1],
		"costo_oro": parcel_cost,
		"nivel_req": parcel_lvl
	})
