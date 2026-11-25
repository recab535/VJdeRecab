extends Node

## Autoload central: carga el catálogo oficial (data/especies_68.json),
## gestiona la persistencia en user://savegame.json, generación pasiva de oro,
## construcción de hábitats, cruces y nido.

const CATALOG_PATH: String = "res://data/especies_68.json"
const SAVE_PATH: String = "user://savegame.json"
const TEST_CLEAN_START_MODE: bool = true
const HABITAT_COST_ORO: int = 250
const PASSIVE_TICK_SEC: float = 5.0
const MAX_DRAGON_LEVEL: int = 30
const BASE_DRAGON_LEVEL_CAP: int = 10
const MAX_TRAINING_LEVEL: int = 5
const TRAINING_BONUS_PER_LEVEL: float = 0.06

const LEVEL_TEMPLES: Array[Dictionary] = [
	{"tier": 1, "nombre": "Templo del Alba", "nivel_cap": 15, "costo_oro": 1500, "nivel_jugador_req": 3, "exp": 90},
	{"tier": 2, "nombre": "Templo de la Forja", "nivel_cap": 20, "costo_oro": 4500, "nivel_jugador_req": 6, "exp": 160},
	{"tier": 3, "nombre": "Templo de las Mareas", "nivel_cap": 25, "costo_oro": 12000, "nivel_jugador_req": 10, "exp": 260},
	{"tier": 4, "nombre": "Templo Ancestral", "nivel_cap": 30, "costo_oro": 30000, "nivel_jugador_req": 15, "exp": 400}
]

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
signal temples_updated

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

const FOOD_CROPS: Array[Dictionary] = [
	{"nombre": "Baya Rápida", "etiqueta": "30 s", "duracion_seg": 30, "costo_oro": 50, "comida": 25, "gemas_acelerar": 1},
	{"nombre": "Campana Azul", "etiqueta": "5 min", "duracion_seg": 300, "costo_oro": 250, "comida": 140, "gemas_acelerar": 2},
	{"nombre": "Fruta Dragón", "etiqueta": "1 h", "duracion_seg": 3600, "costo_oro": 1200, "comida": 750, "gemas_acelerar": 4},
	{"nombre": "Estrella Solar", "etiqueta": "6 h", "duracion_seg": 21600, "costo_oro": 5000, "comida": 3600, "gemas_acelerar": 8},
	{"nombre": "Árbol Dorado", "etiqueta": "24 h", "duracion_seg": 86400, "costo_oro": 18000, "comida": 15000, "gemas_acelerar": 15}
]

var elementos_by_id: Dictionary = {}
var especies_by_id: Dictionary = {}
var multiplicadores: Dictionary = {}
var reglas_cruce: Dictionary = {}
var recetas_legendarias: Array = []
var player_state: Dictionary = {}

var _passive_accum_sec: float = 0.0
var _gold_fraction: float = 0.0


func _ready() -> void:
	_load_catalog()
	load_game()


func _exit_tree() -> void:
	VisualShaders.clear_cache()
	Dragon2D.clear_cache()


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
	recetas_legendarias = data.get("recetas_legendarias", [])

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
		"templos_nivel": [],
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

	var res: Dictionary = load_game_from_path(SAVE_PATH)
	if not bool(res.get("ok", false)):
		player_state = _create_default_state()
		save_game()
	else:
		player_state = res.get("state", _create_default_state())
		_ensure_state_schema()

	save_loaded.emit()
	_emit_resources()


func load_game_from_path(source_path: String) -> Dictionary:
	if not FileAccess.file_exists(source_path):
		return {"ok": false, "corrupted": false, "backup_path": "", "state": {}}

	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "corrupted": false, "backup_path": "", "state": {}}

	var raw_text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(raw_text)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		var backup_path: String = _backup_corrupt_save(source_path)
		push_warning("[GameCore] Archivo de guardado corrupto en %s. Respaldo creado en: %s" % [source_path, backup_path])
		return {"ok": false, "corrupted": true, "backup_path": backup_path, "state": {}}

	return {"ok": true, "corrupted": false, "backup_path": "", "state": json.data as Dictionary}


func _backup_corrupt_save(source_path: String) -> String:
	var backup_path: String = source_path + ".corrupt.bak"
	var src_abs: String = ProjectSettings.globalize_path(source_path)
	var bak_abs: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(bak_abs)
	var err: Error = DirAccess.copy_absolute(src_abs, bak_abs)
	if err != OK:
		var f_in: FileAccess = FileAccess.open(source_path, FileAccess.READ)
		var f_out: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
		if f_in and f_out:
			f_out.store_string(f_in.get_as_text())
			f_out.flush()
			f_out.close()
			f_in.close()
	return backup_path


func _ensure_state_schema() -> void:
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
	if not player_state.has("templos_nivel"):
		player_state["templos_nivel"] = []
	if not player_state.has("campana"):
		player_state["campana"] = {"capitulo_desbloqueado": int(player_state.get("capitulo_pve_actual", 1)), "completados": []}
	_normalize_loaded_int_arrays()


func _normalize_loaded_int_arrays() -> void:
	var islas_norm: Array = []
	for item: Variant in player_state.get("islas_desbloqueadas", [1]):
		var v: int = int(item)
		if not islas_norm.has(v):
			islas_norm.append(v)
	player_state["islas_desbloqueadas"] = islas_norm if not islas_norm.is_empty() else [1]

	var pot_norm: Array = []
	for item: Variant in player_state.get("potenciadores_colocados", []):
		var v: int = int(item)
		if v >= 1 and v <= 8 and not pot_norm.has(v):
			pot_norm.append(v)
	player_state["potenciadores_colocados"] = pot_norm

	var temp_norm: Array = []
	for item: Variant in player_state.get("templos_nivel", []):
		var v: int = int(item)
		if v >= 1 and v <= LEVEL_TEMPLES.size() and not temp_norm.has(v):
			temp_norm.append(v)
	player_state["templos_nivel"] = temp_norm

	var parc_map: Dictionary = player_state.get("parcelas_desbloqueadas", {})
	for key: Variant in parc_map.keys():
		var raw_list: Variant = parc_map[key]
		if raw_list is Array:
			var norm_list: Array = []
			for p: Variant in raw_list:
				var pv: int = int(p)
				if not norm_list.has(pv):
					norm_list.append(pv)
			parc_map[str(key)] = norm_list
	player_state["parcelas_desbloqueadas"] = parc_map

	var camp: Dictionary = player_state.get("campana", {})
	if camp.has("completados") and camp["completados"] is Array:
		var comp_norm: Array = []
		for c: Variant in camp["completados"]:
			var cv: int = int(c)
			if not comp_norm.has(cv):
				comp_norm.append(cv)
		camp["completados"] = comp_norm
		player_state["campana"] = camp


func save_game() -> bool:
	if TEST_CLEAN_START_MODE:
		return true
	return save_game_to_path(SAVE_PATH)


func save_game_to_path(target_path: String) -> bool:
	var tmp_path: String = target_path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("[GameCore] No se pudo escribir temporal en: " + tmp_path)
		return false
	file.store_string(JSON.stringify(player_state, "\t"))
	file.flush()
	file.close()

	var tmp_abs: String = ProjectSettings.globalize_path(tmp_path)
	var dst_abs: String = ProjectSettings.globalize_path(target_path)
	var err: Error = DirAccess.rename_absolute(tmp_abs, dst_abs)
	if err != OK:
		if FileAccess.file_exists(target_path):
			DirAccess.remove_absolute(dst_abs)
			err = DirAccess.rename_absolute(tmp_abs, dst_abs)
		if err != OK:
			var cp_err: Error = DirAccess.copy_absolute(tmp_abs, dst_abs)
			DirAccess.remove_absolute(tmp_abs)
			if cp_err != OK:
				push_error("[GameCore] Error en guardado atómico hacia: " + target_path)
				return false
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


func move_habitat_slot(old_slot_index: int, new_slot_index: int) -> Dictionary:
	if old_slot_index == new_slot_index:
		return {"ok": false, "msg": "El hábitat ya está en ese espacio."}
	var estructuras: Array = player_state.get("estructuras", [])
	var found_idx: int = -1
	for i: int in range(estructuras.size()):
		var est: Variant = estructuras[i]
		if est is Dictionary:
			var s_idx: int = int(est.get("slot_index", -1))
			if s_idx == new_slot_index:
				return {"ok": false, "msg": "El espacio destino ya está ocupado."}
			if s_idx == old_slot_index:
				found_idx = i
	if found_idx == -1:
		return {"ok": false, "msg": "Hábitat origen no encontrado."}
	estructuras[found_idx]["slot_index"] = new_slot_index
	player_state["estructuras"] = estructuras
	save_game()
	return {"ok": true, "msg": "Hábitat movido al espacio %d." % (new_slot_index + 1)}


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
	var total_sec: int = maxi(5, int(sp.get("tiempo_incubacion_seg", 300)))
	var egg: Dictionary = {
		"especie_id": especie_id,
		"nombre": str(sp.get("nombre", "Dragón")),
		"tiempo_incubacion_seg": total_sec,
		"tiempo_restante_seg": 5.0,
		"listo": false
	}
	huevos.append(egg)
	player_state["nido_huevos"] = huevos
	res["oro"] = oro_actual - cost_oro
	player_state["recursos"] = res
	save_game()
	_emit_resources()
	nest_updated.emit()
	return {"ok": true, "egg": egg, "msg": "Huevo de %s comprado y enviado al Nido (-%d Oro)." % [egg["nombre"], cost_oro]}


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
	var sp_a: Dictionary = get_species(parent_a_id)
	var sp_b: Dictionary = get_species(parent_b_id)
	if _is_pure_opposite_pair(sp_a, sp_b):
		return {
			"candidates": [],
			"min_time_seg": 0,
			"max_time_seg": 0,
			"legendary_id": 0,
			"legendary_prob": 0.0,
			"blocked_reason": "Elementos opuestos puros no se cruzan directamente; usa dragones híbridos."
		}

	var candidates: Array[int] = _get_breeding_candidates(parent_a_id, parent_b_id)
	var leg_recipe: Dictionary = _get_legendary_recipe(parent_a_id, parent_b_id)
	var leg_id: int = int(leg_recipe.get("legendario_id", 0))
	var leg_prob: float = float(leg_recipe.get("probabilidad", reglas_cruce.get("probabilidad_legendario_defecto", 0.04))) if leg_id > 0 else 0.0

	var all_ids: Array[int] = candidates.duplicate()
	if leg_id > 0 and not all_ids.has(leg_id):
		all_ids.append(leg_id)

	var min_time: int = 0
	var max_time: int = 0
	for sp_id: int in all_ids:
		var sp: Dictionary = get_species(sp_id)
		var t: int = maxi(5, int(sp.get("tiempo_incubacion_seg", 300)))
		if min_time == 0 or t < min_time:
			min_time = t
		if t > max_time:
			max_time = t
	return {
		"candidates": candidates,
		"min_time_seg": min_time,
		"max_time_seg": max_time,
		"legendary_id": leg_id,
		"legendary_prob": leg_prob,
		"blocked_reason": ""
	}


func start_breeding(parent_a_id: int, parent_b_id: int, parent_a_level: int = 1, parent_b_level: int = 1) -> Dictionary:
	var huevos: Array = player_state.get("nido_huevos", [])
	var max_slots: int = get_nest_max_slots()
	if huevos.size() >= max_slots:
		return {"ok": false, "msg": "El Nido está lleno (%d/%d). Eclosiona o mejora la Torre Nido." % [huevos.size(), max_slots]}

	if not especies_by_id.has(parent_a_id) or not especies_by_id.has(parent_b_id):
		return {"ok": false, "msg": "Selecciona dos especies válidas para cruzar."}

	if _is_pure_opposite_pair(get_species(parent_a_id), get_species(parent_b_id)):
		return {"ok": false, "msg": "Elementos opuestos puros no se cruzan directamente; usa dragones híbridos."}

	var result_id: int = _resolve_breeding_species(parent_a_id, parent_b_id, parent_a_level, parent_b_level)
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
	return {"ok": true, "egg": egg, "msg": "¡Cruce iniciado! Huevo misterioso enviado a la Torre Nido (%d min)." % maxi(1, int(round(float(total_sec) / 60.0)))}


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
		"xp": 0,
		"entrenamiento_nivel": 0
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


func _is_pure_opposite_pair(sp_a: Dictionary, sp_b: Dictionary) -> bool:
	if sp_a.is_empty() or sp_b.is_empty():
		return false
	if sp_a.get("elemento_secundario_id", null) != null or sp_b.get("elemento_secundario_id", null) != null:
		return false
	var elem_a: int = int(sp_a.get("elemento_primario_id", 0))
	var elem_b: int = int(sp_b.get("elemento_primario_id", 0))
	if elem_a < 1 or elem_a > 8 or elem_b < 1 or elem_b > 8:
		return false
	var elem_data: Dictionary = get_element(elem_a)
	var opp_var: Variant = elem_data.get("elemento_opuesto_id", null)
	return opp_var != null and int(opp_var) == elem_b


func _get_legendary_recipe(parent_a_id: int, parent_b_id: int) -> Dictionary:
	for rec_var: Variant in recetas_legendarias:
		if not (rec_var is Dictionary):
			continue
		var rec: Dictionary = rec_var
		var pa: int = int(rec.get("padre_a_id", 0))
		var pb: int = int(rec.get("padre_b_id", 0))
		if (pa == parent_a_id and pb == parent_b_id) or (pa == parent_b_id and pb == parent_a_id):
			return rec
	return {}


func _extract_base_elements(sp: Dictionary) -> Array[int]:
	var elems: Array[int] = []
	var prim: int = int(sp.get("elemento_primario_id", 0))
	if prim >= 1 and prim <= 8:
		elems.append(prim)
	var sec_var: Variant = sp.get("elemento_secundario_id", null)
	if sec_var != null:
		var sec: int = int(sec_var)
		if sec >= 1 and sec <= 8 and not elems.has(sec):
			elems.append(sec)
	return elems


func _get_breeding_candidates(parent_a_id: int, parent_b_id: int) -> Array[int]:
	var sp_a: Dictionary = get_species(parent_a_id)
	var sp_b: Dictionary = get_species(parent_b_id)
	if _is_pure_opposite_pair(sp_a, sp_b):
		return []

	var elems_a: Array[int] = _extract_base_elements(sp_a)
	var elems_b: Array[int] = _extract_base_elements(sp_b)
	var candidates: Array[int] = []

	for ea: int in elems_a:
		for eb: int in elems_b:
			if ea == eb:
				if especies_by_id.has(ea) and not candidates.has(ea):
					candidates.append(ea)
			else:
				for sp: Variant in especies_by_id.values():
					if sp is Dictionary:
						var p: int = int(sp.get("elemento_primario_id", 0))
						var s: Variant = sp.get("elemento_secundario_id", null)
						if s != null and ((p == ea and int(s) == eb) or (p == eb and int(s) == ea)):
							var sp_id: int = int(sp.get("id", 0))
							if sp_id > 0 and not candidates.has(sp_id):
								candidates.append(sp_id)

	if candidates.is_empty():
		if especies_by_id.has(parent_a_id):
			candidates.append(parent_a_id)
		if especies_by_id.has(parent_b_id) and not candidates.has(parent_b_id):
			candidates.append(parent_b_id)
	return candidates


func _resolve_breeding_species(parent_a_id: int, parent_b_id: int, parent_a_level: int = 1, parent_b_level: int = 1) -> int:
	var avg_level: float = float(maxi(1, parent_a_level) + maxi(1, parent_b_level)) * 0.5
	var high_level_bonus: float = 0.02 if (parent_a_level >= 15 and parent_b_level >= 15) else (0.01 if avg_level >= 8.0 else 0.0)

	var leg_recipe: Dictionary = _get_legendary_recipe(parent_a_id, parent_b_id)
	if not leg_recipe.is_empty():
		var leg_id: int = int(leg_recipe.get("legendario_id", 0))
		var base_prob: float = float(leg_recipe.get("probabilidad", reglas_cruce.get("probabilidad_legendario_defecto", 0.04)))
		var final_prob: float = clampf(base_prob + high_level_bonus, 0.01, 0.08)
		if leg_id > 0 and especies_by_id.has(leg_id) and randf() < final_prob:
			return leg_id

	var candidates: Array[int] = _get_breeding_candidates(parent_a_id, parent_b_id)
	if candidates.is_empty():
		return parent_a_id

	# Selección ponderada (Weighted RNG) preservando paridad 50%/50% en cada par A/B y B/A
	var total_weight: float = 0.0
	var weights: Array[float] = []
	for cid: int in candidates:
		var sp: Dictionary = get_species(cid)
		var rareza: String = str(sp.get("rareza", "PURO")).to_upper()
		var w: float = 1.0
		if rareza == "OPUESTO":
			w = 0.75 + (0.30 if avg_level >= 10.0 else 0.0)
		elif rareza == "HIBRIDO":
			w = 1.0 + (0.25 if avg_level >= 10.0 else 0.0)
		else:
			w = 1.0
		weights.append(w)
		total_weight += w

	var roll: float = randf() * total_weight
	var accum: float = 0.0
	for i: int in range(candidates.size()):
		accum += weights[i]
		if roll <= accum:
			return candidates[i]
	return candidates[candidates.size() - 1]


func get_species(species_id: int) -> Dictionary:
	return especies_by_id.get(species_id, {})


func get_element(element_id: int) -> Dictionary:
	return elementos_by_id.get(element_id, {})


func get_feed_cost(nivel: int) -> int:
	var d_lvl: float = float(maxi(1, nivel) - 1)
	return maxi(15, int(round(14.0 + d_lvl * 18.0 + d_lvl * d_lvl * 2.2)))


func start_food_crop(crop_idx: int) -> Dictionary:
	var idx: int = clampi(crop_idx, 0, FOOD_CROPS.size() - 1)
	var crop: Dictionary = FOOD_CROPS[idx]
	return start_food_production(int(crop["costo_oro"]), int(crop["comida"]), int(crop["duracion_seg"]))


func get_stage_for_level(nivel: int) -> String:
	if nivel >= 16:
		return "adulto"
	if nivel >= 8:
		return "joven"
	return "cria"


func get_current_dragon_level_cap() -> int:
	var cap: int = BASE_DRAGON_LEVEL_CAP
	var unlocked: Array = player_state.get("templos_nivel", [])
	for t: Dictionary in LEVEL_TEMPLES:
		if unlocked.has(int(t["tier"])):
			cap = maxi(cap, int(t["nivel_cap"]))
	return mini(cap, MAX_DRAGON_LEVEL)


func is_level_temple_unlocked(tier: int) -> bool:
	var unlocked: Array = player_state.get("templos_nivel", [])
	return unlocked.has(tier)


func get_next_level_temple() -> Dictionary:
	for t: Dictionary in LEVEL_TEMPLES:
		if not is_level_temple_unlocked(int(t["tier"])):
			return t
	return {}


func unlock_level_temple(tier: int) -> Dictionary:
	var target: Dictionary = {}
	for t: Dictionary in LEVEL_TEMPLES:
		if int(t["tier"]) == tier:
			target = t
			break
	if target.is_empty():
		return {"ok": false, "msg": "Templo inválido."}
	if is_level_temple_unlocked(tier):
		return {"ok": false, "msg": "El %s ya está construido." % str(target["nombre"])}
	if tier > 1 and not is_level_temple_unlocked(tier - 1):
		return {"ok": false, "msg": "Primero debes construir el Templo anterior (Nivel %d)." % (BASE_DRAGON_LEVEL_CAP + (tier - 1) * 5)}
	var lvl_req: int = int(target["nivel_jugador_req"])
	if get_player_level() < lvl_req:
		return {"ok": false, "msg": "%s requiere Nivel de Domador %d (actual: %d)." % [str(target["nombre"]), lvl_req, get_player_level()]}
	var cost: int = int(target["costo_oro"])
	var res: Dictionary = get_resources()
	if int(res.get("oro", 0)) < cost:
		return {"ok": false, "msg": "Oro insuficiente (%d/%d)." % [int(res.get("oro", 0)), cost]}

	res["oro"] = int(res.get("oro", 0)) - cost
	player_state["recursos"] = res
	var unlocked: Array = player_state.get("templos_nivel", [])
	unlocked.append(tier)
	player_state["templos_nivel"] = unlocked
	save_game()
	_emit_resources()
	add_player_exp(int(target["exp"]))
	temples_updated.emit()
	world_state_changed.emit()
	return {
		"ok": true,
		"tier": tier,
		"nivel_cap": int(target["nivel_cap"]),
		"msg": "¡%s construido! Tope de nivel de dragones ampliado a Nv.%d (-%d Oro)." % [str(target["nombre"]), int(target["nivel_cap"]), cost]
	}


func get_dragon_gold_per_minute(dragon_data: Dictionary) -> float:
	var sp: Dictionary = get_species(int(dragon_data.get("especie_id", 0)))
	var base_oro: float = float(sp.get("oro_por_minuto", 0))
	var nivel: int = clampi(int(dragon_data.get("nivel", 1)), 1, MAX_DRAGON_LEVEL)
	return base_oro * (1.0 + float(nivel - 1) * 0.14)


func get_dragon_rank_info(dragon_data: Dictionary) -> Dictionary:
	var wins: int = int(dragon_data.get("victorias_combate", 0))
	if wins >= 15:
		return {"nombre": "Oro ★★★", "mult": 1.25, "wins": wins}
	if wins >= 8:
		return {"nombre": "Plata ★★", "mult": 1.16, "wins": wins}
	if wins >= 3:
		return {"nombre": "Bronce ★", "mult": 1.08, "wins": wins}
	return {"nombre": "", "mult": 1.00, "wins": wins}


func record_dragon_combat_wins(dragon_uids: Array) -> void:
	var changed: bool = false
	for key: String in ["dragones", "guarderia"]:
		var lista: Array = player_state.get(key, [])
		for i: int in range(lista.size()):
			if lista[i] is Dictionary:
				var uid: int = int(lista[i].get("uid", -1))
				if dragon_uids.has(uid):
					lista[i]["victorias_combate"] = int(lista[i].get("victorias_combate", 0)) + 1
					changed = true
		player_state[key] = lista
	if changed:
		save_game()


func get_dragon_stats(dragon_data: Dictionary) -> Dictionary:
	var sp: Dictionary = get_species(int(dragon_data.get("especie_id", 1)))
	var lvl: float = float(clampi(int(dragon_data.get("nivel", 1)), 1, MAX_DRAGON_LEVEL))
	var d_lvl: float = lvl - 1.0
	# Escalado polinómico balanceado para niveles 1..30 (sin explosión exponencial)
	var hp_poly: float = 1.0 + 0.085 * d_lvl + 0.0028 * d_lvl * d_lvl
	var atk_poly: float = 1.0 + 0.075 * d_lvl + 0.0022 * d_lvl * d_lvl
	var spd_poly: float = 1.0 + 0.035 * d_lvl

	var train_lvl: int = clampi(int(dragon_data.get("entrenamiento_nivel", 0)), 0, MAX_TRAINING_LEVEL)
	var train_mult: float = 1.0 + float(train_lvl) * TRAINING_BONUS_PER_LEVEL
	var booster_mult: float = get_booster_multiplier_for_species(sp)
	var rank_info: Dictionary = get_dragon_rank_info(dragon_data)
	var rank_mult: float = float(rank_info["mult"])

	var common_mult: float = train_mult * booster_mult * rank_mult
	return {
		"hp": maxi(10, int(round(float(sp.get("hp_base", 100)) * hp_poly * common_mult))),
		"atk": maxi(5, int(round(float(sp.get("atk_base", 20)) * atk_poly * common_mult))),
		"spd": maxi(5, int(round(float(sp.get("spd_base", 15)) * spd_poly * train_mult))),
		"oro_por_min": int(round(get_dragon_gold_per_minute(dragon_data))),
		"booster_mult": booster_mult,
		"entrenamiento_nivel": train_lvl,
		"rango_nombre": str(rank_info["nombre"]),
		"rango_mult": rank_mult
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
		return 1.35
	if matches == 1:
		return 1.20
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

	var cur_cap: int = get_current_dragon_level_cap()
	if nivel_actual >= cur_cap:
		var next_t: Dictionary = get_next_level_temple()
		var t_name: String = str(next_t.get("nombre", "Templo de Nivel"))
		var next_cap: int = int(next_t.get("nivel_cap", MAX_DRAGON_LEVEL))
		return {
			"ok": false,
			"cap_reached": true,
			"msg": "%s llegó al tope actual (Nv.%d). Construye el %s para subir hasta Nv.%d." % [nombre, cur_cap, t_name, next_cap]
		}

	var cost_comida: int = get_feed_cost(nivel_actual)
	var res: Dictionary = get_resources()
	var comida_actual: int = int(res.get("comida", 0))
	if comida_actual < cost_comida:
		return {"ok": false, "msg": "Comida insuficiente para %s (%d/%d)." % [nombre, comida_actual, cost_comida]}

	res["comida"] = comida_actual - cost_comida
	player_state["recursos"] = res

	# Sistema clásico de 4 pasos de alimentación por nivel (feed_steps 0..3 -> sube nivel en el 4º)
	var cur_steps: int = clampi(int(d.get("feed_steps", 0)), 0, 3) + 1
	var leveled_up: bool = false
	var nuevo_nivel: int = nivel_actual
	var nueva_etapa: String = str(d.get("etapa", get_stage_for_level(nivel_actual)))

	if cur_steps >= 4:
		cur_steps = 0
		nuevo_nivel = nivel_actual + 1
		nueva_etapa = get_stage_for_level(nuevo_nivel)
		d["nivel"] = nuevo_nivel
		d["etapa"] = nueva_etapa
		leveled_up = true

	d["feed_steps"] = cur_steps
	dragones[target_idx] = d
	player_state["dragones"] = dragones

	save_game()
	_emit_resources()
	if leveled_up:
		add_player_exp(18)
		dragon_leveled_up.emit(dragon_uid, nuevo_nivel, nueva_etapa)
		return {
			"ok": true,
			"dragon": d,
			"cost": cost_comida,
			"nivel": nuevo_nivel,
			"etapa": nueva_etapa,
			"feed_steps": cur_steps,
			"leveled_up": true,
			"stats": get_dragon_stats(d),
			"msg": "¡%s subió a Nivel %d (%s)! (-%d Comida, +18 EXP)" % [nombre, nuevo_nivel, nueva_etapa.capitalize(), cost_comida]
		}
	return {
		"ok": true,
		"dragon": d,
		"cost": cost_comida,
		"nivel": nuevo_nivel,
		"etapa": nueva_etapa,
		"feed_steps": cur_steps,
		"leveled_up": false,
		"stats": get_dragon_stats(d),
		"msg": "%s alimentado (%d/4 para Nv.%d) (-%d Comida)" % [nombre, cur_steps, nuevo_nivel + 1, cost_comida]
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


func are_all_parcels_unlocked(island_id: int) -> bool:
	var parcels: Array = get_unlocked_parcels(island_id)
	for idx: int in range(4):
		if not parcels.has(idx):
			return false
	return true


func can_explore_island(island_id: int) -> bool:
	if island_id <= 1:
		return true
	if is_island_unlocked(island_id):
		return true
	return is_island_unlocked(island_id - 1) and are_all_parcels_unlocked(island_id - 1)


func unlock_island_with_level(island_id: int, cost_oro: int, level_req: int) -> Dictionary:
	if is_island_unlocked(island_id):
		return {"ok": false, "msg": "La Isla %d ya está desbloqueada." % island_id}
	if island_id > 1 and not is_island_unlocked(island_id - 1):
		return {"ok": false, "msg": "Debes desbloquear la Isla %d primero." % (island_id - 1)}
	if island_id > 1 and not are_all_parcels_unlocked(island_id - 1):
		return {"ok": false, "msg": "Compra las 4 parcelas de la Isla %d antes de desbloquear la Isla %d." % [island_id - 1, island_id]}
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
	var target_d: Dictionary = get_dragon_by_uid(dragon_uid)
	if target_d.is_empty():
		return {"ok": false, "msg": "Dragón no encontrado para entrenar."}
	var cur_train: int = int(target_d.get("entrenamiento_nivel", 0))
	if cur_train >= MAX_TRAINING_LEVEL:
		return {"ok": false, "msg": "Este dragón ya alcanzó el máximo de entrenamiento (%d/%d)." % [cur_train, MAX_TRAINING_LEVEL]}
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
	return {"ok": true, "msg": "¡Entrenamiento completado al instante! (+6%% stats, -%d Gemas)" % cost_gems}


func _apply_training_bonus(dragon_uid: int) -> void:
	var dragones: Array = player_state.get("dragones", [])
	for i: int in range(dragones.size()):
		if dragones[i] is Dictionary and int(dragones[i].get("uid", -1)) == dragon_uid:
			dragones[i]["entrenamiento_nivel"] = mini(MAX_TRAINING_LEVEL, int(dragones[i].get("entrenamiento_nivel", 0)) + 1)
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

func is_booster_in_warehouse(elem_id: int) -> bool:
	var alm: Dictionary = player_state.get("almacen", {})
	for item_var: Variant in alm.get("estructuras", []):
		if item_var is Dictionary and str(item_var.get("tipo", "")) == "potenciador" and int(item_var.get("elemento_id", 0)) == elem_id:
			return true
	return false


func buy_elemental_booster(elem_id: int, cost_oro: int) -> Dictionary:
	if elem_id < 1 or elem_id > 8:
		return {"ok": false, "msg": "Elemento inválido (solo 8 elementos base)."}
	var placed: Array = player_state.get("potenciadores_colocados", [])
	if placed.has(elem_id):
		return {"ok": false, "msg": "Ya tienes este Potenciador Elemental activo."}
	if is_booster_in_warehouse(elem_id):
		return {"ok": false, "msg": "Ya posees este Tótem en tu Almacén. Colócalo desde allí."}
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
	return {"ok": true, "msg": "¡Potenciador Elemental activado (+20%% / +35%% stats)! (+120 EXP)"}


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
	for g: Variant in player_state.get("guarderia", []):
		if g is Dictionary and int(g.get("especie_id", 0)) == species_id:
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
