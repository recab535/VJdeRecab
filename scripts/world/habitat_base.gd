extends Node3D
class_name HabitatBase

## Plataforma 3D temática de hábitat con shaders 2.5D, decoración por elemento,
## indicador flotante de oro acumulado y reacciones vivas de los dragones alojados.

signal habitat_clicked(habitat: HabitatBase)

@export var elemento_id: int = 1
@export var capacidad_maxima: int = 2

const ELEMENT_COLORS: Dictionary = {
	1: Color(0.68, 0.48, 0.28, 1.0),
	2: Color(0.74, 0.24, 0.16, 1.0),
	3: Color(0.20, 0.58, 0.88, 1.0),
	4: Color(0.28, 0.74, 0.34, 1.0),
	5: Color(0.88, 0.76, 0.22, 1.0),
	6: Color(0.58, 0.88, 0.98, 1.0),
	7: Color(0.64, 0.68, 0.74, 1.0),
	8: Color(0.36, 0.22, 0.48, 1.0)
}

@onready var spots: Array[Node3D] = [$AreaDragones/DragonSpot1, $AreaDragones/DragonSpot2]
@onready var area_click: Area3D = get_node_or_null("AreaClick")

var dragons_count: int = 0
var hosted_dragon_uids: Array[int] = []
var hosted_dragons: Array[Dragon2D] = []
var accumulated_oro: float = 0.0
var oro_per_minute_total: float = 12.0

var _decor_root: Node3D = null
var _gold_badge: Label3D = null
var _badge_time: float = 0.0


func _ready() -> void:
	if area_click:
		area_click.input_event.connect(_on_area_input_event)
	_ensure_gold_badge()
	set_element_theme(elemento_id)


func _ensure_gold_badge() -> void:
	if _gold_badge != null:
		return
	_gold_badge = Label3D.new()
	_gold_badge.text = ""
	_gold_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_gold_badge.font_size = 24
	_gold_badge.outline_size = 6
	_gold_badge.modulate = Color(1.0, 0.90, 0.30, 1.0)
	_gold_badge.position = Vector3(0.0, 1.68, 0.0)
	_gold_badge.visible = false
	add_child(_gold_badge)


func _process(delta: float) -> void:
	if dragons_count > 0:
		accumulated_oro = minf(accumulated_oro + (oro_per_minute_total / 60.0) * delta, 500.0)
	if _gold_badge:
		var ready_gold: int = int(floor(accumulated_oro))
		if ready_gold >= 5:
			_badge_time += delta * 3.0
			_gold_badge.visible = true
			_gold_badge.text = "🪙 +%d Oro" % ready_gold
			_gold_badge.position.y = 1.68 + sin(_badge_time) * 0.08
		else:
			_gold_badge.visible = false


func collect_oro() -> int:
	var amount: int = int(floor(accumulated_oro))
	if amount <= 0:
		return 0
	accumulated_oro -= float(amount)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", "coin")
	spawn_floating_gold_text(amount)
	for d_node: Dragon2D in hosted_dragons:
		if is_instance_valid(d_node):
			d_node.play_reaction("★", true)
	return amount


func spawn_floating_gold_text(amount: int) -> void:
	var lbl: Label3D = Label3D.new()
	lbl.text = "+%d Oro" % amount
	lbl.modulate = Color(1.0, 0.88, 0.28, 1.0)
	lbl.outline_size = 8
	lbl.font_size = 32
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 1.6, 0.0)
	add_child(lbl)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", 2.8, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(lbl.queue_free)


func set_element_theme(elem_id: int) -> void:
	elemento_id = elem_id
	var base_col: Color = ELEMENT_COLORS.get(elem_id, ELEMENT_COLORS[1])
	var plat: MeshInstance3D = get_node_or_null("PlataformaHabitat") as MeshInstance3D
	if plat:
		plat.material_override = VisualShaders.make_toon(base_col, Color(0.20, 0.22, 0.34), 0.36, 0.80)

	if _decor_root and is_instance_valid(_decor_root):
		_decor_root.queue_free()
	_decor_root = Node3D.new()
	_decor_root.name = "HabitatDecor"
	add_child(_decor_root)

	# Borde esculpido alrededor del hábitat
	var rim: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 1.52
	tm.outer_radius = 1.72
	tm.rings = 18
	tm.ring_segments = 6
	rim.mesh = tm
	rim.material_override = VisualShaders.make_toon(base_col.darkened(0.22), Color(0.16, 0.18, 0.28), 0.32, 0.86)
	rim.position = Vector3(0.0, 0.22, 0.0)
	_decor_root.add_child(rim)

	# Superficie / ornamentos temáticos según elemento
	match elem_id:
		2: # Fuego: estanque de lava animada + rocas volcánicas
			var pool: MeshInstance3D = MeshInstance3D.new()
			var pm: CylinderMesh = CylinderMesh.new()
			pm.top_radius = 0.88
			pm.bottom_radius = 0.88
			pm.height = 0.05
			pm.radial_segments = 14
			pool.mesh = pm
			pool.material_override = VisualShaders.make_lava()
			pool.position = Vector3(0.0, 0.25, 0.0)
			_decor_root.add_child(pool)
			_add_accent_prop(Vector3(-1.22, 0.36, -0.68), 0.24, 0.44, Color(0.24, 0.16, 0.18))
			_add_accent_prop(Vector3(1.18, 0.32, 0.66), 0.20, 0.38, Color(0.24, 0.16, 0.18))
		3: # Agua: estanque cristalino animado
			var pool: MeshInstance3D = MeshInstance3D.new()
			var pm: CylinderMesh = CylinderMesh.new()
			pm.top_radius = 1.05
			pm.bottom_radius = 1.05
			pm.height = 0.05
			pm.radial_segments = 16
			pool.mesh = pm
			pool.material_override = VisualShaders.make_water()
			pool.position = Vector3(0.0, 0.25, 0.0)
			_decor_root.add_child(pool)
		4: # Planta: arbustos florales en el borde
			_add_accent_prop(Vector3(-1.25, 0.34, -0.52), 0.28, 0.38, Color(0.18, 0.66, 0.24))
			_add_accent_prop(Vector3(1.22, 0.32, 0.56), 0.24, 0.34, Color(0.24, 0.76, 0.30))
			_add_accent_prop(Vector3(0.88, 0.34, -1.02), 0.22, 0.32, Color(0.98, 0.82, 0.24), 0.2)
		5, 6, 8: # Eléctrico, Hielo, Oscuro: cristales brillantes perimetrales
			var emit_s: float = 0.65
			_add_accent_prop(Vector3(-1.24, 0.48, -0.62), 0.14, 0.68, base_col.lightened(0.2), emit_s)
			_add_accent_prop(Vector3(1.22, 0.44, 0.56), 0.12, 0.58, base_col.lightened(0.25), emit_s)
		_: # Tierra / Metal: rocas / pilares sólidos
			_add_accent_prop(Vector3(-1.24, 0.36, -0.62), 0.24, 0.44, base_col.darkened(0.18))
			_add_accent_prop(Vector3(1.20, 0.32, 0.64), 0.20, 0.38, base_col.lightened(0.12))


func _add_accent_prop(pos: Vector3, r: float, h: float, col: Color, emit_s: float = 0.0) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r * 0.25
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = VisualShaders.make_toon(col, Color(0.18, 0.20, 0.30), 0.45, 0.65, 0.1, col, emit_s)
	mi.position = pos
	_decor_root.add_child(mi)


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		habitat_clicked.emit(self)


func has_free_slot() -> bool:
	return dragons_count < capacidad_maxima and dragons_count < spots.size()


func place_dragon(dragon_node: Node3D, dragon_uid: int = -1) -> bool:
	if not has_free_slot():
		return false
	var spot: Node3D = spots[dragons_count]
	spot.add_child(dragon_node)
	dragon_node.position = Vector3.ZERO
	if "patrol_enabled" in dragon_node:
		dragon_node.set("patrol_enabled", true)
	dragons_count += 1
	if dragon_uid > 0:
		hosted_dragon_uids.append(dragon_uid)
	if dragon_node is Dragon2D:
		hosted_dragons.append(dragon_node as Dragon2D)
	return true


func refresh_dragon_visual(dragon_uid: int, new_nivel: int, new_etapa: String) -> bool:
	for d_node: Dragon2D in hosted_dragons:
		if is_instance_valid(d_node) and d_node.dragon_uid == dragon_uid:
			d_node.update_progression(new_nivel, new_etapa)
			return true
	return false
