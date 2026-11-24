extends Node

## Autoload central: carga el catálogo oficial (data/especies_68.json),
## gestiona la persistencia en user://savegame.json, generación pasiva de oro,
## construcción de hábitats, cruces y nido.

const CATALOG_PATH: String = "res://data/especies_68.json"
const SAVE_PATH: String = "user://savegame.json"
const TEST_CLEAN_START_MODE: bool = true
const HABITAT_COST_ORO: int = 250
const PASSIVE_TICK_SEC: float = 5.0
const MAX_DRAGON_LEVEL: int = 10

signal catalog_loaded(total_species: int)
signal save_loaded
signal resources_changed(oro: int, comida: int, gemas: int)
signal dragon_leveled_up(dragon_uid: int, new_nivel: int, new_etapa: String)
signal nest_updated
signal breeding_started(egg: Dictionary)
signal player_level_changed(level: int, exp_current: int, exp_needed: int)
signal world_state_changed
signal obstacles_updated
signal storage_updated
signal boosters_updated

const OBSTACLE_SPECS: Dictionary = {
	"arbusto": {"nombre": "Arbusto", "duracion_seg": 600, "costo_oro": 150, "gemas_acelerar": 2, "exp": 20},
	"arbol_pequeno": {"nombre": "Árbol pequeño", "duracion_seg": 2700, "costo_oro": 350, "gemas_acelerar": 4, "exp": 45},
	"piedrita": {"nombre": "Piedrita", "duracion_seg": 3600, "costo_oro": 500, "gemas_acelerar": 5, "exp": 60},
	"arbol_grande": {"nombre": "Árbol grande", "duracion_seg": 10800, "costo_oro": 1200, "gemas_acelerar": 10, "exp": 120},
	"piedra_mediana": {"nombre": "Piedra mediana", "duracion_seg": 14400, "costo_oro": 1800, "gemas_acelerar": 14, "exp": 160},
	"roca_enorme": {"nombre": "Roca enorme", "duracion_seg": 28800, "costo_oro": 3200, "gemas_acelerar": 22, "exp": 260}
}

const NEST_SLOT_UPGRADE_COSTS: Array[int] = [10, 15, 20]
const GEM_MINE_CYCLE_SEC: float = 86400.0
const GEM_MINE_BUILD_COST: int = 10
const EXTRA_BREEDING_COST_GEMS: int = 20
const NURSERY_MAX_CAPACITY: int = 4

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
	_tick_obstacles(delta)
	_tick_gem_mines(delta)
	_tick_food_farms(delta)
	_tick_training(delta)
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
		"version": "2.0.0",
		"nivel_jugador": 1,
		"exp_jugador": 0,
		"capitulo_pve_actual": 1,
		"tutorial_completado": false,
		"recursos": {
			"oro": 1500,
			"comida": 500,
			"gemas": 35
		},
		"islas_desbloqueadas": [1],
		"parcelas_desbloqueadas": {
			"1": [0],
			"2": [0],
			"3": [0],
			"4": [0],
			"5": [0]
		},
		"obstaculos": _create_default_obstacles(),
		"torre_nido_ranuras": 1,
		"segundo_adoratorio": false,
		"minas_gemas": {},
		"granjas_comida": [
			{"id": 1, "produciendo": false, "restante_seg": 0.0, "cantidad": 150, "duracion_seg": 120}
		],
		"entrenamiento": {
			"activo": false,
			"dragon_uid": -1,
			"restante_seg": 0.0,
			"duracion_seg": 600
		},
		"guarderia": [],
		"almacen": {
			"capacidad_estructuras": 5,
			"estructuras": [],
			"baldosas": {}
		},
		"potenciadores_colocados": [],
		"campana": {
			"capitulo_desbloqueado": 1,
			"completados": []
		},
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
				"xp": 0,
				"entrenamiento_nivel": 0
			},
			{
				"uid": 2,
				"especie_id": 2,
				"nivel": 1,
				"etapa": "cria",
				"xp": 0,
				"entrenamiento_nivel": 0
			}
		]
	}


func _create_default_obstacles() -> Array:
	var obs: Array = []
	var tipos_por_parcela: Array[Array] = [
		["arbusto", "piedrita"],
		["arbol_pequeno", "arbusto"],
		["arbol_grande", "piedra_mediana"],
		["roca_enorme", "piedra_mediana"]
	]
	for island_id: int in range(1, 6):
		for p_idx: int in range(4):
			var tipos: Array = tipos_por_parcela[p_idx]
			for t_idx: int in range(tipos.size()):
				var tipo: String = str(tipos[t_idx])
				var spec: Dictionary = OBSTACLE_SPECS.get(tipo, OBSTACLE_SPECS["arbusto"])
				obs.append({
					"id": "obs_%d_%d_%d" % [island_id, p_idx, t_idx],
					"island_id": island_id,
					"parcela": p_idx,
					"tipo": tipo,
					"duracion_seg": int(spec["duracion_seg"]),
					"restante_seg": float(spec["duracion_seg"]),
					"limpiando": false,
					"limpiado": false,
					"x": -2.1 if t_idx == 0 else 2.0,
					"z": 1.9 if t_idx == 0 else -1.8
				})
	return obs


func is_tutorial_completed() -> bool:
	return bool(player_state.get("tutorial_completado", false))


func complete_tutorial() -> void:
	player_state["tutorial_completado"] = true
	save_game()


func load_game() -> void:
	if TEST_CLEAN_START_MODE:
		player_state = _create_default_state()
		save_loaded.emit()
		_emit_resources()
		return

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
		if not player_state.has("exp_jugador"):
			player_state["exp_jugador"] = 0
		if not player_state.has("parcelas_desbloqueadas"):
			player_state["parcelas_desbloqueadas"] = {"1": [0], "2": [0], "3": [0], "4": [0], "5": [0]}
		if not player_state.has("obstaculos"):
			player_state["obstaculos"] = _create_default_obstacles()
		if not player_state.has("torre_nido_ranuras"):
			player_state["torre_nido_ranuras"] = 1
		if not player_state.has("segundo_adoratorio"):
			player_state["segundo_adoratorio"] = false
		if not player_state.has("minas_gemas"):
			player_state["minas_gemas"] = {}
		if not player_state.has("granjas_comida"):
			player_state["granjas_comida"] = [{"id": 1, "produciendo": false, "restante_seg": 0.0, "cantidad": 150, "duracion_seg": 120}]
		if not player_state.has("entrenamiento"):
			player_state["entrenamiento"] = {"activo": false, "dragon_uid": -1, "restante_seg": 0.0, "duracion_seg": 600}
		if not player_state.has("guarderia"):
			player_state["guarderia"] = []
		if not player_state.has("almacen"):
			player_state["almacen"] = {"capacidad_estructuras": 5, "estructuras": [], "baldosas": {}}
		if not player_state.has("potenciadores_colocados"):
			player_state["potenciadores_colocados"] = []
		if not player_state.has("campana"):
			player_state["campana"] = {"capitulo_desbloqueado": int(player_state.get("capitulo_pve_actual", 1)), "completados": []}

	save_loaded.emit()
	_emit_resources()


func save_game() -> bool:
	if TEST_CLEAN_START_MODE:
		return true
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
	var max_slots: int = get_nest_max_slots()
	if huevos.size() >= max_slots:
		return {"ok": false, "msg": "El Nido está lleno (%d/%d). Mejora la Torre Nido con Gemas." % [huevos.size(), max_slots]}

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
	var max_slots: int = get_nest_max_slots()
	if huevos.size() >= max_slots:
		return {"ok": false, "msg": "El Nido está lleno (%d/%d). Eclosiona o mejora la Torre Nido." % [huevos.size(), max_slots]}

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
	var train_lvl: int = maxi(0, int(dragon_data.get("entrenamiento_nivel", 0)))
	var train_mult: float = 1.0 + float(train_lvl) * 0.10
	var booster_mult: float = get_booster_multiplier_for_species(sp)
	var total_mult: float = scale * train_mult * booster_mult
	return {
		"hp": maxi(10, int(round(float(sp.get("hp_base", 100)) * total_mult))),
		"atk": maxi(5, int(round(float(sp.get("atk_base", 20)) * total_mult))),
		"spd": maxi(5, int(round(float(sp.get("spd_base", 15)) * total_mult))),
		"oro_por_min": int(round(get_dragon_gold_per_minute(dragon_data))),
		"booster_mult": booster_mult,
		"entrenamiento_nivel": train_lvl
	}


func get_booster_multiplier_for_species(sp: Dictionary) -> float:
	if str(sp.get("rareza", "")).to_upper() == "LEGENDARIO":
		return 1.0
	var placed: Array = player_state.get("potenciadores_colocados", [])
	if placed.is_empty():
		return 1.0
	var prim: int = int(sp.get("elemento_primario_id", 0))
	var sec_var: Variant = sp.get("elemento_secundario_id", null)
	var sec: int = int(sec_var) if sec_var != null else 0
	var matches: int = 0
	if prim >= 1 and prim <= 8 and placed.has(prim):
		matches += 1
	if sec >= 1 and sec <= 8 and sec != prim and placed.has(sec):
		matches += 1
	if matches >= 2:
		return 3.0
	if matches == 1:
		return 2.0
	return 1.0


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


# ============================================================================
# SISTEMA DE NIVEL/EXP DE JUGADOR, 5 ISLAS, PARCELAS Y OBSTÁCULOS TEMPORIZADOS
# ============================================================================

func get_player_level() -> int:
	return maxi(1, int(player_state.get("nivel_jugador", 1)))


func get_player_exp_needed(lvl: int) -> int:
	return 100 * maxi(1, lvl)


func add_player_exp(amount: int) -> Dictionary:
	if amount <= 0:
		return {"level": get_player_level(), "leveled_up": false}
	var lvl: int = get_player_level()
	var exp_cur: int = int(player_state.get("exp_jugador", 0)) + amount
	var leveled: bool = false
	while exp_cur >= get_player_exp_needed(lvl):
		exp_cur -= get_player_exp_needed(lvl)
		lvl += 1
		leveled = true
	player_state["nivel_jugador"] = lvl
	player_state["exp_jugador"] = exp_cur
	save_game()
	player_level_changed.emit(lvl, exp_cur, get_player_exp_needed(lvl))
	return {"level": lvl, "exp": exp_cur, "needed": get_player_exp_needed(lvl), "leveled_up": leveled}


func get_unlocked_parcels(island_id: int) -> Array:
	var map: Dictionary = player_state.get("parcelas_desbloqueadas", {})
	return map.get(str(island_id), [0])


func unlock_island_with_level(island_id: int, cost_oro: int, level_req: int) -> Dictionary:
	if is_island_unlocked(island_id):
		return {"ok": false, "msg": "La Isla %d ya está desbloqueada." % island_id}
	if island_id > 1 and not is_island_unlocked(island_id - 1):
		return {"ok": false, "msg": "Debes desbloquear la Isla %d primero." % (island_id - 1)}
	var cur_lvl: int = get_player_level()
	if cur_lvl < level_req:
		return {"ok": false, "msg": "Requiere Nivel de Jugador %d (actual: %d)." % [level_req, cur_lvl]}
	var res: Dictionary = unlock_island(island_id, cost_oro)
	if res.get("ok", false):
		add_player_exp(150 * island_id)
		world_state_changed.emit()
	return res


func unlock_parcel(island_id: int, parcel_idx: int, cost_oro: int, level_req: int) -> Dictionary:
	if not is_island_unlocked(island_id):
		return {"ok": false, "msg": "Primero desbloquea la Isla %d." % island_id}
	var cur_lvl: int = get_player_level()
	if cur_lvl < level_req:
		return {"ok": false, "msg": "Parcela requiere Nivel %d (actual: %d)." % [level_req, cur_lvl]}
	var map: Dictionary = player_state.get("parcelas_desbloqueadas", {})
	var key: String = str(island_id)
	var list: Array = map.get(key, [0])
	if list.has(parcel_idx):
		return {"ok": false, "msg": "Esta parcela ya está desbloqueada."}
	var res: Dictionary = get_resources()
	var oro_actual: int = int(res.get("oro", 0))
	if oro_actual < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [oro_actual, cost_oro]}
	res["oro"] = oro_actual - cost_oro
	player_state["recursos"] = res
	list.append(parcel_idx)
	map[key] = list
	player_state["parcelas_desbloqueadas"] = map
	save_game()
	_emit_resources()
	add_player_exp(55)
	world_state_changed.emit()
	return {"ok": true, "msg": "¡Parcela %d de Isla %d desbloqueada! (+55 EXP)" % [parcel_idx + 1, island_id]}


func get_obstacle_by_id(obs_id: String) -> Dictionary:
	for o: Variant in player_state.get("obstaculos", []):
		if o is Dictionary and str(o.get("id", "")) == obs_id:
			return o
	return {}


func start_clear_obstacle(obs_id: String) -> Dictionary:
	var obs_list: Array = player_state.get("obstaculos", [])
	for i: int in range(obs_list.size()):
		var o: Variant = obs_list[i]
		if o is Dictionary and str(o.get("id", "")) == obs_id:
			if bool(o.get("limpiado", false)):
				return {"ok": false, "msg": "Este obstáculo ya fue limpiado."}
			if bool(o.get("limpiando", false)):
				return {"ok": false, "msg": "Ya se está limpiando este obstáculo."}
			var spec: Dictionary = OBSTACLE_SPECS.get(str(o.get("tipo", "arbusto")), OBSTACLE_SPECS["arbusto"])
			var cost: int = int(spec["costo_oro"])
			var res: Dictionary = get_resources()
			if int(res.get("oro", 0)) < cost:
				return {"ok": false, "msg": "Oro insuficiente para limpiar (%d/%d)." % [int(res.get("oro", 0)), cost]}
			res["oro"] = int(res.get("oro", 0)) - cost
			player_state["recursos"] = res
			o["limpiando"] = true
			obs_list[i] = o
			player_state["obstaculos"] = obs_list
			save_game()
			_emit_resources()
			obstacles_updated.emit()
			return {"ok": true, "msg": "Limpiando %s (-%d Oro)." % [str(spec["nombre"]), cost]}
	return {"ok": false, "msg": "Obstáculo no encontrado."}


func speedup_obstacle_with_gems(obs_id: String) -> Dictionary:
	var obs_list: Array = player_state.get("obstaculos", [])
	for i: int in range(obs_list.size()):
		var o: Variant = obs_list[i]
		if o is Dictionary and str(o.get("id", "")) == obs_id:
			if bool(o.get("limpiado", false)):
				return {"ok": false, "msg": "Ya está limpio."}
			var spec: Dictionary = OBSTACLE_SPECS.get(str(o.get("tipo", "arbusto")), OBSTACLE_SPECS["arbusto"])
			var cost_gems: int = int(spec["gemas_acelerar"])
			var res: Dictionary = get_resources()
			if int(res.get("gemas", 0)) < cost_gems:
				return {"ok": false, "msg": "Gemas insuficientes (%d/%d)." % [int(res.get("gemas", 0)), cost_gems]}
			res["gemas"] = int(res.get("gemas", 0)) - cost_gems
			player_state["recursos"] = res
			o["limpiando"] = false
			o["restante_seg"] = 0.0
			o["limpiado"] = true
			obs_list[i] = o
			player_state["obstaculos"] = obs_list
			save_game()
			_emit_resources()
			add_player_exp(int(spec["exp"]))
			obstacles_updated.emit()
			return {"ok": true, "msg": "¡%s despejado al instante! (-%d Gemas, +%d EXP)" % [str(spec["nombre"]), cost_gems, int(spec["exp"])]}
	return {"ok": false, "msg": "Obstáculo no encontrado."}


func _tick_obstacles(delta: float) -> void:
	var obs_list: Array = player_state.get("obstaculos", [])
	var changed: bool = false
	for i: int in range(obs_list.size()):
		var o: Variant = obs_list[i]
		if o is Dictionary and bool(o.get("limpiando", false)) and not bool(o.get("limpiado", false)):
			var rem: float = maxf(0.0, float(o.get("restante_seg", 0.0)) - delta)
			o["restante_seg"] = rem
			if rem <= 0.0:
				o["limpiando"] = false
				o["limpiado"] = true
				var spec: Dictionary = OBSTACLE_SPECS.get(str(o.get("tipo", "arbusto")), OBSTACLE_SPECS["arbusto"])
				add_player_exp(int(spec["exp"]))
				changed = true
			obs_list[i] = o
	if changed:
		player_state["obstaculos"] = obs_list
		save_game()
		obstacles_updated.emit()


# ============================================================================
# ESTRUCTURAS ESPECIALES, MINAS DE GEMAS, GRANJAS, ENTRENAMIENTO Y GUARDERÍA
# ============================================================================

func get_nest_max_slots() -> int:
	return clampi(int(player_state.get("torre_nido_ranuras", 1)), 1, 4)


func get_next_nest_upgrade_cost() -> int:
	var cur: int = get_nest_max_slots()
	if cur >= 4:
		return -1
	return NEST_SLOT_UPGRADE_COSTS[cur - 1]


func upgrade_nest_tower() -> Dictionary:
	var cost: int = get_next_nest_upgrade_cost()
	if cost < 0:
		return {"ok": false, "msg": "La Torre Nido ya está al máximo (4 ranuras)."}
	var res: Dictionary = get_resources()
	if int(res.get("gemas", 0)) < cost:
		return {"ok": false, "msg": "Gemas insuficientes (%d/%d)." % [int(res.get("gemas", 0)), cost]}
	res["gemas"] = int(res.get("gemas", 0)) - cost
	player_state["recursos"] = res
	var next_slots: int = get_nest_max_slots() + 1
	player_state["torre_nido_ranuras"] = next_slots
	save_game()
	_emit_resources()
	add_player_exp(60)
	nest_updated.emit()
	return {"ok": true, "msg": "¡Torre Nido mejorada a %d ranuras! (-%d Gemas, +60 EXP)" % [next_slots, cost]}


func unlock_second_adoratorio() -> Dictionary:
	if bool(player_state.get("segundo_adoratorio", false)):
		return {"ok": false, "msg": "Ya desbloqueaste el Segundo Adoratorio."}
	var res: Dictionary = get_resources()
	if int(res.get("gemas", 0)) < EXTRA_BREEDING_COST_GEMS:
		return {"ok": false, "msg": "Requiere %d Gemas." % EXTRA_BREEDING_COST_GEMS}
	res["gemas"] = int(res.get("gemas", 0)) - EXTRA_BREEDING_COST_GEMS
	player_state["recursos"] = res
	player_state["segundo_adoratorio"] = true
	save_game()
	_emit_resources()
	add_player_exp(100)
	world_state_changed.emit()
	return {"ok": true, "msg": "¡Segundo Adoratorio de Cría desbloqueado! (-20 Gemas, +100 EXP)"}


func build_gem_mine_on_island(island_id: int) -> Dictionary:
	if not is_island_unlocked(island_id):
		return {"ok": false, "msg": "Debes desbloquear la Isla %d primero." % island_id}
	var mines: Dictionary = player_state.get("minas_gemas", {})
	var key: String = str(island_id)
	if mines.has(key) and bool(mines[key].get("construida", false)):
		return {"ok": false, "msg": "Ya hay una Mina de Gemas en la Isla %d (máx. 1 por isla)." % island_id}
	var res: Dictionary = get_resources()
	if int(res.get("gemas", 0)) < GEM_MINE_BUILD_COST:
		return {"ok": false, "msg": "Gemas insuficientes (%d/%d)." % [int(res.get("gemas", 0)), GEM_MINE_BUILD_COST]}
	res["gemas"] = int(res.get("gemas", 0)) - GEM_MINE_BUILD_COST
	player_state["recursos"] = res
	mines[key] = {"construida": true, "restante_seg": GEM_MINE_CYCLE_SEC, "lista": false}
	player_state["minas_gemas"] = mines
	save_game()
	_emit_resources()
	add_player_exp(80)
	world_state_changed.emit()
	return {"ok": true, "msg": "¡Mina de Gemas construida en Isla %d! Produce 1 Gema cada 24h." % island_id}


func collect_gem_mine(island_id: int) -> Dictionary:
	var mines: Dictionary = player_state.get("minas_gemas", {})
	var key: String = str(island_id)
	if not mines.has(key):
		return {"ok": false, "msg": "No hay Mina de Gemas en la Isla %d." % island_id}
	var mine: Dictionary = mines[key]
	if not bool(mine.get("lista", false)) and float(mine.get("restante_seg", 1.0)) > 0.0:
		var rem_h: float = float(mine.get("restante_seg", 0.0)) / 3600.0
		return {"ok": false, "msg": "Mina de Isla %d produciendo (faltan %.1f h)." % [island_id, rem_h]}
	mine["lista"] = false
	mine["restante_seg"] = GEM_MINE_CYCLE_SEC
	mines[key] = mine
	player_state["minas_gemas"] = mines
	var res: Dictionary = get_resources()
	res["gemas"] = int(res.get("gemas", 0)) + 1
	player_state["recursos"] = res
	save_game()
	_emit_resources()
	add_player_exp(30)
	return {"ok": true, "msg": "¡+1 Gema recogida de la Mina de Isla %d!" % island_id}


func _tick_gem_mines(delta: float) -> void:
	var mines: Dictionary = player_state.get("minas_gemas", {})
	var changed: bool = false
	for key: Variant in mines.keys():
		var m: Variant = mines[key]
		if m is Dictionary and bool(m.get("construida", false)) and not bool(m.get("lista", false)):
			var rem: float = maxf(0.0, float(m.get("restante_seg", GEM_MINE_CYCLE_SEC)) - delta)
			m["restante_seg"] = rem
			if rem <= 0.0:
				m["lista"] = true
				changed = true
			mines[key] = m
	if changed:
		player_state["minas_gemas"] = mines
		save_game()


func start_food_production(cost_oro: int = 200, cantidad: int = 180, duracion_seg: int = 120) -> Dictionary:
	var res: Dictionary = get_resources()
	if int(res.get("oro", 0)) < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [int(res.get("oro", 0)), cost_oro]}
	var granjas: Array = player_state.get("granjas_comida", [])
	if granjas.is_empty():
		granjas.append({"id": 1, "produciendo": false, "restante_seg": 0.0, "cantidad": cantidad, "duracion_seg": duracion_seg})
	var g: Dictionary = granjas[0]
	if bool(g.get("produciendo", false)):
		return {"ok": false, "msg": "La Granja ya está produciendo comida."}
	res["oro"] = int(res.get("oro", 0)) - cost_oro
	player_state["recursos"] = res
	g["produciendo"] = true
	g["cantidad"] = cantidad
	g["duracion_seg"] = duracion_seg
	g["restante_seg"] = float(duracion_seg)
	granjas[0] = g
	player_state["granjas_comida"] = granjas
	save_game()
	_emit_resources()
	return {"ok": true, "msg": "Granja sembrada: +%d Comida en %d s (-%d Oro)." % [cantidad, duracion_seg, cost_oro]}


func speedup_food_farm(cost_gems: int = 2) -> Dictionary:
	var granjas: Array = player_state.get("granjas_comida", [])
	if granjas.is_empty() or not bool(granjas[0].get("produciendo", false)):
		return {"ok": false, "msg": "No hay cosecha activa en la Granja."}
	var res: Dictionary = get_resources()
	if int(res.get("gemas", 0)) < cost_gems:
		return {"ok": false, "msg": "Gemas insuficientes (%d/%d)." % [int(res.get("gemas", 0)), cost_gems]}
	var cantidad: int = int(granjas[0].get("cantidad", 150))
	res["gemas"] = int(res.get("gemas", 0)) - cost_gems
	res["comida"] = int(res.get("comida", 0)) + cantidad
	player_state["recursos"] = res
	granjas[0]["produciendo"] = false
	granjas[0]["restante_seg"] = 0.0
	player_state["granjas_comida"] = granjas
	save_game()
	_emit_resources()
	add_player_exp(25)
	return {"ok": true, "msg": "¡Cosecha acelerada! +%d Comida (-%d Gemas)." % [cantidad, cost_gems]}


func _tick_food_farms(delta: float) -> void:
	var granjas: Array = player_state.get("granjas_comida", [])
	var changed: bool = false
	for i: int in range(granjas.size()):
		var g: Variant = granjas[i]
		if g is Dictionary and bool(g.get("produciendo", false)):
			var rem: float = maxf(0.0, float(g.get("restante_seg", 0.0)) - delta)
			g["restante_seg"] = rem
			if rem <= 0.0:
				g["produciendo"] = false
				var res: Dictionary = get_resources()
				res["comida"] = int(res.get("comida", 0)) + int(g.get("cantidad", 150))
				player_state["recursos"] = res
				add_player_exp(20)
				changed = true
			granjas[i] = g
	if changed:
		player_state["granjas_comida"] = granjas
		save_game()
		_emit_resources()


func start_training(dragon_uid: int, cost_oro: int = 300, duracion_seg: int = 300) -> Dictionary:
	var tr: Dictionary = player_state.get("entrenamiento", {})
	if bool(tr.get("activo", false)):
		return {"ok": false, "msg": "Ya hay un dragón entrenando en el Campo."}
	var res: Dictionary = get_resources()
	if int(res.get("oro", 0)) < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [int(res.get("oro", 0)), cost_oro]}
	res["oro"] = int(res.get("oro", 0)) - cost_oro
	player_state["recursos"] = res
	player_state["entrenamiento"] = {
		"activo": true,
		"dragon_uid": dragon_uid,
		"restante_seg": float(duracion_seg),
		"duracion_seg": duracion_seg
	}
	save_game()
	_emit_resources()
	return {"ok": true, "msg": "Entrenamiento iniciado (-%d Oro, %d s)." % [cost_oro, duracion_seg]}


func speedup_training_with_gems(cost_gems: int = 3) -> Dictionary:
	var tr: Dictionary = player_state.get("entrenamiento", {})
	if not bool(tr.get("activo", false)):
		return {"ok": false, "msg": "No hay entrenamiento activo."}
	var res: Dictionary = get_resources()
	if int(res.get("gemas", 0)) < cost_gems:
		return {"ok": false, "msg": "Gemas insuficientes (%d/%d)." % [int(res.get("gemas", 0)), cost_gems]}
	res["gemas"] = int(res.get("gemas", 0)) - cost_gems
	player_state["recursos"] = res
	var uid: int = int(tr.get("dragon_uid", -1))
	tr["activo"] = false
	tr["restante_seg"] = 0.0
	player_state["entrenamiento"] = tr
	_apply_training_bonus(uid)
	save_game()
	_emit_resources()
	return {"ok": true, "msg": "¡Entrenamiento completado al instante! (+10%% stats, -%d Gemas)" % cost_gems}


func _apply_training_bonus(dragon_uid: int) -> void:
	var dragones: Array = player_state.get("dragones", [])
	for i: int in range(dragones.size()):
		if dragones[i] is Dictionary and int(dragones[i].get("uid", -1)) == dragon_uid:
			dragones[i]["entrenamiento_nivel"] = int(dragones[i].get("entrenamiento_nivel", 0)) + 1
			player_state["dragones"] = dragones
			add_player_exp(40)
			return


func _tick_training(delta: float) -> void:
	var tr: Dictionary = player_state.get("entrenamiento", {})
	if not bool(tr.get("activo", false)):
		return
	var rem: float = maxf(0.0, float(tr.get("restante_seg", 0.0)) - delta)
	tr["restante_seg"] = rem
	if rem <= 0.0:
		tr["activo"] = false
		var uid: int = int(tr.get("dragon_uid", -1))
		player_state["entrenamiento"] = tr
		_apply_training_bonus(uid)
		save_game()
	else:
		player_state["entrenamiento"] = tr


func store_dragon_in_nursery(dragon_data: Dictionary) -> Dictionary:
	var guarderia: Array = player_state.get("guarderia", [])
	if guarderia.size() >= NURSERY_MAX_CAPACITY:
		return {"ok": false, "msg": "Guardería llena (máx. 4 crías)."}
	guarderia.append(dragon_data)
	player_state["guarderia"] = guarderia
	save_game()
	return {"ok": true, "msg": "Cría guardada en la Guardería (%d/4)." % guarderia.size()}


func retrieve_dragon_from_nursery(idx: int) -> Dictionary:
	var guarderia: Array = player_state.get("guarderia", [])
	if idx < 0 or idx >= guarderia.size():
		return {"ok": false, "msg": "No hay cría en ese espacio."}
	var d: Dictionary = guarderia.pop_at(idx)
	player_state["guarderia"] = guarderia
	var dragones: Array = player_state.get("dragones", [])
	dragones.append(d)
	player_state["dragones"] = dragones
	save_game()
	return {"ok": true, "dragon": d, "msg": "¡Cría retirada de la Guardería!"}


# ============================================================================
# POTENCIADORES ELEMENTALES (x2 / x3), ALMACÉN DE ESTRUCTURAS Y BALDOSAS
# ============================================================================

func buy_elemental_booster(elem_id: int, cost_oro: int) -> Dictionary:
	if elem_id < 1 or elem_id > 8:
		return {"ok": false, "msg": "Elemento inválido (solo 8 elementos base)."}
	var placed: Array = player_state.get("potenciadores_colocados", [])
	if placed.has(elem_id):
		return {"ok": false, "msg": "Ya tienes este Potenciador Elemental activo."}
	var res: Dictionary = get_resources()
	if int(res.get("oro", 0)) < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [int(res.get("oro", 0)), cost_oro]}
	res["oro"] = int(res.get("oro", 0)) - cost_oro
	player_state["recursos"] = res
	placed.append(elem_id)
	player_state["potenciadores_colocados"] = placed
	save_game()
	_emit_resources()
	add_player_exp(120)
	boosters_updated.emit()
	return {"ok": true, "msg": "¡Potenciador Elemental activado (×2 / ×3 stats)! (+120 EXP)"}


func store_booster_in_warehouse(elem_id: int) -> Dictionary:
	var placed: Array = player_state.get("potenciadores_colocados", [])
	if not placed.has(elem_id):
		return {"ok": false, "msg": "Ese potenciador no está colocado."}
	var alm: Dictionary = player_state.get("almacen", {"capacidad_estructuras": 5, "estructuras": [], "baldosas": {}})
	var ests: Array = alm.get("estructuras", [])
	if ests.size() >= int(alm.get("capacidad_estructuras", 5)):
		return {"ok": false, "msg": "Almacén lleno (%d/%d). Amplíalo con Gemas." % [ests.size(), int(alm.get("capacidad_estructuras", 5))]}
	placed.erase(elem_id)
	player_state["potenciadores_colocados"] = placed
	var elem_name: String = str(get_element(elem_id).get("nombre", "Elemento %d" % elem_id))
	ests.append({"tipo": "potenciador", "elemento_id": elem_id, "nombre": "Tótem %s" % elem_name})
	alm["estructuras"] = ests
	player_state["almacen"] = alm
	save_game()
	boosters_updated.emit()
	storage_updated.emit()
	return {"ok": true, "msg": "Tótem %s guardado en Almacén (bono desactivado)." % elem_name}


func deploy_structure_from_warehouse(index: int) -> Dictionary:
	var alm: Dictionary = player_state.get("almacen", {"capacidad_estructuras": 5, "estructuras": [], "baldosas": {}})
	var ests: Array = alm.get("estructuras", [])
	if index < 0 or index >= ests.size():
		return {"ok": false, "msg": "Elemento no válido en Almacén."}
	var item: Dictionary = ests.pop_at(index)
	alm["estructuras"] = ests
	player_state["almacen"] = alm
	if str(item.get("tipo", "")) == "potenciador":
		var elem_id: int = int(item.get("elemento_id", 1))
		var placed: Array = player_state.get("potenciadores_colocados", [])
		if not placed.has(elem_id):
			placed.append(elem_id)
		player_state["potenciadores_colocados"] = placed
		boosters_updated.emit()
	save_game()
	storage_updated.emit()
	return {"ok": true, "msg": "¡%s colocado nuevamente en la isla!" % str(item.get("nombre", "Estructura"))}


func expand_warehouse_slots(cost_gems: int = 15) -> Dictionary:
	var res: Dictionary = get_resources()
	if int(res.get("gemas", 0)) < cost_gems:
		return {"ok": false, "msg": "Gemas insuficientes (%d/%d)." % [int(res.get("gemas", 0)), cost_gems]}
	var alm: Dictionary = player_state.get("almacen", {"capacidad_estructuras": 5, "estructuras": [], "baldosas": {}})
	res["gemas"] = int(res.get("gemas", 0)) - cost_gems
	player_state["recursos"] = res
	alm["capacidad_estructuras"] = int(alm.get("capacidad_estructuras", 5)) + 5
	player_state["almacen"] = alm
	save_game()
	_emit_resources()
	storage_updated.emit()
	return {"ok": true, "msg": "¡Almacén ampliado a %d espacios! (-%d Gemas)" % [int(alm["capacidad_estructuras"]), cost_gems]}


func buy_floor_tile(tile_id: String, tile_name: String, cost_oro: int) -> Dictionary:
	var res: Dictionary = get_resources()
	if int(res.get("oro", 0)) < cost_oro:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [int(res.get("oro", 0)), cost_oro]}
	res["oro"] = int(res.get("oro", 0)) - cost_oro
	player_state["recursos"] = res
	var alm: Dictionary = player_state.get("almacen", {"capacidad_estructuras": 5, "estructuras": [], "baldosas": {}})
	var baldosas: Dictionary = alm.get("baldosas", {})
	baldosas[tile_id] = int(baldosas.get(tile_id, 0)) + 1
	alm["baldosas"] = baldosas
	player_state["almacen"] = alm
	save_game()
	_emit_resources()
	add_player_exp(10)
	storage_updated.emit()
	return {"ok": true, "msg": "Baldosa '%s' añadida al Almacén infinito (-%d Oro)." % [tile_name, cost_oro]}


func grant_demo_package(oro: int, comida: int, gemas: int, pack_name: String) -> Dictionary:
	var res: Dictionary = get_resources()
	res["oro"] = int(res.get("oro", 0)) + oro
	res["comida"] = int(res.get("comida", 0)) + comida
	res["gemas"] = int(res.get("gemas", 0)) + gemas
	player_state["recursos"] = res
	save_game()
	_emit_resources()
	return {"ok": true, "msg": "[Demo itch.io] Paquete '%s' acreditado (+%d Oro, +%d Comida, +%d Gemas)." % [pack_name, oro, comida, gemas]}


func has_species_in_collection(species_id: int) -> bool:
	for d: Variant in player_state.get("dragones", []):
		if d is Dictionary and int(d.get("especie_id", 0)) == species_id:
			return true
	return false


func complete_campaign_chapter(chapter_id: int, oro: int, comida: int, gemas: int, exp_reward: int) -> Dictionary:
	var camp: Dictionary = player_state.get("campana", {"capitulo_desbloqueado": 1, "completados": []})
	var comp: Array = camp.get("completados", [])
	if not comp.has(chapter_id):
		comp.append(chapter_id)
	camp["completados"] = comp
	camp["capitulo_desbloqueado"] = maxi(int(camp.get("capitulo_desbloqueado", 1)), mini(50, chapter_id + 1))
	player_state["campana"] = camp
	player_state["capitulo_pve_actual"] = int(camp["capitulo_desbloqueado"])
	var rew: Dictionary = grant_combat_rewards(oro, comida, gemas, int(camp["capitulo_desbloqueado"]))
	var lvl_info: Dictionary = add_player_exp(exp_reward)
	rew["exp"] = exp_reward
	rew["level"] = int(lvl_info.get("level", get_player_level()))
	return rew
