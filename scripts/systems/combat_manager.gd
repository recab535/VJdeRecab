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
var _chapter_data: Dictionary = {}
var _busy: bool = false
var _ended: bool = false


func start_chapter(chapter_id: int, arena: CombatArena) -> void:
	var fallback_data: Dictionary = {
		"capitulo": chapter_id,
		"arco": "Tierra",
		"especie_requerida_id": 1,
		"oro": 350 + chapter_id * 180,
		"comida": 180 + chapter_id * 95,
		"gemas": 5 if (chapter_id == 1 or chapter_id % 5 == 0) else 1,
		"exp": 60 + chapter_id * 25,
		"enemigos": [
			{"especie_id": 2, "nivel": 1},
			{"especie_id": 5, "nivel": 1},
			{"especie_id": 9, "nivel": 2}
		]
	}
	start_chapter_data(fallback_data, arena)


func start_chapter_data(chapter_data: Dictionary, arena: CombatArena) -> void:
	_chapter_data = chapter_data
	_chapter_id = int(chapter_data.get("capitulo", 1))
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
	var arco: String = str(_chapter_data.get("arco", "Tierra"))
	_arena.set_header_info("Capítulo %d — Arco %s (1v1)" % [_chapter_id, arco], "Tu Turno")
	_refresh_arena_state()

	var ally: Dictionary = _ally_team[_active_ally_idx]
	var b_mult: float = float(ally.get("booster_mult", 1.0))
	var t_lvl: int = int(ally.get("entrenamiento_nivel", 0))
	var bonus_txt: String = ""
	if b_mult > 1.0:
		bonus_txt += " [Tótem ×%.0f]" % b_mult
	if t_lvl > 0:
		bonus_txt += " [Entrenamiento +%d%%]" % (t_lvl * 10)
	_arena.set_combat_log("¡Combate directo! %s lidera tu equipo%s." % [str(ally.get("nombre", "Dragón")), bonus_txt])


func _build_teams() -> void:
	_ally_team.clear()
	_enemy_team.clear()

	var req_species_id: int = int(_chapter_data.get("especie_requerida_id", 1))

	if _core:
		var owned: Array = _core.player_state.get("dragones", [])
		var used_uids: Dictionary = {}
		# 1. Colocar primero el dragón obligatorio del capítulo
		for d: Variant in owned:
			if d is Dictionary and int(d.get("especie_id", 0)) == req_species_id:
				_ally_team.append(_make_unit_from_owned(d))
				used_uids[int(d.get("uid", -1))] = true
				break
		# 2. Completar hasta 3 dragones (1 activo + 2 en banca)
		for d: Variant in owned:
			if _ally_team.size() >= 3:
				break
			if d is Dictionary and not used_uids.has(int(d.get("uid", -1))):
				_ally_team.append(_make_unit_from_owned(d))
				used_uids[int(d.get("uid", -1))] = true

	if _ally_team.is_empty():
		_ally_team.append(_make_unit_from_species_id(req_species_id, 1, 1))

	var enemies_cfg: Array = _chapter_data.get("enemigos", [])
	if enemies_cfg.is_empty():
		enemies_cfg = [{"especie_id": 2, "nivel": 1}, {"especie_id": 5, "nivel": 1}, {"especie_id": 9, "nivel": 2}]
	for i: int in range(enemies_cfg.size()):
		var ec: Dictionary = enemies_cfg[i]
		_enemy_team.append(_make_unit_from_species_id(int(ec.get("especie_id", 2)), int(ec.get("nivel", 1)), -(i + 1)))

	_active_ally_idx = 0
	_active_enemy_idx = 0


func _make_unit_from_owned(d: Dictionary) -> Dictionary:
	var sp_id: int = int(d.get("especie_id", 1))
	var nivel: int = maxi(1, int(d.get("nivel", 1)))
	var sp: Dictionary = _core.get_species(sp_id) if _core else {}
	var stats: Dictionary = _core.get_dragon_stats(d) if _core else {"hp": 420, "atk": 85, "spd": 40, "booster_mult": 1.0, "entrenamiento_nivel": 0, "rango_nombre": "", "rango_mult": 1.0}
	var hp: int = int(stats.get("hp", 420))
	var train_lvl: int = int(stats.get("entrenamiento_nivel", 0))
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
		"booster_mult": float(stats.get("booster_mult", 1.0)),
		"entrenamiento_nivel": train_lvl,
		"rango_nombre": str(stats.get("rango_nombre", "")),
		"rango_mult": float(stats.get("rango_mult", 1.0)),
		"species": sp,
		"moves": _build_moves_for_species(sp, train_lvl)
	}


func _make_unit_from_species_id(sp_id: int, nivel: int, uid: int) -> Dictionary:
	var sp: Dictionary = _core.get_species(sp_id) if _core else {}
	var hp_base: float = float(sp.get("hp_base", 310))
	var atk_base: float = float(sp.get("atk_base", 90))
	var spd_base: float = float(sp.get("spd_base", 55))
	var d_lvl: float = float(maxi(1, nivel) - 1)
	var hp_poly: float = 1.0 + 0.12 * d_lvl + 0.015 * d_lvl * d_lvl
	var atk_poly: float = 1.0 + 0.10 * d_lvl + 0.012 * d_lvl * d_lvl
	var spd_poly: float = 1.0 + 0.06 * d_lvl
	var hp: int = roundi(hp_base * hp_poly)
	var etapa_rival: String = "adulto" if nivel >= 7 else ("joven" if nivel >= 4 else "cria")
	return {
		"uid": uid,
		"especie_id": sp_id,
		"nombre": str(sp.get("nombre", "Dragón Rival")),
		"sprite_prefijo": str(sp.get("sprite_prefijo", "dragon_ascua")),
		"etapa": etapa_rival,
		"nivel": nivel,
		"hp": hp,
		"max_hp": hp,
		"atk": roundi(atk_base * atk_poly),
		"spd": roundi(spd_base * spd_poly),
		"entrenamiento_nivel": 0,
		"rango_nombre": "",
		"rango_mult": 1.0,
		"species": sp,
		"moves": _build_moves_for_species(sp, 0)
	}


func _build_moves_for_species(sp: Dictionary, train_lvl: int = 0) -> Array[Dictionary]:
	var prim: int = int(sp.get("elemento_primario_id", 1))
	var sec_var: Variant = sp.get("elemento_secundario_id", null)
	var sec: int = int(sec_var) if sec_var != null else prim
	var prim_names: Array = ELEMENT_MOVES.get(prim, ELEMENT_MOVES[1])
	var sec_names: Array = ELEMENT_MOVES.get(sec, ELEMENT_MOVES[1])
	var train_bonus: int = train_lvl * 6
	var tag: String = "+" if train_lvl > 0 else ""
	return [
		{"nombre": "Embestida", "elemento_id": prim, "potencia": 30},
		{"nombre": str(prim_names[0]) + tag, "elemento_id": prim, "potencia": 40 + train_bonus},
		{"nombre": str(sec_names[1]) + tag, "elemento_id": sec, "potencia": 52 + train_bonus},
		{"nombre": str(prim_names[2]) + tag, "elemento_id": prim, "potencia": 65 + train_bonus}
	]


func _calculate_damage_2012(attacker: Dictionary, move: Dictionary, elemental_mult: float) -> Dictionary:
	# 5% probabilidad de fallo clásica + varianza RNG(0.90, 1.10)
	if randf() < 0.05:
		return {"missed": true, "damage": 0}
	var move_power: float = float(move.get("potencia", 40))
	var variance: float = randf_range(0.90, 1.10)
	var raw_dmg: float = float(attacker.get("atk", 80)) * (move_power / 40.0) * elemental_mult * variance
	return {"missed": false, "damage": maxi(10, roundi(raw_dmg))}


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
	var calc: Dictionary = _calculate_damage_2012(ally, mv, mult)

	_arena.play_lunge_animation(true)
	var am: Node = get_node_or_null("/root/AudioManager")
	if bool(calc["missed"]):
		if am and am.has_method("play_sfx"):
			am.call("play_sfx", "click")
		if _arena.has_method("spawn_miss_text"):
			_arena.spawn_miss_text(false)
		_arena.set_combat_log("¡%s falló %s!" % [str(ally["nombre"]), str(mv["nombre"])])
	else:
		var dmg: int = int(calc["damage"])
		if am and am.has_method("play_sfx"):
			am.call("play_sfx", "crit" if mult >= 1.9 else "attack")
		if _arena.has_method("play_attack_vfx"):
			_arena.play_attack_vfx(true, elem_id, mult)
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
		if _ended or not is_instance_valid(_arena):
			return
		_busy = false
		_arena.set_controls_enabled(true)
		return

	await _execute_enemy_turn()


func _on_switch_requested(bench_team_idx: int) -> void:
	if _busy or _ended:
		return
	if bench_team_idx < 0 or bench_team_idx >= _ally_team.size() or bench_team_idx == _active_ally_idx:
		return
	if int(_ally_team[bench_team_idx]["hp"]) <= 0:
		return

	_busy = true
	_arena.set_controls_enabled(false)
	var am_sw: Node = get_node_or_null("/root/AudioManager")
	if am_sw and am_sw.has_method("play_sfx"):
		am_sw.call("play_sfx", "click")
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
	var calc: Dictionary = _calculate_damage_2012(enemy, mv, mult)

	var arco: String = str(_chapter_data.get("arco", "Tierra"))
	_arena.set_header_info("Capítulo %d — Arco %s (1v1)" % [_chapter_id, arco], "Turno Enemigo")
	_arena.play_lunge_animation(false)
	var am_en: Node = get_node_or_null("/root/AudioManager")
	if bool(calc["missed"]):
		if am_en and am_en.has_method("play_sfx"):
			am_en.call("play_sfx", "click")
		if _arena.has_method("spawn_miss_text"):
			_arena.spawn_miss_text(true)
		_arena.set_combat_log("¡%s falló %s!" % [str(enemy["nombre"]), str(mv["nombre"])])
	else:
		var dmg: int = int(calc["damage"])
		if am_en and am_en.has_method("play_sfx"):
			am_en.call("play_sfx", "crit" if mult >= 1.9 else "attack")
		if _arena.has_method("play_attack_vfx"):
			_arena.play_attack_vfx(false, elem_id, mult)
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
	_arena.set_header_info("Capítulo %d — Arco %s (1v1)" % [_chapter_id, arco], "Tu Turno")
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
		var am_win: Node = get_node_or_null("/root/AudioManager")
		if am_win and am_win.has_method("play_sfx"):
			am_win.call("play_sfx", "victory")
		var oro_r: int = int(_chapter_data.get("oro", 800))
		var comida_r: int = int(_chapter_data.get("comida", 400))
		var gemas_r: int = int(_chapter_data.get("gemas", 5))
		var exp_r: int = int(_chapter_data.get("exp", 85))
		if _core and _core.has_method("complete_campaign_chapter"):
			rewards = _core.complete_campaign_chapter(_chapter_id, oro_r, comida_r, gemas_r, exp_r)
			var ally_uids: Array = []
			for u: Dictionary in _ally_team:
				if int(u.get("uid", -1)) > 0:
					ally_uids.append(int(u["uid"]))
			if _core.has_method("record_dragon_combat_wins"):
				_core.record_dragon_combat_wins(ally_uids)
		else:
			rewards = {"oro": oro_r, "comida": comida_r, "gemas": gemas_r, "exp": exp_r}
		_arena.set_combat_log("¡VICTORIA Cap. %d! +%d Oro, +%d Comida, +%d Gemas, +%d EXP." % [_chapter_id, oro_r, comida_r, gemas_r, exp_r])
	else:
		var am_lose: Node = get_node_or_null("/root/AudioManager")
		if am_lose and am_lose.has_method("play_sfx"):
			am_lose.call("play_sfx", "defeat")
		_arena.set_combat_log("Derrota... Alimenta o entrena tus dragones e inténtalo de nuevo.")

	await get_tree().create_timer(1.2).timeout
	combat_finished.emit(victory, rewards)


func _on_retreat_requested() -> void:
	if _ended:
		return
	_ended = true
	combat_finished.emit(false, {})
