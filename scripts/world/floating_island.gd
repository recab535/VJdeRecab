extends Node3D

## Isla Flotante 3D orgánica y esculpida (silueta irregular sin plato circular ni césped cuadriculado).
## Cuadrícula lógica de 14x14 dividida en 4 parcelas comprables (0..3) con rejilla visible
## únicamente durante modo colocación o movimiento.

signal island_locked_clicked(island_info: Dictionary)
signal parcel_locked_clicked(island_id: int, parcel_index: int, info: Dictionary)
signal slot_clicked_on_island(island_id: int, global_slot_index: int, slot_node: Node3D)
signal obstacle_clicked_on_island(obstacle_node: Node3D)

const OBSTACLE_SCENE_PATH: String = "res://scenes/world/obstaculo_isla.tscn"
const BUILD_SLOT_SCRIPT: Script = preload("res://scripts/world/build_slot.gd")
const ISLAND_GRID_SCRIPT: Script = preload("res://scripts/world/island_grid.gd")

var _obstacle_scene_cache: PackedScene = null
var grid: RefCounted = null

const ISLAND_CONFIGS: Dictionary = {
	1: {
		"nombre": "Isla 1 — Santuario Verde",
		"color": Color(0.32, 0.72, 0.32),
		"rim_color": Color(0.24, 0.56, 0.25),
		"rock_top": Color(0.54, 0.40, 0.28),
		"rock_mid": Color(0.42, 0.32, 0.24),
		"rock_deep": Color(0.30, 0.23, 0.19),
		"accent": Color(0.92, 0.78, 0.26),
		"flow_type": "water",
		"costo_oro": 0,
		"nivel_req": 1,
		"elementos": "Tierra / Fuego"
	},
	2: {
		"nombre": "Isla 2 — Bruma Volcánica",
		"color": Color(0.64, 0.34, 0.22),
		"rim_color": Color(0.44, 0.22, 0.16),
		"rock_top": Color(0.34, 0.24, 0.22),
		"rock_mid": Color(0.24, 0.17, 0.17),
		"rock_deep": Color(0.16, 0.11, 0.12),
		"accent": Color(0.96, 0.44, 0.14),
		"flow_type": "lava",
		"costo_oro": 2500,
		"nivel_req": 3,
		"elementos": "Fuego / Agua"
	},
	3: {
		"nombre": "Isla 3 — Atolón Cristalino",
		"color": Color(0.26, 0.66, 0.78),
		"rim_color": Color(0.18, 0.52, 0.66),
		"rock_top": Color(0.64, 0.58, 0.46),
		"rock_mid": Color(0.44, 0.48, 0.54),
		"rock_deep": Color(0.26, 0.34, 0.44),
		"accent": Color(0.54, 0.90, 0.96),
		"flow_type": "water",
		"costo_oro": 8000,
		"nivel_req": 6,
		"elementos": "Agua / Planta"
	},
	4: {
		"nombre": "Isla 4 — Cumbre Tormenta",
		"color": Color(0.44, 0.42, 0.72),
		"rim_color": Color(0.32, 0.30, 0.58),
		"rock_top": Color(0.36, 0.38, 0.50),
		"rock_mid": Color(0.26, 0.28, 0.40),
		"rock_deep": Color(0.18, 0.20, 0.30),
		"accent": Color(0.52, 0.86, 0.96),
		"flow_type": "storm",
		"costo_oro": 20000,
		"nivel_req": 10,
		"elementos": "Eléctrico / Hielo"
	},
	5: {
		"nombre": "Isla 5 — Bastión Astral",
		"color": Color(0.32, 0.26, 0.50),
		"rim_color": Color(0.22, 0.18, 0.38),
		"rock_top": Color(0.28, 0.22, 0.38),
		"rock_mid": Color(0.20, 0.15, 0.28),
		"rock_deep": Color(0.12, 0.09, 0.18),
		"accent": Color(0.95, 0.78, 0.36),
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
var meadow_mesh_node: MeshInstance3D = null
var parcel_veil_meshes: Array[MeshInstance3D] = []
var parcel_areas: Array[Area3D] = []
var slot_nodes: Array[Node3D] = []
var obstacle_nodes: Dictionary = {}
var floor_tile_root: Node3D = null
var _grid_overlay_root: Node3D = null
var _floating_satellites: Array[Node3D] = []

var _base_y: float = 0.0
var _bob_time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_bob_time = float(island_id) * 1.15
	grid = ISLAND_GRID_SCRIPT.new()
	_build_island_geometry()


func _process(delta: float) -> void:
	_bob_time += delta * 0.95
	position.y = _base_y + sin(_bob_time) * 0.11
	for i: int in range(_floating_satellites.size()):
		var sat: Node3D = _floating_satellites[i]
		if is_instance_valid(sat):
			var base_sy: float = float(sat.get_meta("base_y", sat.position.y))
			sat.position.y = base_sy + sin(_bob_time * 1.35 + float(i) * 1.7) * 0.20
			sat.rotation.y += delta * (0.14 + float(i % 2) * 0.10)


func _organic_radius(angle: float, base_r: float) -> float:
	var s: float = float(island_id) * 1.37
	var wave: float = (
		sin(angle * 2.0 + s) * 0.085
		+ cos(angle * 3.0 - s * 1.4) * 0.065
		+ sin(angle * 5.0 + s * 2.1) * 0.032
		+ cos(angle * 4.0 + s * 0.7) * 0.028
	)
	return base_r * (1.0 + wave)


func _create_organic_cliff_mesh(
	rings: Array[Dictionary],
	segments: int = 28
) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_verts: Array = []
	for r_idx: int in range(rings.size()):
		var r_cfg: Dictionary = rings[r_idx]
		var r_base: float = float(r_cfg["radius"])
		var y_val: float = float(r_cfg["y"])
		var crag: float = float(r_cfg.get("crag", 0.0))
		var shift: Vector2 = r_cfg.get("shift", Vector2.ZERO)
		var pts: PackedVector3Array = PackedVector3Array()
		for i: int in range(segments):
			var ang: float = (float(i) / float(segments)) * TAU
			var rad: float = _organic_radius(ang, r_base)
			if crag > 0.0:
				rad *= 1.0 + sin(ang * 7.0 + float(r_idx) * 2.3 + float(island_id)) * crag
			var py: float = y_val + sin(ang * 4.0 + float(r_idx)) * (crag * 0.55)
			pts.append(Vector3(cos(ang) * rad + shift.x, py, sin(ang) * rad + shift.y))
		ring_verts.append(pts)

	# Tapa superior orgánica suave
	var top_pts: PackedVector3Array = ring_verts[0]
	var top_center: Vector3 = Vector3(0.0, float(rings[0]["y"]) + 0.03, 0.0)
	for i: int in range(segments):
		var next_i: int = (i + 1) % segments
		st.add_vertex(top_center)
		st.add_vertex(top_pts[next_i])
		st.add_vertex(top_pts[i])

	# Paredes laterales esculpidas entre anillos
	for r_idx: int in range(rings.size() - 1):
		var upper: PackedVector3Array = ring_verts[r_idx]
		var lower: PackedVector3Array = ring_verts[r_idx + 1]
		for i: int in range(segments):
			var next_i: int = (i + 1) % segments
			st.add_vertex(upper[i])
			st.add_vertex(upper[next_i])
			st.add_vertex(lower[i])

			st.add_vertex(upper[next_i])
			st.add_vertex(lower[next_i])
			st.add_vertex(lower[i])

	# Punta inferior asimétrica
	var bot_pts: PackedVector3Array = ring_verts[rings.size() - 1]
	var bot_tip: Vector3 = Vector3(
		sin(float(island_id) * 1.9) * 0.55,
		float(rings[rings.size() - 1]["y"]) - 1.15,
		cos(float(island_id) * 1.3) * 0.45
	)
	for i: int in range(segments):
		var next_i: int = (i + 1) % segments
		st.add_vertex(bot_tip)
		st.add_vertex(bot_pts[i])
		st.add_vertex(bot_pts[next_i])

	st.generate_normals()
	return st.commit()


func _build_island_geometry() -> void:
	var cfg: Dictionary = ISLAND_CONFIGS.get(island_id, ISLAND_CONFIGS[1])
	var rock_mat: ShaderMaterial = VisualShaders.make_toon(cfg["rock_mid"], Color(0.18, 0.22, 0.34), 0.06, 0.94)
	var rock_deep_mat: ShaderMaterial = VisualShaders.make_toon(cfg["rock_deep"], Color(0.14, 0.17, 0.28), 0.05, 0.96)
	var meadow_mat: ShaderMaterial = VisualShaders.make_toon(cfg["color"], Color(0.22, 0.30, 0.42), 0.05, 0.94)
	var rim_mat: ShaderMaterial = VisualShaders.make_toon(cfg["rim_color"], Color(0.20, 0.28, 0.38), 0.06, 0.90)

	# 1. Acantilado rocoso orgánico irregular debajo de la pradera
	var cliff_rings: Array[Dictionary] = [
		{"radius": 9.85, "y": 0.14, "crag": 0.04, "shift": Vector2.ZERO},
		{"radius": 9.15, "y": -0.75, "crag": 0.09, "shift": Vector2(0.18, -0.12)},
		{"radius": 6.40, "y": -2.35, "crag": 0.14, "shift": Vector2(-0.22, 0.16)},
		{"radius": 2.95, "y": -4.10, "crag": 0.18, "shift": Vector2(0.14, 0.10)}
	]
	var cliff_node: MeshInstance3D = MeshInstance3D.new()
	cliff_node.name = "AcantiladoOrganico"
	cliff_node.mesh = _create_organic_cliff_mesh(cliff_rings, 28)
	cliff_node.material_override = rock_mat
	add_child(cliff_node)

	# 2. Pradera superior continua orgánica con borde de césped colgante (sin plato circular)
	var meadow_rings: Array[Dictionary] = [
		{"radius": 10.15, "y": 0.56, "crag": 0.025, "shift": Vector2.ZERO},
		{"radius": 10.35, "y": 0.30, "crag": 0.04, "shift": Vector2.ZERO},
		{"radius": 9.80, "y": 0.06, "crag": 0.05, "shift": Vector2.ZERO}
	]
	meadow_mesh_node = MeshInstance3D.new()
	meadow_mesh_node.name = "PraderaOrganica"
	meadow_mesh_node.mesh = _create_organic_cliff_mesh(meadow_rings, 28)
	meadow_mesh_node.material_override = meadow_mat
	add_child(meadow_mesh_node)

	# Estalactitas asimétricas esculpidas bajo el acantilado
	var stalactite_offsets: Array[Vector3] = [
		Vector3(-5.6, -2.1, -3.2),
		Vector3(5.4, -2.4, -2.6),
		Vector3(-4.4, -2.7, 4.7),
		Vector3(4.6, -2.0, 4.0)
	]
	for idx: int in range(stalactite_offsets.size()):
		var st_r: float = 1.45 - float(idx % 3) * 0.25
		var st_h: float = 2.4 + float(idx % 2) * 0.85
		var mi: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = st_r
		cm.bottom_radius = 0.22
		cm.height = st_h
		cm.radial_segments = 6
		mi.mesh = cm
		mi.material_override = rock_deep_mat
		mi.position = stalactite_offsets[idx]
		add_child(mi)

	# Rocas flotantes satélite orgánicas
	_floating_satellites.clear()
	var sat_positions: Array[Vector3] = [
		Vector3(-11.2, -1.2, -4.4),
		Vector3(11.0, -0.8, 3.4),
		Vector3(-9.8, -2.4, 6.4),
		Vector3(10.2, -2.0, -6.2)
	]
	for s_idx: int in range(sat_positions.size()):
		var sat_root: Node3D = Node3D.new()
		sat_root.position = sat_positions[s_idx]
		sat_root.set_meta("base_y", sat_positions[s_idx].y)
		var sat_top: MeshInstance3D = MeshInstance3D.new()
		var sat_cap: CylinderMesh = CylinderMesh.new()
		sat_cap.top_radius = 1.0 - float(s_idx % 2) * 0.22
		sat_cap.bottom_radius = 0.2
		sat_cap.height = 1.3
		sat_cap.radial_segments = 6
		sat_top.mesh = sat_cap
		sat_top.material_override = rock_mat
		sat_root.add_child(sat_top)

		var grass_cap: MeshInstance3D = MeshInstance3D.new()
		var g_mesh: CylinderMesh = CylinderMesh.new()
		g_mesh.top_radius = sat_cap.top_radius * 1.06
		g_mesh.bottom_radius = sat_cap.top_radius * 0.96
		g_mesh.height = 0.22
		g_mesh.radial_segments = 6
		grass_cap.mesh = g_mesh
		grass_cap.material_override = rim_mat
		grass_cap.position = Vector3(0.0, 0.66, 0.0)
		sat_root.add_child(grass_cap)
		add_child(sat_root)
		_floating_satellites.append(sat_root)

	# 3. Detalles ambientales de bioma y puente inter-isla
	_build_biome_features(cfg)
	if island_id < 5:
		_build_inter_island_bridge(rock_mat, rim_mat)

	# 4. Rejilla lógica 14x14 (OCULTA en reposo; solo visible al colocar o mover)
	_build_placement_grid_overlay()

	# 5. 4 Parcelas (0..3) con velo suave solo cuando están bloqueadas + áreas clicables
	parcel_veil_meshes.clear()
	parcel_areas.clear()
	slot_nodes.clear()

	for p_idx: int in range(4):
		var p_root: Node3D = Node3D.new()
		p_root.name = "Parcela_%d" % p_idx
		p_root.position = PARCEL_OFFSETS[p_idx]
		add_child(p_root)

		var veil: MeshInstance3D = MeshInstance3D.new()
		var v_box: BoxMesh = BoxMesh.new()
		v_box.size = Vector3(6.6, 0.08, 6.6)
		veil.mesh = v_box
		veil.position = Vector3(0.0, 0.60, 0.0)
		p_root.add_child(veil)
		parcel_veil_meshes.append(veil)

		var p_area: Area3D = Area3D.new()
		var col: CollisionShape3D = CollisionShape3D.new()
		var bshape: BoxShape3D = BoxShape3D.new()
		bshape.size = Vector3(6.6, 0.85, 6.6)
		col.shape = bshape
		p_area.add_child(col)
		p_area.position = Vector3(0.0, 0.42, 0.0)
		var captured_p: int = p_idx
		p_area.input_event.connect(func(_cam: Node, ev: InputEvent, _pos: Vector3, _n: Vector3, _s: int) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_parcel_area_clicked(captured_p)
		)
		p_root.add_child(p_area)
		parcel_areas.append(p_area)

		# 2 Slots construibles por parcela (8 por isla)
		var local_offsets: Array[Vector3] = [Vector3(-1.55, 0.60, -1.2), Vector3(1.55, 0.60, 1.3)]
		for s_local: int in range(local_offsets.size()):
			var slot: Marker3D = Marker3D.new()
			slot.name = "Slot_%d_%d" % [p_idx, s_local]
			slot.position = local_offsets[s_local]
			var pad: MeshInstance3D = MeshInstance3D.new()
			var pad_mesh: CylinderMesh = CylinderMesh.new()
			pad_mesh.top_radius = 1.35
			pad_mesh.bottom_radius = 1.35
			pad_mesh.height = 0.03
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


func _build_placement_grid_overlay() -> void:
	_grid_overlay_root = Node3D.new()
	_grid_overlay_root.name = "GridOverlay"
	_grid_overlay_root.visible = false
	add_child(_grid_overlay_root)

	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.albedo_color = Color(0.88, 1.0, 0.88, 0.24)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i: int in range(15):
		var coord: float = -7.0 + float(i)
		var lx: MeshInstance3D = MeshInstance3D.new()
		var bx: BoxMesh = BoxMesh.new()
		bx.size = Vector3(14.0, 0.012, 0.032)
		lx.mesh = bx
		lx.material_override = line_mat
		lx.position = Vector3(0.0, 0.605, coord)
		_grid_overlay_root.add_child(lx)

		var lz: MeshInstance3D = MeshInstance3D.new()
		var bz: BoxMesh = BoxMesh.new()
		bz.size = Vector3(0.032, 0.012, 14.0)
		lz.mesh = bz
		lz.material_override = line_mat
		lz.position = Vector3(coord, 0.605, 0.0)
		_grid_overlay_root.add_child(lz)


func _build_biome_features(cfg: Dictionary) -> void:
	var flow_type: String = str(cfg.get("flow_type", "water"))
	var flow_mat: ShaderMaterial
	match flow_type:
		"lava":
			flow_mat = VisualShaders.make_lava()
		"storm":
			flow_mat = VisualShaders.make_water(Color(0.28, 0.68, 0.92, 0.90), Color(0.12, 0.24, 0.62, 0.95), Color(0.82, 0.94, 1.0, 1.0), 0.85, 0.04)
		"astral":
			flow_mat = VisualShaders.make_astral_flow()
		_:
			flow_mat = VisualShaders.make_water()

	var pool: MeshInstance3D = MeshInstance3D.new()
	var pool_mesh: CylinderMesh = CylinderMesh.new()
	pool_mesh.top_radius = 1.55
	pool_mesh.bottom_radius = 1.45
	pool_mesh.height = 0.10
	pool_mesh.radial_segments = 14
	pool.mesh = pool_mesh
	pool.material_override = flow_mat
	pool.position = Vector3(7.4, 0.54, -1.2)
	add_child(pool)

	var fall: MeshInstance3D = MeshInstance3D.new()
	var fall_mesh: BoxMesh = BoxMesh.new()
	fall_mesh.size = Vector3(0.42, 5.2, 1.25)
	fall.mesh = fall_mesh
	fall.material_override = flow_mat
	fall.position = Vector3(8.9, -2.15, -1.2)
	fall.rotation_degrees = Vector3(0.0, 0.0, 8.0)
	add_child(fall)

	var accent_col: Color = cfg["accent"]
	var accent_mat: ShaderMaterial = VisualShaders.make_toon(accent_col, Color(0.22, 0.24, 0.36), 0.10, 0.72, 0.05, accent_col, 0.18 if flow_type != "water" else 0.0)
	var decor_angles: Array[float] = [0.42, 1.18, 2.32, 3.68, 4.86, 5.62]
	for a_idx: int in range(decor_angles.size()):
		var ang: float = decor_angles[a_idx]
		var r_edge: float = _organic_radius(ang, 8.55)
		var px: float = cos(ang) * r_edge
		var pz: float = sin(ang) * r_edge
		var spire: MeshInstance3D = MeshInstance3D.new()
		var sm: CylinderMesh = CylinderMesh.new()
		if island_id == 1:
			sm.top_radius = 0.44
			sm.bottom_radius = 0.58
			sm.height = 0.62
			sm.radial_segments = 7
			spire.material_override = VisualShaders.make_toon(Color(0.22, 0.62, 0.26), Color(0.16, 0.30, 0.22), 0.06, 0.92)
			spire.position = Vector3(px, 0.76, pz)
		else:
			sm.top_radius = 0.06
			sm.bottom_radius = 0.38
			sm.height = 1.3 + float(a_idx % 2) * 0.45
			sm.radial_segments = 5
			spire.material_override = accent_mat
			spire.position = Vector3(px, 0.92 + float(a_idx % 2) * 0.18, pz)
			spire.rotation_degrees = Vector3(float((a_idx % 3) - 1) * 9.0, float(a_idx) * 35.0, float((a_idx % 2) * 8 - 4))
		spire.mesh = sm
		add_child(spire)


func _build_inter_island_bridge(rock_mat: Material, rim_mat: Material) -> void:
	var bridge_z: Array[float] = [-10.4, -12.1, -13.8]
	for i: int in range(bridge_z.size()):
		var stone: MeshInstance3D = MeshInstance3D.new()
		var sm: CylinderMesh = CylinderMesh.new()
		sm.top_radius = 1.1 - absf(float(i - 1)) * 0.15
		sm.bottom_radius = 0.62
		sm.height = 0.65
		sm.radial_segments = 7
		stone.mesh = sm
		stone.material_override = rock_mat
		stone.position = Vector3(sin(float(i) * 1.3) * 0.45, -0.08 + float(i % 2) * 0.10, bridge_z[i])
		add_child(stone)

		var cap: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = sm.top_radius * 1.03
		cm.bottom_radius = sm.top_radius * 0.98
		cm.height = 0.14
		cm.radial_segments = 7
		cap.mesh = cm
		cap.material_override = rim_mat
		cap.position = Vector3(0.0, 0.34, 0.0)
		stone.add_child(cap)


func apply_state(island_unlocked: bool, unlocked_parcel_list: Array, obstacles_data: Array) -> void:
	is_island_unlocked = island_unlocked
	unlocked_parcels = unlocked_parcel_list.duplicate()
	var cfg: Dictionary = ISLAND_CONFIGS.get(island_id, ISLAND_CONFIGS[1])
	var active_color: Color = cfg["color"]

	if meadow_mesh_node:
		if is_island_unlocked:
			meadow_mesh_node.material_override = VisualShaders.make_toon(active_color, Color(0.22, 0.30, 0.42), 0.05, 0.94)
		else:
			var dark_mat: StandardMaterial3D = StandardMaterial3D.new()
			dark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dark_mat.albedo_color = Color(0.18, 0.22, 0.32, 0.72)
			dark_mat.roughness = 0.96
			meadow_mesh_node.material_override = dark_mat

	for p_idx: int in range(4):
		var parcel_open: bool = is_island_unlocked and unlocked_parcels.has(p_idx)
		var veil: MeshInstance3D = parcel_veil_meshes[p_idx]
		if parcel_open:
			veil.visible = false
		elif is_island_unlocked:
			veil.visible = true
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.09, 0.12, 0.18, 0.44)
			mat.roughness = 0.96
			veil.material_override = mat
		else:
			veil.visible = false

		parcel_areas[p_idx].input_ray_pickable = not parcel_open

	if grid:
		grid.call("sync_unlocked_parcels", unlocked_parcels if is_island_unlocked else [])

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
			node.position = p_offset + Vector3(ox, 0.58, oz)
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
	if _grid_overlay_root:
		_grid_overlay_root.visible = active and is_island_unlocked
	if grid:
		grid.call("clear_occupants")
		for sn: Node3D in slot_nodes:
			var g_idx: int = int(sn.get("slot_index"))
			if built_habitats.has(g_idx):
				var local_p: Vector3 = sn.get_parent().position + sn.position
				var fp: Vector2i = Vector2i(3, 3)
				var cell_o: Vector2i = grid.call("local_to_cell", local_p, fp)
				grid.call("occupy", cell_o, fp, "hab_%d" % g_idx)
	for sn: Node3D in slot_nodes:
		var g_idx: int = int(sn.get("slot_index"))
		var p_idx: int = int(sn.get_meta("parcel_index", 0))
		var parcel_open: bool = is_island_unlocked and unlocked_parcels.has(p_idx)
		var is_free: bool = parcel_open and not built_habitats.has(g_idx)
		if grid and is_free:
			var local_p: Vector3 = sn.get_parent().position + sn.position
			var fp: Vector2i = Vector2i(3, 3)
			var cell_o: Vector2i = grid.call("local_to_cell", local_p, fp)
			is_free = bool(grid.call("can_place", cell_o, fp))
		sn.call("set_placement_highlight", active and parcel_open, is_free)


func add_decorative_tile(tile_color: Color, count_idx: int) -> void:
	if floor_tile_root == null:
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.08, 0.05, 1.08)
	mi.mesh = box
	mi.material_override = VisualShaders.make_toon(tile_color, Color(0.24, 0.28, 0.42), 0.05, 0.85)
	var col: int = count_idx % 5
	var row: int = count_idx / 5
	mi.position = Vector3(-5.0 + col * 1.25, 0.60, -5.2 + row * 1.25)
	floor_tile_root.add_child(mi)


func get_parcel_world_center(parcel_idx: int) -> Vector3:
	var p_off: Vector3 = PARCEL_OFFSETS[clampi(parcel_idx, 0, 3)]
	return global_position + p_off + Vector3(0.0, 0.6, 0.0)


func _on_parcel_area_clicked(parcel_idx: int) -> void:
	var cfg: Dictionary = ISLAND_CONFIGS.get(island_id, ISLAND_CONFIGS[1])
	if not is_island_unlocked:
		island_locked_clicked.emit({
			"id": island_id,
			"nombre": cfg["nombre"],
			"costo_oro": cfg["costo_oro"],
			"nivel_req": cfg["nivel_req"],
			"slots": 8,
			"elementos": cfg["elementos"],
			"world_pos": global_position
		})
		return

	var parcel_cost: int = 450 * island_id + parcel_idx * 350
	var parcel_lvl: int = maxi(1, int(cfg["nivel_req"]) + parcel_idx - 1)
	parcel_locked_clicked.emit(island_id, parcel_idx, {
		"island_id": island_id,
		"parcel_index": parcel_idx,
		"nombre": "%s — Parcela %d" % [str(cfg["nombre"]), parcel_idx + 1],
		"costo_oro": parcel_cost,
		"nivel_req": parcel_lvl,
		"world_pos": get_parcel_world_center(parcel_idx)
	})
