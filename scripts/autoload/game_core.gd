extends Node

## Autoload central: carga el catálogo oficial (data/especies_68.json),
## gestiona la persistencia en user://savegame.json, generación pasiva de oro,
## construcción de hábitats, cruces y nido.

const CATALOG_PATH: String = "res://data/especies_68.json"
const SAVE_PATH: String = "user://savegame.json"
const HABITAT_COST_ORO: int = 250
const PASSIVE_TICK_SEC: float = 5.0
const MAX_DRAGON_LEVEL: int = 10

signal catalog_loaded(total_species: int)
signal save_loaded
signal resources_changed(oro: int, comida: int, gemas: int)
signal dragon_leveled_up(dragon_uid: int, new_nivel: int, new_etapa: String)
signal nest_updated
signal breeding_started(egg: Dictionary)

var elementos_by_id: Dictionary = {}
var especies_by_id: Dictionary = {}
var multiplicadores: Dictionary = {}
var reglas_cruce: Dictionary = {}
var player_state: Dictionary = {}

var _passive_accum_sec: float = 0.0
var _gold_fraction: float = 0.0


func _ready() -> void:
	_load_catalog()
	load_game()


func _process(delta: float) -> void:
	_tick_nest_incubation(delta)
	_passive_accum_sec += delta
	if _passive_accum_sec >= PASSIVE_TICK_SEC:
		var elapsed: float = _passive_accum_sec
		_passive_accum_sec = 0.0
		_tick_passive_gold(elapsed)


func _tick_nest_incubation(delta: float) -> void:
	var huevos: Array = player_state.get("nido_huevos", [])
	if huevos.is_empty():
		return

	var completed_any: bool = false
	for egg_var: Variant in huevos:
		if not (egg_var is Dictionary):
			continue
		var egg: Dictionary = egg_var
		if bool(egg.get("listo", false)):
			continue
		var rem: float = maxf(0.0, float(egg.get("tiempo_restante_seg", 0.0)) - delta)
		egg["tiempo_restante_seg"] = rem
		if rem <= 0.0:
			egg["listo"] = true
			completed_any = true

	if completed_any:
		save_game()
		nest_updated.emit()


func _tick_passive_gold(elapsed_sec: float) -> void:
	var oro_por_min: float = 0.0
	for d: Variant in player_state.get("dragones", []):
		if d is Dictionary:
			oro_por_min += get_dragon_gold_per_minute(d)

	if oro_por_min <= 0.0:
		return

	_gold_fraction += oro_por_min * (elapsed_sec / 60.0)
	var earned: int = int(floor(_gold_fraction))
	if earned > 0:
		_gold_fraction -= float(earned)
		add_oro(earned)


func _load_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("[GameCore] No se encontró el catálogo en: " + CATALOG_PATH)
		return

	var file: FileAccess = FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("[GameCore] Error al abrir: " + CATALOG_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[GameCore] Formato JSON inválido en: " + CATALOG_PATH)
		return

	var data: Dictionary = parsed
	reglas_cruce = data.get("reglas_cruce", {})
	multiplicadores = data.get("multiplicadores_elementales", {})

	elementos_by_id.clear()
	for elem: Variant in data.get("elementos", []):
		if elem is Dictionary:
			elementos_by_id[int(elem.get("id", 0))] = elem

	especies_by_id.clear()
	for sp: Variant in data.get("especies", []):
		if sp is Dictionary:
			especies_by_id[int(sp.get("id", 0))] = sp

	catalog_loaded.emit(especies_by_id.size())


func _create_default_state() -> Dictionary:
	return {
		"version": "1.0.0",
		"nivel_jugador": 1,
		"capitulo_pve_actual": 1,
		"tutorial_completado": false,
		"recursos": {
			"oro": 1000,
			"comida": 500,
			"gemas": 25
		},
		"islas_desbloqueadas": [1],
		"estructuras": [
			{
				"id": 1,
				"slot_index": 0,
				"elemento_id": 1
			}
		],
		"nido_huevos": [],
		"dragones": [
			{
				"uid": 1,
				"especie_id": 1,
				"nivel": 1,
				"etapa": "cria",
				"xp": 0
			},
			{
				"uid": 2,
				"especie_id": 2,
				"nivel": 1,
				"etapa": "cria",
				"xp": 0
			}
		]
	}


func is_tutorial_completed() -> bool:
	return bool(player_state.get("tutorial_completado", false))


func complete_tutorial() -> void:
	player_state["tutorial_completado"] = true
	save_game()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		player_state = _create_default_state()
		save_game()
		save_loaded.emit()
		_emit_resources()
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		player_state = _create_default_state()
		save_loaded.emit()
		_emit_resources()
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		player_state = _create_default_state()
	else:
		player_state = parsed
		if not player_state.has("nido_huevos"):
			player_state["nido_huevos"] = []
		else:
			_normalize_nest_eggs()
		if not player_state.has("estructuras"):
			player_state["estructuras"] = []
		if not player_state.has("islas_desbloqueadas"):
			player_state["islas_desbloqueadas"] = [1]
		if not player_state.has("tutorial_completado"):
			player_state["tutorial_completado"] = false

	save_loaded.emit()
	_emit_resources()


func save_game() -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[GameCore] No se pudo escribir en: " + SAVE_PATH)
		return false
	file.store_string(JSON.stringify(player_state, "\t"))
	return true


func add_oro(amount: int) -> void:
	var res: Dictionary = player_state.get("recursos", {})
	res["oro"] = int(res.get("oro", 0)) + amount
	player_state["recursos"] = res
	save_game()
	_emit_resources()


func grant_combat_rewards(oro: int, comida: int, gemas: int = 0, next_chapter: int = -1) -> Dictionary:
	var res: Dictionary = get_resources()
	res["oro"] = int(res.get("oro", 0)) + maxi(0, oro)
	res["comida"] = int(res.get("comida", 0)) + maxi(0, comida)
	res["gemas"] = int(res.get("gemas", 0)) + maxi(0, gemas)
	player_state["recursos"] = res

	var current_chapter: int = int(player_state.get("capitulo_pve_actual", 1))
	if next_chapter > current_chapter:
		player_state["capitulo_pve_actual"] = next_chapter

	save_game()
	_emit_resources()
	return {
		"oro": maxi(0, oro),
		"comida": maxi(0, comida),
		"gemas": maxi(0, gemas),
		"capitulo_pve_actual": int(player_state.get("capitulo_pve_actual", 1))
	}


func get_elemental_multiplier(atk_elem_id: int, def_species: Dictionary) -> float:
	var atk_key: String = str(atk_elem_id)
	var row: Dictionary = multiplicadores.get(atk_key, {})
	if row.is_empty():
		return 1.0

	var prim_id: int = int(def_species.get("elemento_primario_id", 1))
	var mult: float = float(row.get(str(prim_id), 1.0))

	var sec_var: Variant = def_species.get("elemento_secundario_id", null)
	if sec_var != null:
		var sec_id: int = int(sec_var)
		if sec_id > 0:
			mult *= float(row.get(str(sec_id), 1.0))

	return mult


func build_habitat(slot_index: int, elemento_id: int = 1, cost_oro: int = HABITAT_COST_ORO) -> Dictionary:
	var res: Dictionary = get_resources()
	var oro_actual: int = int(res.get("oro", 0))
	if oro_actual < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [oro_actual, cost_oro]}

	var estructuras: Array = player_state.get("estructuras", [])
	for est: Variant in estructuras:
		if est is Dictionary and int(est.get("slot_index", -1)) == slot_index:
			return {"ok": false, "msg": "El espacio %d ya tiene un hábitat." % (slot_index + 1)}

	var new_id: int = estructuras.size() + 1
	var nueva: Dictionary = {
		"id": new_id,
		"slot_index": slot_index,
		"elemento_id": elemento_id
	}
	estructuras.append(nueva)
	player_state["estructuras"] = estructuras
	res["oro"] = oro_actual - cost_oro
	player_state["recursos"] = res
	save_game()
	_emit_resources()
	return {"ok": true, "estructura": nueva, "msg": "Hábitat construido en espacio %d (-%d Oro)." % [slot_index + 1, cost_oro]}


func buy_egg(especie_id: int, cost_oro: int) -> Dictionary:
	var res: Dictionary = get_resources()
	var oro_actual: int = int(res.get("oro", 0))
	if oro_actual < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [oro_actual, cost_oro]}

	var huevos: Array = player_state.get("nido_huevos", [])
	if huevos.size() >= 3:
		return {"ok": false, "msg": "El Nido está lleno (máx. 3 huevos)."}

	var sp: Dictionary = get_species(especie_id)
	var egg: Dictionary = {
		"especie_id": especie_id,
		"nombre": str(sp.get("nombre", "Dragón")),
		"tiempo_incubacion_seg": int(sp.get("tiempo_incubacion_seg", 300)),
		"restante_seg": 5.0
	}
	huevos.append(egg)
	player_state["nido_huevos"] = huevos
	res["oro"] = oro_actual - cost_oro
	player_state["recursos"] = res
	save_game()
	_emit_resources()
	return {"ok": true, "msg": "Huevo de %s comprado y enviado al Nido (-%d Oro)." % [egg["nombre"], cost_oro]}


func buy_food_farm(cost_oro: int = 300) -> Dictionary:
	var res: Dictionary = get_resources()
	var oro_actual: int = int(res.get("oro", 0))
	if oro_actual < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [oro_actual, cost_oro]}
	res["oro"] = oro_actual - cost_oro
	res["comida"] = int(res.get("comida", 0)) + 150
	player_state["recursos"] = res
	save_game()
	_emit_resources()
	return {"ok": true, "msg": "¡Granja de Comida cosechada! +150 Comida (-%d Oro)." % cost_oro}


func is_island_unlocked(island_id: int) -> bool:
	var unlocked: Array = player_state.get("islas_desbloqueadas", [1])
	for item: Variant in unlocked:
		if int(item) == island_id:
			return true
	return false


func unlock_island(island_id: int, cost_oro: int = 2500) -> Dictionary:
	if not player_state.has("islas_desbloqueadas"):
		player_state["islas_desbloqueadas"] = [1]

	if is_island_unlocked(island_id):
		return {"ok": false, "msg": "La isla %d ya está desbloqueada." % island_id}

	var res: Dictionary = get_resources()
	var oro_actual: int = int(res.get("oro", 0))
	if oro_actual < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [oro_actual, cost_oro]}

	var unlocked: Array = player_state.get("islas_desbloqueadas", [1])
	unlocked.append(island_id)
	player_state["islas_desbloqueadas"] = unlocked

	res["oro"] = oro_actual - cost_oro
	player_state["recursos"] = res
	save_game()
	_emit_resources()
	return {
		"ok": true,
		"island_id": island_id,
		"msg": "¡Isla %d desbloqueada (-%d Oro)! 4 nuevos espacios disponibles." % [island_id, cost_oro]
	}


func _normalize_nest_eggs() -> void:
	var huevos: Array = player_state.get("nido_huevos", [])
	for egg_var: Variant in huevos:
		if not (egg_var is Dictionary):
			continue
		var egg: Dictionary = egg_var
		var total_sec: int = maxi(5, int(egg.get("tiempo_incubacion_seg", 300)))
		egg["tiempo_incubacion_seg"] = total_sec
		if not egg.has("tiempo_restante_seg"):
			egg["tiempo_restante_seg"] = float(total_sec)
		var rem: float = maxf(0.0, float(egg.get("tiempo_restante_seg", total_sec)))
		egg["tiempo_restante_seg"] = rem
		egg["listo"] = bool(egg.get("listo", false)) or rem <= 0.0


func get_nest_eggs() -> Array:
	return player_state.get("nido_huevos", [])


func get_breeding_preview(parent_a_id: int, parent_b_id: int) -> Dictionary:
	var candidates: Array[int] = _get_breeding_candidates(parent_a_id, parent_b_id)
	var min_time: int = 0
	var max_time: int = 0
	for sp_id: int in candidates:
		var sp: Dictionary = get_species(sp_id)
		var t: int = maxi(5, int(sp.get("tiempo_incubacion_seg", 300)))
		if min_time == 0 or t < min_time:
			min_time = t
		if t > max_time:
			max_time = t
	return {
		"candidates": candidates,
		"min_time_seg": min_time,
		"max_time_seg": max_time
	}


func start_breeding(parent_a_id: int, parent_b_id: int) -> Dictionary:
	var huevos: Array = player_state.get("nido_huevos", [])
	if huevos.size() >= 3:
		return {"ok": false, "msg": "El Nido está lleno (máx. 3 huevos). Eclosiona uno primero."}

	if not especies_by_id.has(parent_a_id) or not especies_by_id.has(parent_b_id):
		return {"ok": false, "msg": "Selecciona dos especies válidas para cruzar."}

	var result_id: int = _resolve_breeding_species(parent_a_id, parent_b_id)
	var sp: Dictionary = get_species(result_id)
	var total_sec: int = maxi(5, int(sp.get("tiempo_incubacion_seg", 300)))
	var egg: Dictionary = {
		"especie_id": result_id,
		"nombre": str(sp.get("nombre", "Dragón")),
		"tiempo_incubacion_seg": total_sec,
		"tiempo_restante_seg": float(total_sec),
		"padre_a_id": parent_a_id,
		"padre_b_id": parent_b_id,
		"listo": false
	}
	huevos.append(egg)
	player_state["nido_huevos"] = huevos
	save_game()
	breeding_started.emit(egg)
	nest_updated.emit()
	return {"ok": true, "egg": egg, "msg": "Cruce iniciado: huevo de %s enviado al Nido." % egg["nombre"]}


func accelerate_egg(egg_index: int, cost_gemas: int = 1) -> Dictionary:
	var huevos: Array = player_state.get("nido_huevos", [])
	if egg_index < 0 or egg_index >= huevos.size():
		return {"ok": false, "msg": "Huevo no encontrado en el Nido."}

	var egg: Dictionary = huevos[egg_index]
	if bool(egg.get("listo", false)):
		return {"ok": false, "msg": "Este huevo ya está listo para eclosionar."}

	var res: Dictionary = get_resources()
	var gemas_actuales: int = int(res.get("gemas", 0))
	if gemas_actuales < cost_gemas:
		return {"ok": false, "msg": "Gemas insuficientes (%d/%d)." % [gemas_actuales, cost_gemas]}

	res["gemas"] = gemas_actuales - cost_gemas
	player_state["recursos"] = res
	egg["tiempo_restante_seg"] = 0.0
	egg["listo"] = true
	huevos[egg_index] = egg
	player_state["nido_huevos"] = huevos

	save_game()
	_emit_resources()
	nest_updated.emit()
	return {
		"ok": true,
		"egg": egg,
		"msg": "¡%s listo para eclosionar (-%d Gema)!" % [str(egg.get("nombre", "Huevo")), cost_gemas]
	}


func hatch_egg_at(egg_index: int) -> Dictionary:
	var huevos: Array = player_state.get("nido_huevos", [])
	if huevos.is_empty():
		return {"ok": false, "msg": "No hay huevos en el Nido. Usa Cruce primero."}
	if egg_index < 0 or egg_index >= huevos.size():
		return {"ok": false, "msg": "Huevo inválido en el Nido."}

	var egg: Dictionary = huevos[egg_index]
	if not bool(egg.get("listo", false)):
		return {"ok": false, "msg": "El huevo de %s aún está incubando." % str(egg.get("nombre", "Dragón"))}

	huevos.remove_at(egg_index)
	player_state["nido_huevos"] = huevos

	var dragones: Array = player_state.get("dragones", [])
	var max_uid: int = 0
	for d_var: Variant in dragones:
		if d_var is Dictionary:
			max_uid = maxi(max_uid, int(d_var.get("uid", 0)))
	var next_uid: int = max_uid + 1

	var new_dragon: Dictionary = {
		"uid": next_uid,
		"especie_id": int(egg.get("especie_id", 1)),
		"nivel": 1,
		"etapa": "cria",
		"xp": 0
	}
	dragones.append(new_dragon)
	player_state["dragones"] = dragones
	save_game()
	nest_updated.emit()
	return {"ok": true, "dragon": new_dragon, "nombre": str(egg.get("nombre", "Dragón")), "msg": "¡Eclosionó %s!" % str(egg.get("nombre", "Dragón"))}


func hatch_next_egg() -> Dictionary:
	var huevos: Array = player_state.get("nido_huevos", [])
	if huevos.is_empty():
		return {"ok": false, "msg": "No hay huevos en el Nido. Usa Cruce primero."}

	for i: int in range(huevos.size()):
		var egg_var: Variant = huevos[i]
		if egg_var is Dictionary and bool(egg_var.get("listo", false)):
			return hatch_egg_at(i)

	return hatch_egg_at(0)


func _get_breeding_candidates(parent_a_id: int, parent_b_id: int) -> Array[int]:
	var sp_a: Dictionary = get_species(parent_a_id)
	var sp_b: Dictionary = get_species(parent_b_id)
	var elem_a: int = int(sp_a.get("elemento_primario_id", 1))
	var elem_b: int = int(sp_b.get("elemento_primario_id", 1))

	if elem_a == elem_b:
		return [elem_a]

	var candidates: Array[int] = []
	for sp: Variant in especies_by_id.values():
		if sp is Dictionary:
			var p: int = int(sp.get("elemento_primario_id", 0))
			var s: Variant = sp.get("elemento_secundario_id", null)
			if s != null and ((p == elem_a and int(s) == elem_b) or (p == elem_b and int(s) == elem_a)):
				candidates.append(int(sp.get("id", 1)))

	if candidates.is_empty():
		candidates.append(elem_a)
	return candidates


func _resolve_breeding_species(parent_a_id: int, parent_b_id: int) -> int:
	var candidates: Array[int] = _get_breeding_candidates(parent_a_id, parent_b_id)
	return candidates[randi() % candidates.size()]


func get_species(species_id: int) -> Dictionary:
	return especies_by_id.get(species_id, {})


func get_element(element_id: int) -> Dictionary:
	return elementos_by_id.get(element_id, {})


func get_feed_cost(nivel: int) -> int:
	return 50 + (maxi(1, nivel) - 1) * 50


func get_stage_for_level(nivel: int) -> String:
	if nivel >= 7:
		return "adulto"
	if nivel >= 4:
		return "joven"
	return "cria"


func get_dragon_gold_per_minute(dragon_data: Dictionary) -> float:
	var sp: Dictionary = get_species(int(dragon_data.get("especie_id", 0)))
	var base_oro: float = float(sp.get("oro_por_minuto", 0))
	var nivel: int = maxi(1, int(dragon_data.get("nivel", 1)))
	return base_oro * (1.0 + float(nivel - 1) * 0.25)


func get_dragon_stats(dragon_data: Dictionary) -> Dictionary:
	var sp: Dictionary = get_species(int(dragon_data.get("especie_id", 1)))
	var nivel: int = maxi(1, int(dragon_data.get("nivel", 1)))
	var scale: float = 1.0 + float(nivel - 1) * 0.15
	return {
		"hp": maxi(10, int(round(float(sp.get("hp_base", 100)) * scale))),
		"atk": maxi(5, int(round(float(sp.get("atk_base", 20)) * scale))),
		"spd": maxi(5, int(round(float(sp.get("spd_base", 15)) * scale))),
		"oro_por_min": int(round(get_dragon_gold_per_minute(dragon_data)))
	}


func get_dragon_by_uid(dragon_uid: int) -> Dictionary:
	for d: Variant in player_state.get("dragones", []):
		if d is Dictionary and int(d.get("uid", -1)) == dragon_uid:
			return d
	return {}


func feed_dragon(dragon_uid: int) -> Dictionary:
	var dragones: Array = player_state.get("dragones", [])
	var target_idx: int = -1
	for i: int in range(dragones.size()):
		var item: Variant = dragones[i]
		if item is Dictionary and int(item.get("uid", -1)) == dragon_uid:
			target_idx = i
			break

	if target_idx == -1:
		return {"ok": false, "msg": "Dragón no encontrado (UID %d)." % dragon_uid}

	var d: Dictionary = dragones[target_idx]
	var sp: Dictionary = get_species(int(d.get("especie_id", 1)))
	var nombre: String = str(sp.get("nombre", "Dragón"))
	var nivel_actual: int = maxi(1, int(d.get("nivel", 1)))

	if nivel_actual >= MAX_DRAGON_LEVEL:
		return {"ok": false, "msg": "%s ya alcanzó el nivel máximo (%d)." % [nombre, MAX_DRAGON_LEVEL]}

	var cost_comida: int = get_feed_cost(nivel_actual)
	var res: Dictionary = get_resources()
	var comida_actual: int = int(res.get("comida", 0))
	if comida_actual < cost_comida:
		return {"ok": false, "msg": "Comida insuficiente para %s (%d/%d)." % [nombre, comida_actual, cost_comida]}

	var nuevo_nivel: int = nivel_actual + 1
	var nueva_etapa: String = get_stage_for_level(nuevo_nivel)
	d["nivel"] = nuevo_nivel
	d["etapa"] = nueva_etapa
	dragones[target_idx] = d
	player_state["dragones"] = dragones

	res["comida"] = comida_actual - cost_comida
	player_state["recursos"] = res

	save_game()
	_emit_resources()
	dragon_leveled_up.emit(dragon_uid, nuevo_nivel, nueva_etapa)

	return {
		"ok": true,
		"dragon": d,
		"cost": cost_comida,
		"nivel": nuevo_nivel,
		"etapa": nueva_etapa,
		"stats": get_dragon_stats(d),
		"msg": "¡%s subió a Nivel %d (%s)! (-%d Comida)" % [nombre, nuevo_nivel, nueva_etapa.capitalize(), cost_comida]
	}


func get_resources() -> Dictionary:
	return player_state.get("recursos", {"oro": 0, "comida": 0, "gemas": 0})


func _emit_resources() -> void:
	var res: Dictionary = get_resources()
	resources_changed.emit(
		int(res.get("oro", 0)),
		int(res.get("comida", 0)),
		int(res.get("gemas", 0))
	)
