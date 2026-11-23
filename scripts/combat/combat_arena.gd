extends Node3D
class_name CombatArena

## Escena 2.5D de la Arena de Combate 3v3:
## Posiciona hasta 3 dragones aliados y 3 enemigos (Dragon2D),
## muestra barras de HP por unidad y botones de ataque elemental.

signal attack_selected(attack_index: int, element_id: int)
signal target_selected(enemy_index: int)
signal retreat_requested

const DRAGON_SCENE: PackedScene = preload("res://scenes/dragons/dragon_2d.tscn")
const MAX_TEAM_SIZE: int = 3

@onready var ally_markers: Array[Marker3D] = [
	$AllyPositions/AllySlot0,
	$AllyPositions/AllySlot1,
	$AllyPositions/AllySlot2
]
@onready var enemy_markers: Array[Marker3D] = [
	$EnemyPositions/EnemySlot0,
	$EnemyPositions/EnemySlot1,
	$EnemyPositions/EnemySlot2
]

@onready var lbl_arena_title: Label = %LblArenaTitle
@onready var lbl_turn_info: Label = %LblTurnInfo
@onready var btn_retreat: Button = %BtnRetreat
@onready var lbl_combat_log: Label = %LblCombatLog
@onready var ally_hp_list: VBoxContainer = %AllyHpList
@onready var enemy_hp_list: VBoxContainer = %EnemyHpList
@onready var attack_buttons_container: HBoxContainer = %AttackButtonsContainer
@onready var combat_manager: CombatManager = $CombatManager
@onready var arena_camera: Camera3D = $Camera3D

var _ally_dragons: Array[Dragon2D] = []
var _enemy_dragons: Array[Dragon2D] = []
var _ally_hp_cards: Array[Dictionary] = []
var _enemy_hp_cards: Array[Dictionary] = []
var _attack_buttons: Array[Button] = []
var _attack_elements: Array[int] = [1, 1, 2, 5]
var _selected_enemy_idx: int = 0
var _teams_initialized: bool = false


func _ready() -> void:
	btn_retreat.pressed.connect(func() -> void: retreat_requested.emit())
	_bind_hp_cards()
	_bind_attack_buttons()

	if not _teams_initialized:
		if has_node("/root/GameCore") and combat_manager:
			combat_manager.start_chapter(1, self)
		else:
			_setup_demo_preview()


func _bind_hp_cards() -> void:
	_ally_hp_cards.clear()
	for i: int in range(MAX_TEAM_SIZE):
		var card: PanelContainer = ally_hp_list.get_child(i) as PanelContainer
		_ally_hp_cards.append({
			"panel": card,
			"lbl_name": card.get_node("VBox/LblName") as Label,
			"bar": card.get_node("VBox/BarHp") as ProgressBar,
			"lbl_hp": card.get_node("VBox/LblHp") as Label
		})

	_enemy_hp_cards.clear()
	for i: int in range(MAX_TEAM_SIZE):
		var card: PanelContainer = enemy_hp_list.get_child(i) as PanelContainer
		var btn_target: Button = card.get_node("VBox/Header/BtnTarget") as Button
		var idx: int = i
		btn_target.pressed.connect(func() -> void: _on_enemy_target_pressed(idx))
		_enemy_hp_cards.append({
			"panel": card,
			"lbl_name": card.get_node("VBox/Header/LblName") as Label,
			"btn_target": btn_target,
			"bar": card.get_node("VBox/BarHp") as ProgressBar,
			"lbl_hp": card.get_node("VBox/LblHp") as Label
		})


func _bind_attack_buttons() -> void:
	_attack_buttons.clear()
	for i: int in range(attack_buttons_container.get_child_count()):
		var btn: Button = attack_buttons_container.get_child(i) as Button
		if btn:
			var idx: int = i
			btn.pressed.connect(func() -> void: _on_attack_button_pressed(idx))
			_attack_buttons.append(btn)


func _setup_demo_preview() -> void:
	var demo_allies: Array[Dictionary] = [
		{
			"especie_id": 1,
			"nombre": "Dragón Terracota",
			"sprite_prefijo": "dragon_terracota",
			"etapa": "joven",
			"hp": 120,
			"max_hp": 120
		}
	]
	var demo_enemies: Array[Dictionary] = [
		{
			"especie_id": 2,
			"nombre": "Dragón Ascua",
			"sprite_prefijo": "dragon_ascua",
			"etapa": "cria",
			"hp": 95,
			"max_hp": 95
		},
		{
			"especie_id": 5,
			"nombre": "Dragón Chispa",
			"sprite_prefijo": "dragon_chispa",
			"etapa": "cria",
			"hp": 90,
			"max_hp": 90
		}
	]
	setup_teams(demo_allies, demo_enemies)
	set_attack_buttons([
		{"label": "Golpe Tierra", "element_id": 1, "disabled": false},
		{"label": "Embestida Feroz", "element_id": 1, "disabled": false}
	])


func setup_teams(allies: Array, enemies: Array) -> void:
	_teams_initialized = true
	_clear_spawned_dragons()

	for i: int in range(MAX_TEAM_SIZE):
		if i < allies.size() and allies[i] is Dictionary:
			var unit: Dictionary = allies[i]
			var d_node: Dragon2D = _spawn_dragon_at(ally_markers[i], unit)
			_ally_dragons.append(d_node)
			_configure_hp_card(_ally_hp_cards[i], unit, true)
		else:
			_ally_dragons.append(null)
			_hide_hp_card(_ally_hp_cards[i])

	for i: int in range(MAX_TEAM_SIZE):
		if i < enemies.size() and enemies[i] is Dictionary:
			var unit: Dictionary = enemies[i]
			var d_node: Dragon2D = _spawn_dragon_at(enemy_markers[i], unit)
			_enemy_dragons.append(d_node)
			_configure_hp_card(_enemy_hp_cards[i], unit, false)
		else:
			_enemy_dragons.append(null)
			_hide_hp_card(_enemy_hp_cards[i])

	select_enemy_target(0)


func _clear_spawned_dragons() -> void:
	for d: Dragon2D in _ally_dragons:
		if is_instance_valid(d):
			d.queue_free()
	_ally_dragons.clear()

	for d: Dragon2D in _enemy_dragons:
		if is_instance_valid(d):
			d.queue_free()
	_enemy_dragons.clear()


func _spawn_dragon_at(marker: Marker3D, unit: Dictionary) -> Dragon2D:
	var d_node: Dragon2D = DRAGON_SCENE.instantiate() as Dragon2D
	marker.add_child(d_node)
	d_node.position = Vector3.ZERO
	d_node.setup_visual(
		int(unit.get("especie_id", 1)),
		str(unit.get("nombre", "Dragón")),
		str(unit.get("sprite_prefijo", "dragon_terracota")),
		str(unit.get("etapa", "cria"))
	)
	return d_node


func _configure_hp_card(card: Dictionary, unit: Dictionary, is_ally: bool) -> void:
	var panel: PanelContainer = card["panel"]
	var lbl_name: Label = card["lbl_name"]
	var bar: ProgressBar = card["bar"]
	var lbl_hp: Label = card["lbl_hp"]

	panel.visible = true
	var max_hp: int = maxi(1, int(unit.get("max_hp", unit.get("hp", 100))))
	var cur_hp: int = clampi(int(unit.get("hp", max_hp)), 0, max_hp)
	lbl_name.text = str(unit.get("nombre", "Dragón"))
	bar.max_value = max_hp
	bar.value = cur_hp
	lbl_hp.text = "%d / %d HP" % [cur_hp, max_hp]

	if not is_ally and card.has("btn_target"):
		var btn: Button = card["btn_target"]
		btn.disabled = cur_hp <= 0


func _hide_hp_card(card: Dictionary) -> void:
	var panel: PanelContainer = card["panel"]
	panel.visible = false


func update_unit_hp(is_ally: bool, index: int, current_hp: int, max_hp: int) -> void:
	var cards: Array[Dictionary] = _ally_hp_cards if is_ally else _enemy_hp_cards
	if index < 0 or index >= cards.size():
		return

	var card: Dictionary = cards[index]
	var safe_max: int = maxi(1, max_hp)
	var safe_hp: int = clampi(current_hp, 0, safe_max)

	var bar: ProgressBar = card["bar"]
	var lbl_hp: Label = card["lbl_hp"]
	bar.max_value = safe_max
	bar.value = safe_hp
	lbl_hp.text = "%d / %d HP" % [safe_hp, safe_max]

	if not is_ally and card.has("btn_target"):
		var btn: Button = card["btn_target"]
		btn.disabled = safe_hp <= 0

	var dragons: Array[Dragon2D] = _ally_dragons if is_ally else _enemy_dragons
	if index < dragons.size() and is_instance_valid(dragons[index]):
		var d_node: Dragon2D = dragons[index]
		if d_node.sprite:
			d_node.sprite.modulate = Color(1, 1, 1, 1) if safe_hp > 0 else Color(0.35, 0.35, 0.35, 0.5)


func set_attack_buttons(attacks: Array) -> void:
	_attack_elements.clear()
	for i: int in range(_attack_buttons.size()):
		var btn: Button = _attack_buttons[i]
		if i < attacks.size() and attacks[i] is Dictionary:
			var atk: Dictionary = attacks[i]
			btn.visible = true
			btn.text = str(atk.get("label", "Ataque %d" % (i + 1)))
			btn.disabled = bool(atk.get("disabled", false))
			_attack_elements.append(int(atk.get("element_id", 1)))
		else:
			btn.visible = false
			_attack_elements.append(1)


func set_attack_buttons_enabled(enabled: bool) -> void:
	for btn: Button in _attack_buttons:
		if btn.visible:
			btn.disabled = not enabled


func set_arena_title(title: String) -> void:
	if lbl_arena_title:
		lbl_arena_title.text = title


func set_turn_info(text: String) -> void:
	if lbl_turn_info:
		lbl_turn_info.text = text


func set_combat_log(text: String) -> void:
	if lbl_combat_log:
		lbl_combat_log.text = text


func select_enemy_target(index: int) -> void:
	if index < 0 or index >= _enemy_hp_cards.size():
		return
	_selected_enemy_idx = index
	for i: int in range(_enemy_hp_cards.size()):
		var card: Dictionary = _enemy_hp_cards[i]
		if card.has("btn_target"):
			var btn: Button = card["btn_target"]
			btn.text = "Objetivo" if i == _selected_enemy_idx else "Apuntar"


func get_selected_enemy_index() -> int:
	return _selected_enemy_idx


func _on_enemy_target_pressed(index: int) -> void:
	select_enemy_target(index)
	target_selected.emit(index)


func _on_attack_button_pressed(index: int) -> void:
	var elem_id: int = _attack_elements[index] if index < _attack_elements.size() else 1
	attack_selected.emit(index, elem_id)
