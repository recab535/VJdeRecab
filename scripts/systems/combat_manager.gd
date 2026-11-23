extends Node
class_name CombatManager

## Motor de combate por turnos 3v3 para la campaña PvE.
## Usa hp_base, atk_base, spd_base y multiplicadores elementales de GameCore.

signal combat_finished(victory: bool, rewards: Dictionary)

const CHAPTER_1_STAGES: Array[Dictionary] = [
	{
		"titulo": "Etapa 1/3 — Vanguardia Ígnea",
		"enemigos": [
			{"especie_id": 2, "nivel": 1},
			{"especie_id": 5, "nivel": 1}
		],
		"recompensa": {"oro": 150, "comida": 75, "gemas": 0}
	},
	{
		"titulo": "Etapa 2/3 — Cañón Volcánico",
		"enemigos": [
			{"especie_id": 9, "nivel": 2},
			{"especie_id": 10, "nivel": 2}
		],
		"recompensa": {"oro": 250, "comida": 125, "gemas": 0}
	},
	{
		"titulo": "Etapa 3/3 — Guardián del Sendero (Jefe)",
		"enemigos": [
			{"especie_id": 1, "nivel": 2},
			{"especie_id": 9, "nivel": 3},
			{"especie_id": 2, "nivel": 3}
		],
		"recompensa": {"oro": 400, "comida": 200, "gemas": 5}
	}
]

const ELEMENT_ATTACK_NAMES: Dictionary = {
	1: "Golpe Terracota",
	2: "Llamarada",
	3: "Torrente",
	4: "Látigo Cepa",
	5: "Descarga",
	6: "Aliento Gélido",
	7: "Impacto Férreo",
	8: "Pulso Umbrío",
	9: "Destello Astral"
}

var _arena: CombatArena = null
var _core: Node = null
var _chapter_id: int = 1
var _stages: Array[Dictionary] = []
var _stage_index: int = 0
var _ally_units: Array[Dictionary] = []
var _enemy_units: Array[Dictionary] = []
var _turn_queue: Array[Dictionary] = []
var _turn_cursor: int = 0
var _active_unit: Dictionary = {}
var _waiting_player_input: bool = false
var _combat_active: bool = false
var _accumulated_rewards: Dictionary = {"oro": 0, "comida": 0, "gemas": 0}


func start_chapter(chapter_id: int, arena: CombatArena) -> void:
	_arena = arena
	_chapter_id = chapter_id
	_core = get_node_or_null("/root/GameCore")
	if _arena == null or _core == null:
		push_error("[CombatManager] Falta CombatArena o GameCore para iniciar combate.")
		return

	if not _arena.attack_selected.is_connected(_on_arena_attack_selected):
		_arena.attack_selected.connect(_on_arena_attack_selected)
	if not _arena.retreat_requested.is_connected(_on_arena_retreat_requested):
		_arena.retreat_requested.connect(_on_arena_retreat_requested)

	_stages = CHAPTER_1_STAGES.duplicate(true)
	_stage_index = 0
	_accumulated_rewards = {"oro": 0, "comida": 0, "gemas": 0}
	_combat_active = true
	_waiting_player_input = false

	_ally_units = _build_player_team()
	_load_current_stage()


func _build_player_team() -> Array[Dictionary]:
	var team: Array[Dictionary] = []
	var owned: Array = _core.player_state.get("dragones", [])
	for i: int in range(mini(3, owned.size())):
		var d: Variant = owned[i]
		if d is Dictionary:
			var sp_id: int = int(d.get("especie_id", 1))
			var lvl: int = maxi(1, int(d.get("nivel", 1)))
			var etapa: String = str(d.get("etapa", "cria"))
			team.append(_create_unit(sp_id, lvl, etapa, true, team.size()))

	if team.is_empty():
		team.append(_create_unit(1, 1, "cria", true, 0))
	return team


func _create_unit(species_id: int, nivel: int, etapa: String, is_ally: bool, slot_idx: int) -> Dictionary:
	var sp: Dictionary = _core.get_species(species_id)
	var scale: float = 1.0 + float(nivel - 1) * 0.15
	var max_hp: int = maxi(10, int(round(float(sp.get("hp_base", 100)) * scale)))
	var atk: int = maxi(5, int(round(float(sp.get("atk_base", 20)) * scale)))
	var spd: int = maxi(5, int(round(float(sp.get("spd_base", 15)) * scale)))

	return {
		"especie_id": species_id,
		"nombre": str(sp.get("nombre", "Dragón")),
		"sprite_prefijo": str(sp.get("sprite_prefijo", "dragon_terracota")),
		"etapa": etapa,
		"nivel": nivel,
		"hp": max_hp,
		"max_hp": max_hp,
		"atk": atk,
		"spd": spd,
		"elemento_primario_id": int(sp.get("elemento_primario_id", 1)),
		"elemento_secundario_id": sp.get("elemento_secundario_id", null),
		"elementos": sp.get("elementos", [1]),
		"species_data": sp,
		"is_ally": is_ally,
		"slot_index": slot_idx
	}


func _load_current_stage() -> void:
	if not _combat_active or _stage_index >= _stages.size():
		return

	var stage: Dictionary = _stages[_stage_index]
	_enemy_units.clear()
	var enemies_cfg: Array = stage.get("enemigos", [])
	for i: int in range(mini(3, enemies_cfg.size())):
		var e_cfg: Dictionary = enemies_cfg[i]
		var sp_id: int = int(e_cfg.get("especie_id", 2))
		var lvl: int = int(e_cfg.get("nivel", 1))
		var etapa: String = "cria" if lvl <= 1 else ("joven" if lvl == 2 else "adulto")
		_enemy_units.append(_create_unit(sp_id, lvl, etapa, false, i))

	_arena.set_arena_title("Capítulo %d: Sendero Terracota — %s" % [_chapter_id, str(stage.get("titulo", ""))])
	_arena.setup_teams(_ally_units, _enemy_units)
	_arena.set_attack_buttons_enabled(false)
	_arena.set_combat_log("¡Aparece %s! Orden de turnos según velocidad (SPD)." % str(stage.get("titulo", "la oleada")))

	_rebuild_turn_queue()
	_advance_turn()


func _rebuild_turn_queue() -> void:
	_turn_queue.clear()
	for u: Dictionary in _ally_units:
		if int(u.get("hp", 0)) > 0:
			_turn_queue.append(u)
	for u: Dictionary in _enemy_units:
		if int(u.get("hp", 0)) > 0:
			_turn_queue.append(u)

	_turn_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var spd_a: int = int(a.get("spd", 0))
		var spd_b: int = int(b.get("spd", 0))
		if spd_a == spd_b:
			return bool(a.get("is_ally", false)) and not bool(b.get("is_ally", false))
		return spd_a > spd_b
	)
	_turn_cursor = 0


func _advance_turn() -> void:
	if not _combat_active:
		return

	if _all_defeated(_enemy_units):
		_on_stage_cleared()
		return
	if _all_defeated(_ally_units):
		_on_combat_defeat()
		return

	while _turn_cursor < _turn_queue.size():
		var candidate: Dictionary = _turn_queue[_turn_cursor]
		_turn_cursor += 1
		if int(candidate.get("hp", 0)) > 0:
			_start_unit_turn(candidate)
			return

	_rebuild_turn_queue()
	if not _turn_queue.is_empty():
		var first_unit: Dictionary = _turn_queue[0]
		_turn_cursor = 1
		_start_unit_turn(first_unit)


func _start_unit_turn(unit: Dictionary) -> void:
	_active_unit = unit
	var is_ally: bool = bool(unit.get("is_ally", false))
	if is_ally:
		_waiting_player_input = true
		_arena.set_turn_info("Turno Aliado: %s (SPD %d)" % [str(unit.get("nombre", "")), int(unit.get("spd", 0))])
		_arena.set_attack_buttons(_build_attacks_for_unit(unit))
		_arena.set_attack_buttons_enabled(true)
	else:
		_waiting_player_input = false
		_arena.set_attack_buttons_enabled(false)
		_arena.set_turn_info("Turno Enemigo: %s (SPD %d)" % [str(unit.get("nombre", "")), int(unit.get("spd", 0))])
		_execute_enemy_turn(unit)


func _build_attacks_for_unit(unit: Dictionary) -> Array[Dictionary]:
	var attacks: Array[Dictionary] = []
	var elems: Array = unit.get("elementos", [1])
	for elem_var: Variant in elems:
		var elem_id: int = int(elem_var)
		var label: String = str(ELEMENT_ATTACK_NAMES.get(elem_id, "Ataque Elemental"))
		attacks.append({"label": label, "element_id": elem_id, "disabled": false})

	if attacks.size() < 2:
		var prim_id: int = int(unit.get("elemento_primario_id", 1))
		attacks.append({"label": "Embestida Feroz", "element_id": prim_id, "disabled": false})
	return attacks


func _on_arena_attack_selected(_attack_index: int, element_id: int) -> void:
	if not _combat_active or not _waiting_player_input:
		return

	_waiting_player_input = false
	_arena.set_attack_buttons_enabled(false)

	var target_idx: int = _resolve_alive_enemy_index(_arena.get_selected_enemy_index())
	if target_idx == -1:
		_on_stage_cleared()
		return
	_arena.select_enemy_target(target_idx)

	var target: Dictionary = _enemy_units[target_idx]
	_apply_attack(_active_unit, target, element_id)
	_arena.update_unit_hp(false, target_idx, int(target.get("hp", 0)), int(target.get("max_hp", 1)))

	await get_tree().create_timer(0.55).timeout
	if not _combat_active or not is_inside_tree():
		return
	_advance_turn()


func _execute_enemy_turn(enemy: Dictionary) -> void:
	await get_tree().create_timer(0.65).timeout
	if not _combat_active or not is_inside_tree():
		return

	var alive_allies: Array[int] = []
	for i: int in range(_ally_units.size()):
		if int(_ally_units[i].get("hp", 0)) > 0:
			alive_allies.append(i)

	if alive_allies.is_empty():
		_on_combat_defeat()
		return

	var target_idx: int = alive_allies[randi() % alive_allies.size()]
	var target: Dictionary = _ally_units[target_idx]
	var elem_id: int = int(enemy.get("elemento_primario_id", 1))
	_apply_attack(enemy, target, elem_id)
	_arena.update_unit_hp(true, target_idx, int(target.get("hp", 0)), int(target.get("max_hp", 1)))

	await get_tree().create_timer(0.55).timeout
	if not _combat_active or not is_inside_tree():
		return
	_advance_turn()


func _apply_attack(attacker: Dictionary, defender: Dictionary, atk_elem_id: int) -> void:
	var def_species: Dictionary = defender.get("species_data", {})
	var mult: float = _core.get_elemental_multiplier(atk_elem_id, def_species)
	var base_atk: float = float(attacker.get("atk", 20))
	var variance: float = randf_range(0.92, 1.08)
	var dmg: int = maxi(1, int(round(base_atk * mult * variance)))

	var new_hp: int = maxi(0, int(defender.get("hp", 0)) - dmg)
	defender["hp"] = new_hp

	var eff_tag: String = ""
	if mult >= 1.5:
		eff_tag = " ¡Crítico elemental (x%.1f)!" % mult
	elif mult <= 0.6:
		eff_tag = " Poco efectivo (x%.2f)..." % mult

	var atk_name: String = str(ELEMENT_ATTACK_NAMES.get(atk_elem_id, "Ataque"))
	var ko_tag: String = " ¡%s fue derrotado!" % str(defender.get("nombre", "")) if new_hp <= 0 else ""
	_arena.set_combat_log("%s usa %s contra %s (-%d HP).%s%s" % [
		str(attacker.get("nombre", "Dragón")),
		atk_name,
		str(defender.get("nombre", "Objetivo")),
		dmg,
		eff_tag,
		ko_tag
	])


func _resolve_alive_enemy_index(preferred_idx: int) -> int:
	if preferred_idx >= 0 and preferred_idx < _enemy_units.size():
		if int(_enemy_units[preferred_idx].get("hp", 0)) > 0:
			return preferred_idx
	for i: int in range(_enemy_units.size()):
		if int(_enemy_units[i].get("hp", 0)) > 0:
			return i
	return -1


func _all_defeated(units: Array[Dictionary]) -> bool:
	for u: Dictionary in units:
		if int(u.get("hp", 0)) > 0:
			return false
	return true


func _on_stage_cleared() -> void:
	var stage: Dictionary = _stages[_stage_index]
	var reward: Dictionary = stage.get("recompensa", {})
	_accumulated_rewards["oro"] = int(_accumulated_rewards.get("oro", 0)) + int(reward.get("oro", 0))
	_accumulated_rewards["comida"] = int(_accumulated_rewards.get("comida", 0)) + int(reward.get("comida", 0))
	_accumulated_rewards["gemas"] = int(_accumulated_rewards.get("gemas", 0)) + int(reward.get("gemas", 0))

	_stage_index += 1
	if _stage_index < _stages.size():
		_arena.set_combat_log("¡Etapa superada! Preparando siguiente oleada...")
		await get_tree().create_timer(1.0).timeout
		if not _combat_active or not is_inside_tree():
			return
		_load_current_stage()
	else:
		_on_chapter_victory()


func _on_chapter_victory() -> void:
	_combat_active = false
	_waiting_player_input = false
	_arena.set_attack_buttons_enabled(false)

	var oro: int = int(_accumulated_rewards.get("oro", 800))
	var comida: int = int(_accumulated_rewards.get("comida", 400))
	var gemas: int = int(_accumulated_rewards.get("gemas", 5))
	var granted: Dictionary = _core.grant_combat_rewards(oro, comida, gemas, _chapter_id + 1)

	_arena.set_turn_info("¡Victoria en Capítulo %d!" % _chapter_id)
	_arena.set_combat_log("¡Capítulo %d completado! Recompensa: +%d Oro, +%d Comida, +%d Gemas." % [
		_chapter_id, oro, comida, gemas
	])

	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	combat_finished.emit(true, granted)


func _on_combat_defeat() -> void:
	_combat_active = false
	_waiting_player_input = false
	_arena.set_attack_buttons_enabled(false)
	_arena.set_turn_info("Derrota en Capítulo %d" % _chapter_id)
	_arena.set_combat_log("Tu equipo ha caído. Entrena o cruza más dragones e inténtalo de nuevo.")

	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	combat_finished.emit(false, {})


func _on_arena_retreat_requested() -> void:
	_combat_active = false
	_waiting_player_input = false
	combat_finished.emit(false, {})
