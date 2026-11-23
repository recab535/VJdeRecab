extends Node
class_name CombatManager

## Motor de combate 1v1 por turnos con equipo de 3 dragones (1 activo + 2 en banca).
## Gestiona relevos, 4 movimientos por especie, embestidas, camera shake y recompensas.

signal combat_finished(victory: bool, rewards: Dictionary)

const ELEMENT_MOVES: Dictionary = {
	1: ["Golpe Rocoso", "Avalancha", "Terremoto"],
	2: ["Ascua Viva", "Llamarada", "Erupción"],
	3: ["Chorro Veloz", "Oleaje", "Tsunami"],
	4: ["Látigo Hoja", "Tormenta Floral", "Raíz Ancestral"],
	5: ["Chispazo", "Rayo Voltio", "Tempestad"],
	6: ["Soplo Gélido", "Carámbano", "Ventisca"],
	7: ["Garra Férrea", "Cañón Metal", "Impacto Acero"],
	8: ["Sombra Fugaz", "Pulso Umbrío", "Abismo"],
	9: ["Destello Astral", "Pulso Etéreo", "Juicio Legendario"]
}

var _arena: CombatArena = null
var _core: Node = null
var _ally_team: Array[Dictionary] = []
var _enemy_team: Array[Dictionary] = []
var _active_ally_idx: int = 0
var _active_enemy_idx: int = 0
var _chapter_id: int = 1
var _busy: bool = false
var _ended: bool = false


func start_chapter(chapter_id: int, arena: CombatArena) -> void:
	_chapter_id = chapter_id
	_arena = arena
	_core = get_node_or_null("/root/GameCore")
	_ended = false
	_busy = false

	if not _arena.attack_selected.is_connected(_on_attack_selected):
		_arena.attack_selected.connect(_on_attack_selected)
	if not _arena.switch_requested.is_connected(_on_switch_requested):
		_arena.switch_requested.connect(_on_switch_requested)
	if not _arena.retreat_requested.is_connected(_on_retreat_requested):
		_arena.retreat_requested.connect(_on_retreat_requested)

	_build_teams()
	_arena.set_header_info("Capítulo %d — Sendero Terracota (1v1)" % _chapter_id, "Tu Turno")
	_refresh_arena_state()
	_arena.set_combat_log("¡Combate iniciado! Elige un ataque o releva a un dragón de reserva.")


func _build_teams() -> void:
	_ally_team.clear()
	_enemy_team.clear()

	if _core:
		var owned: Array = _core.player_state.get("dragones", [])
		for i: int in range(mini(3, owned.size())):
			var d: Variant = owned[i]
			if d is Dictionary:
				_ally_team.append(_make_unit_from_owned(d))

	if _ally_team.is_empty():
		_ally_team.append(_make_unit_from_species_id(1, 1, 1))

	# Equipo rival de 3 dragones del Capítulo 1
	_enemy_team.append(_make_unit_from_species_id(2, 1, -1))
	_enemy_team.append(_make_unit_from_species_id(5, 1, -2))
	_enemy_team.append(_make_unit_from_species_id(9, 2, -3))

	_active_ally_idx = 0
	_active_enemy_idx = 0


func _make_unit_from_owned(d: Dictionary) -> Dictionary:
	var sp_id: int = int(d.get("especie_id", 1))
	var nivel: int = maxi(1, int(d.get("nivel", 1)))
	var sp: Dictionary = _core.get_species(sp_id) if _core else {}
	var stats: Dictionary = _core.get_dragon_stats(d) if _core else {"hp": 420, "atk": 85, "spd": 40}
	var hp: int = int(stats.get("hp", 420))
	return {
		"uid": int(d.get("uid", 1)),
		"especie_id": sp_id,
		"nombre": str(sp.get("nombre", "Dragón Terracota")),
		"sprite_prefijo": str(sp.get("sprite_prefijo", "dragon_terracota")),
		"etapa": str(d.get("etapa", "cria")),
		"nivel": nivel,
		"hp": hp,
		"max_hp": hp,
		"atk": int(stats.get("atk", 85)),
		"spd": int(stats.get("spd", 40)),
		"species": sp,
		"moves": _build_moves_for_species(sp)
	}


func _make_unit_from_species_id(sp_id: int, nivel: int, uid: int) -> Dictionary:
	var sp: Dictionary = _core.get_species(sp_id) if _core else {}
	var hp_base: int = int(sp.get("hp_base", 310))
	var atk_base: int = int(sp.get("atk_base", 90))
	var spd_base: int = int(sp.get("spd_base", 55))
	var scale_f: float = 1.0 + float(nivel - 1) * 0.14
	var hp: int = roundi(hp_base * scale_f)
	return {
		"uid": uid,
		"especie_id": sp_id,
		"nombre": str(sp.get("nombre", "Dragón Rival")),
		"sprite_prefijo": str(sp.get("sprite_prefijo", "dragon_ascua")),
		"etapa": "cria",
		"nivel": nivel,
		"hp": hp,
		"max_hp": hp,
		"atk": roundi(atk_base * scale_f),
		"spd": roundi(spd_base * scale_f),
		"species": sp,
		"moves": _build_moves_for_species(sp)
	}


func _build_moves_for_species(sp: Dictionary) -> Array[Dictionary]:
	var prim: int = int(sp.get("elemento_primario_id", 1))
	var sec_var: Variant = sp.get("elemento_secundario_id", null)
	var sec: int = int(sec_var) if sec_var != null else prim
	var prim_names: Array = ELEMENT_MOVES.get(prim, ELEMENT_MOVES[1])
	var sec_names: Array = ELEMENT_MOVES.get(sec, ELEMENT_MOVES[1])
	return [
		{"nombre": "Embestida", "elemento_id": prim, "potencia": 28},
		{"nombre": str(prim_names[0]), "elemento_id": prim, "potencia": 38},
		{"nombre": str(sec_names[1]), "elemento_id": sec, "potencia": 48},
		{"nombre": str(prim_names[2]), "elemento_id": prim, "potencia": 60}
	]


func _refresh_arena_state() -> void:
	var ally: Dictionary = _ally_team[_active_ally_idx]
	var enemy: Dictionary = _enemy_team[_active_enemy_idx]
	_arena.set_active_fighters(ally, enemy)
	_arena.update_attack_buttons(ally["moves"], enemy.get("species", {}), _core)
	_arena.update_bench_buttons(_ally_team, _active_ally_idx)
	_arena.set_controls_enabled(not _busy and not _ended)


func _on_attack_selected(attack_idx: int) -> void:
	if _busy or _ended:
		return
	_busy = true
	_arena.set_controls_enabled(false)

	var ally: Dictionary = _ally_team[_active_ally_idx]
	var enemy: Dictionary = _enemy_team[_active_enemy_idx]
	var moves: Array[Dictionary] = ally["moves"]
	var mv: Dictionary = moves[clampi(attack_idx, 0, moves.size() - 1)]

	var elem_id: int = int(mv.get("elemento_id", 1))
	var mult: float = _core.get_elemental_multiplier(elem_id, enemy.get("species", {})) if _core else 1.0
	var dmg: int = maxi(10, roundi((float(ally["atk"]) * (float(mv["potencia"]) / 35.0)) * mult))

	_arena.play_lunge_animation(true)
	enemy["hp"] = maxi(0, int(enemy["hp"]) - dmg)
	_arena.spawn_damage_number(false, dmg, mult)
	_arena.shake_camera(0.24 if mult >= 1.9 else 0.16, 0.22)
	_arena.update_hp_bars(int(ally["hp"]), int(ally["max_hp"]), int(enemy["hp"]), int(enemy["max_hp"]))
	_arena.set_combat_log("%s usó %s (-%d HP)." % [str(ally["nombre"]), str(mv["nombre"]), dmg])

	await get_tree().create_timer(0.6).timeout
	if _ended or not is_instance_valid(_arena):
		return

	if int(enemy["hp"]) <= 0:
		var next_enemy: int = _find_next_alive(_enemy_team)
		if next_enemy == -1:
			await _finish_battle(true)
			return
		_active_enemy_idx = next_enemy
		_arena.set_combat_log("¡%s derrotado! Entra %s." % [str(enemy["nombre"]), str(_enemy_team[_active_enemy_idx]["nombre"])])
		_refresh_arena_state()
		await get_tree().create_timer(0.45).timeout
		_busy = false
		_arena.set_controls_enabled(true)
		return

	await _execute_enemy_turn()


func _on_switch_requested(bench_team_idx: int) -> void:
	if _busy or _ended:
		return
	if bench_team_idx < 0 or bench_team_idx >= _ally_team.size():
		return
	if int(_ally_team[bench_team_idx]["hp"]) <= 0:
		return

	_busy = true
	_arena.set_controls_enabled(false)
	_active_ally_idx = bench_team_idx
	_refresh_arena_state()
	_arena.set_combat_log("¡Relevo! %s entra a la arena." % str(_ally_team[_active_ally_idx]["nombre"]))

	await get_tree().create_timer(0.55).timeout
	if _ended or not is_instance_valid(_arena):
		return
	await _execute_enemy_turn()


func _execute_enemy_turn() -> void:
	var ally: Dictionary = _ally_team[_active_ally_idx]
	var enemy: Dictionary = _enemy_team[_active_enemy_idx]
	var moves: Array[Dictionary] = enemy["moves"]
	var mv: Dictionary = moves[randi() % moves.size()]

	var elem_id: int = int(mv.get("elemento_id", 1))
	var mult: float = _core.get_elemental_multiplier(elem_id, ally.get("species", {})) if _core else 1.0
	var dmg: int = maxi(8, roundi((float(enemy["atk"]) * (float(mv["potencia"]) / 38.0)) * mult))

	_arena.set_header_info("Capítulo %d — Sendero Terracota (1v1)" % _chapter_id, "Turno Enemigo")
	_arena.play_lunge_animation(false)
	ally["hp"] = maxi(0, int(ally["hp"]) - dmg)
	_arena.spawn_damage_number(true, dmg, mult)
	_arena.shake_camera(0.18, 0.2)
	_arena.update_hp_bars(int(ally["hp"]), int(ally["max_hp"]), int(enemy["hp"]), int(enemy["max_hp"]))
	_arena.set_combat_log("%s respondió con %s (-%d HP)." % [str(enemy["nombre"]), str(mv["nombre"]), dmg])

	await get_tree().create_timer(0.6).timeout
	if _ended or not is_instance_valid(_arena):
		return

	if int(ally["hp"]) <= 0:
		var next_ally: int = _find_next_alive(_ally_team)
		if next_ally == -1:
			await _finish_battle(false)
			return
		_active_ally_idx = next_ally
		_arena.set_combat_log("¡%s cayó! Entra %s." % [str(ally["nombre"]), str(_ally_team[_active_ally_idx]["nombre"])])
		_refresh_arena_state()

	_arena.update_bench_buttons(_ally_team, _active_ally_idx)
	_arena.set_header_info("Capítulo %d — Sendero Terracota (1v1)" % _chapter_id, "Tu Turno")
	_busy = false
	_arena.set_controls_enabled(true)


func _find_next_alive(team: Array[Dictionary]) -> int:
	for i: int in range(team.size()):
		if int(team[i].get("hp", 0)) > 0:
			return i
	return -1


func _finish_battle(victory: bool) -> void:
	_ended = true
	_busy = true
	_arena.set_controls_enabled(false)
	var rewards: Dictionary = {}
	if victory:
		if _core:
			rewards = _core.grant_combat_rewards(800, 400, 5, _chapter_id + 1)
		else:
			rewards = {"oro": 800, "comida": 400, "gemas": 5}
		_arena.set_combat_log("¡VICTORIA! Derrotaste a los 3 dragones rivales (+800 Oro, +400 Comida, +5 Gemas).")
	else:
		_arena.set_combat_log("Derrota... Alimenta a tus dragones e inténtalo de nuevo.")

	await get_tree().create_timer(1.2).timeout
	combat_finished.emit(victory, rewards)


func _on_retreat_requested() -> void:
	if _ended:
		return
	_ended = true
	combat_finished.emit(false, {})
