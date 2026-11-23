extends Node3D
class_name CombatArena

## Arena 1v1 estilo Dragon City:
## 1 dragón aliado activo vs 1 enemigo activo en pedestales 3D,
## 4 botones de ataque con efectividad elemental, 2 botones laterales de relevo
## y barras de HP animadas suavemente con Tween.

signal attack_selected(attack_index: int)
signal switch_requested(bench_team_index: int)
signal retreat_requested

const DRAGON_SCENE: PackedScene = preload("res://scenes/dragons/dragon_2d.tscn")

@onready var ally_spot: Marker3D = $PedestalAliado/AllyPedestalSpot
@onready var enemy_spot: Marker3D = $PedestalEnemigo/EnemyPedestalSpot
@onready var arena_camera: Camera3D = $Camera3D
@onready var combat_manager: CombatManager = $CombatManager

@onready var lbl_arena_title: Label = %LblArenaTitle
@onready var lbl_turn_info: Label = %LblTurnInfo
@onready var btn_retreat: Button = %BtnRetreat
@onready var lbl_combat_log: Label = %LblCombatLog

@onready var lbl_ally_name: Label = %LblAllyName
@onready var pb_ally_hp: ProgressBar = %PbAllyHp
@onready var lbl_ally_hp: Label = %LblAllyHp

@onready var lbl_enemy_name: Label = %LblEnemyName
@onready var pb_enemy_hp: ProgressBar = %PbEnemyHp
@onready var lbl_enemy_hp: Label = %LblEnemyHp

@onready var btn_relevo_0: Button = %BtnRelevo0
@onready var btn_relevo_1: Button = %BtnRelevo1
@onready var attack_buttons_container: HBoxContainer = %AttackButtonsContainer

var _active_ally_node: Dragon2D = null
var _active_enemy_node: Dragon2D = null
var _bench_team_indices: Array[int] = [-1, -1]
var _attack_buttons: Array[Button] = []
var _cam_base_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	if arena_camera:
		_cam_base_pos = arena_camera.position
	btn_retreat.pressed.connect(func() -> void: retreat_requested.emit())
	btn_relevo_0.pressed.connect(func() -> void:
		if _bench_team_indices[0] >= 0:
			switch_requested.emit(_bench_team_indices[0])
	)
	btn_relevo_1.pressed.connect(func() -> void:
		if _bench_team_indices[1] >= 0:
			switch_requested.emit(_bench_team_indices[1])
	)

	_attack_buttons.clear()
	for i: int in range(attack_buttons_container.get_child_count()):
		var btn: Button = attack_buttons_container.get_child(i) as Button
		if btn:
			_attack_buttons.append(btn)
			var idx: int = i
			btn.pressed.connect(func() -> void: attack_selected.emit(idx))

	if has_node("/root/GameCore") and combat_manager:
		combat_manager.start_chapter(1, self)


func set_header_info(title: String, turn_text: String) -> void:
	lbl_arena_title.text = title
	lbl_turn_info.text = turn_text


func set_combat_log(msg: String) -> void:
	lbl_combat_log.text = msg


func set_active_fighters(ally_unit: Dictionary, enemy_unit: Dictionary) -> void:
	_spawn_fighter_on_spot(ally_spot, ally_unit, true)
	_spawn_fighter_on_spot(enemy_spot, enemy_unit, false)

	lbl_ally_name.text = "%s (Nv.%d)" % [str(ally_unit.get("nombre", "Aliado")), int(ally_unit.get("nivel", 1))]
	lbl_enemy_name.text = "%s (Nv.%d)" % [str(enemy_unit.get("nombre", "Rival")), int(enemy_unit.get("nivel", 1))]
	update_hp_bars(
		int(ally_unit.get("hp", 100)), int(ally_unit.get("max_hp", 100)),
		int(enemy_unit.get("hp", 100)), int(enemy_unit.get("max_hp", 100)),
		true
	)


func _spawn_fighter_on_spot(spot: Marker3D, unit: Dictionary, is_ally: bool) -> void:
	for c: Node in spot.get_children():
		c.queue_free()
	var d: Dragon2D = DRAGON_SCENE.instantiate() as Dragon2D
	spot.add_child(d)
	d.position = Vector3(0, -0.35, 0)
	d.scale = Vector3(1.35, 1.35, 1.35)
	d.patrol_enabled = false
	d.setup_visual(
		int(unit.get("especie_id", 1)),
		str(unit.get("nombre", "Dragón")),
		str(unit.get("sprite_prefijo", "dragon_terracota")),
		str(unit.get("etapa", "cria")),
		int(unit.get("uid", -1)),
		int(unit.get("nivel", 1))
	)
	if is_ally:
		_active_ally_node = d
	else:
		_active_enemy_node = d

	var tw: Tween = create_tween()
	tw.tween_property(d, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func update_hp_bars(ally_hp: int, ally_max: int, enemy_hp: int, enemy_max: int, instant: bool = false) -> void:
	pb_ally_hp.max_value = maxf(1.0, float(ally_max))
	pb_enemy_hp.max_value = maxf(1.0, float(enemy_max))
	lbl_ally_hp.text = "%d / %d" % [maxi(0, ally_hp), ally_max]
	lbl_enemy_hp.text = "%d / %d" % [maxi(0, enemy_hp), enemy_max]

	if instant:
		pb_ally_hp.value = float(maxi(0, ally_hp))
		pb_enemy_hp.value = float(maxi(0, enemy_hp))
	else:
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(pb_ally_hp, "value", float(maxi(0, ally_hp)), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(pb_enemy_hp, "value", float(maxi(0, enemy_hp)), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func update_attack_buttons(moves: Array[Dictionary], enemy_species: Dictionary, core: Node) -> void:
	for i: int in range(_attack_buttons.size()):
		var btn: Button = _attack_buttons[i]
		if i >= moves.size():
			btn.visible = false
			continue
		btn.visible = true
		var mv: Dictionary = moves[i]
		var elem_id: int = int(mv.get("elemento_id", 1))
		var mult: float = core.get_elemental_multiplier(elem_id, enemy_species) if core else 1.0
		var tag: String = "Normal"
		var color: Color = Color(0.94, 0.96, 1.0, 1.0)
		if mult >= 1.9:
			tag = "Fuerte (2.0×)"
			color = Color(0.35, 0.98, 0.45, 1.0)
		elif mult <= 0.6:
			tag = "Débil (0.5×)"
			color = Color(1.0, 0.45, 0.42, 1.0)
		btn.text = "%s\n[%s]" % [str(mv.get("nombre", "Ataque")), tag]
		btn.add_theme_color_override("font_color", color)


func update_bench_buttons(ally_team: Array[Dictionary], active_idx: int) -> void:
	var btns: Array[Button] = [btn_relevo_0, btn_relevo_1]
	var slot: int = 0
	_bench_team_indices = [-1, -1]

	for i: int in range(ally_team.size()):
		if i == active_idx or slot >= 2:
			continue
		var unit: Dictionary = ally_team[i]
		var hp: int = int(unit.get("hp", 0))
		var max_hp: int = int(unit.get("max_hp", 100))
		var btn: Button = btns[slot]
		btn.visible = true
		btn.text = "Relevo: %s\nHP %d/%d" % [str(unit.get("nombre", "Dragón")), maxi(0, hp), max_hp]
		btn.disabled = hp <= 0
		_bench_team_indices[slot] = i
		slot += 1

	while slot < 2:
		btns[slot].visible = false
		slot += 1


func set_controls_enabled(enabled: bool) -> void:
	for btn: Button in _attack_buttons:
		btn.disabled = not enabled
	for i: int in range(2):
		var btn: Button = btn_relevo_0 if i == 0 else btn_relevo_1
		if _bench_team_indices[i] < 0:
			btn.disabled = true
		elif not enabled:
			btn.disabled = true


func play_lunge_animation(is_ally: bool) -> void:
	var attacker: Dragon2D = _active_ally_node if is_ally else _active_enemy_node
	if attacker == null:
		return
	var dir: Vector3 = Vector3(1.1, 0.25, -0.35) if is_ally else Vector3(-1.1, 0.25, 0.35)
	var tw: Tween = create_tween()
	tw.tween_property(attacker, "position", dir, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(attacker, "position", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func spawn_damage_number(is_ally_target: bool, damage: int, mult: float) -> void:
	var spot: Marker3D = ally_spot if is_ally_target else enemy_spot
	if spot == null:
		return
	var lbl: Label3D = Label3D.new()
	var suffix: String = " ¡CRÍTICO!" if mult >= 1.9 else (" (Débil)" if mult <= 0.6 else "")
	lbl.text = "-%d%s" % [damage, suffix]
	lbl.modulate = Color(1.0, 0.86, 0.22, 1.0) if mult >= 1.9 else Color(1.0, 0.35, 0.32, 1.0)
	lbl.font_size = 40
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0.0, 1.65, 0.0)
	spot.add_child(lbl)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", 2.9, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85)
	tw.chain().tween_callback(lbl.queue_free)


func shake_camera(intensity: float = 0.22, duration: float = 0.24) -> void:
	if arena_camera == null:
		return
	var tw: Tween = create_tween()
	var steps: int = 6
	var step_time: float = duration / float(steps)
	for _i: int in range(steps - 1):
		var offset: Vector3 = Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0.0)
		tw.tween_property(arena_camera, "position", _cam_base_pos + offset, step_time)
	tw.tween_property(arena_camera, "position", _cam_base_pos, step_time)
