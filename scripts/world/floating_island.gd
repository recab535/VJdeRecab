extends Node3D

## Isla Flotante 3D modular (parte del archipiélago de 5 islas consecutivas en eje Z).
## Cuadrícula de 14x14 dividida en 4 parcelas comprables (0..3) con slots y obstáculos.

signal island_locked_clicked(island_info: Dictionary)
signal parcel_locked_clicked(island_id: int, parcel_index: int, info: Dictionary)
signal slot_clicked_on_island(island_id: int, global_slot_index: int, slot_node: Node3D)
signal obstacle_clicked_on_island(obstacle_node: Node3D)

const OBSTACLE_SCENE: PackedScene = preload("res://scenes/world/obstaculo_isla.tscn")
const BUILD_SLOT_SCRIPT: Script = preload("res://scripts/world/build_slot.gd")

const ISLAND_CONFIGS: Dictionary = {
	1: {"nombre": "Isla 1 — Santuario Verde", "color": Color(0.28, 0.76, 0.34), "costo_oro": 0, "nivel_req": 1, "elementos": "Tierra / Fuego"},
	2: {"nombre": "Isla 2 — Bruma Volcánica", "color": Color(0.76, 0.38, 0.24), "costo_oro": 2500, "nivel_req": 3, "elementos": "Fuego / Agua"},
	3: {"nombre": "Isla 3 — Atolón Cristalino", "color": Color(0.24, 0.62, 0.84), "costo_oro": 8000, "nivel_req": 6, "elementos": "Agua / Planta"},
	4: {"nombre": "Isla 4 — Cumbre Tormenta", "color": Color(0.54, 0.44, 0.82), "costo_oro": 20000, "nivel_req": 10, "elementos": "Eléctrico / Hielo"},
	5: {"nombre": "Isla 5 — Bastión Astral", "color": Color(0.28, 0.24, 0.42), "costo_oro": 45000, "nivel_req": 15, "elementos": "Metal / Oscuro / Legendario"}
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
var parcel_areas: Array[Area3D] = []
var slot_nodes: Array[Node3D] = []
var obstacle_nodes: Dictionary = {}
var floor_tile_root: Node3D = null

var _base_y: float = 0.0
var _bob_time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_bob_time = float(island_id) * 1.1
	_build_island_geometry()


func _process(delta: float) -> void:
	_bob_time += delta * 1.05
	position.y = _base_y + sin(_bob_time) * 0.14


func _build_island_geometry() -> void:
	var cfg: Dictionary = ISLAND_CONFIGS.get(island_id, ISLAND_CONFIGS[1])

	# Base rocosa cónica low-poly (14x14)
	var rock: MeshInstance3D = MeshInstance3D.new()
	var rock_mesh: CylinderMesh = CylinderMesh.new()
	rock_mesh.top_radius = 9.4
	rock_mesh.bottom_radius = 2.6
	rock_mesh.height = 4.2
	rock_mesh.radial_segments = 8
	var rock_mat: StandardMaterial3D = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.34, 0.28, 1.0)
	rock_mat.roughness = 0.95
	rock_mesh.material = rock_mat
	rock.mesh = rock_mesh
	rock.position = Vector3(0.0, -2.1, 0.0)
	add_child(rock)

	# 4 Parcelas de 7x7 conformando la cuadrícula 14x14
	parcel_meshes.clear()
	parcel_areas.clear()
	slot_nodes.clear()

	for p_idx: int in range(4):
		var p_root: Node3D = Node3D.new()
		p_root.name = "Parcela_%d" % p_idx
		p_root.position = PARCEL_OFFSETS[p_idx]
		add_child(p_root)

		var slab: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(6.7, 0.55, 6.7)
		slab.mesh = box
		slab.position = Vector3(0.0, 0.28, 0.0)
		p_root.add_child(slab)
		parcel_meshes.append(slab)

		var p_area: Area3D = Area3D.new()
		var col: CollisionShape3D = CollisionShape3D.new()
		var bshape: BoxShape3D = BoxShape3D.new()
		bshape.size = Vector3(6.7, 0.8, 6.7)
		col.shape = bshape
		p_area.add_child(col)
		p_area.position = Vector3(0.0, 0.35, 0.0)
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
			pad_mesh.radial_segments = 12
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
	var lbl: Label3D = Label3D.new()
	lbl.text = str(cfg["nombre"])
	lbl.position = Vector3(0.0, 2.8, -6.8)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 34
	lbl.outline_size = 8
	add_child(lbl)


func apply_state(island_unlocked: bool, unlocked_parcel_list: Array, obstacles_data: Array) -> void:
	is_island_unlocked = island_unlocked
	unlocked_parcels = unlocked_parcel_list.duplicate()
	var cfg: Dictionary = ISLAND_CONFIGS.get(island_id, ISLAND_CONFIGS[1])
	var active_color: Color = cfg["color"]

	for p_idx: int in range(4):
		var parcel_open: bool = is_island_unlocked and unlocked_parcels.has(p_idx)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		if parcel_open:
			mat.albedo_color = active_color
			mat.roughness = 0.85
		elif is_island_unlocked:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = active_color.darkened(0.55)
			mat.albedo_color.a = 0.72
			mat.roughness = 0.92
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.2, 0.22, 0.3, 0.52)
			mat.roughness = 0.95
		parcel_meshes[p_idx].material_override = mat
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
			var node: Node3D = OBSTACLE_SCENE.instantiate() as Node3D
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
	box.size = Vector3(1.1, 0.06, 1.1)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tile_color
	mat.roughness = 0.65
	box.material = mat
	mi.mesh = box
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
	elif not unlocked_parcels.has(parcel_idx):
		var cost: int = 400 * island_id + parcel_idx * 350
		var lvl_req: int = maxi(1, (island_id - 1) * 3 + parcel_idx)
		parcel_locked_clicked.emit(island_id, parcel_idx, {
			"island_id": island_id,
			"parcela": parcel_idx,
			"costo_oro": cost,
			"nivel_req": lvl_req
		})
