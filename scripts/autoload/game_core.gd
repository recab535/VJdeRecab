extends Node

## Autoload central: carga el catálogo oficial (data/especies_68.json),
## gestiona la persistencia en user://savegame.json, generación pasiva de oro,
## construcción de hábitats, cruces y nido.

const CATALOG_PATH: String = "res://data/especies_68.json"
const SAVE_PATH: String = "user://savegame.json"
const HABITAT_COST_ORO: int = 250
const PASSIVE_TICK_SEC: float = 5.0

signal catalog_loaded(total_species: int)
signal save_loaded
signal resources_changed(oro: int, comida: int, gemas: int)

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
	_passive_accum_sec += delta
	if _passive_accum_sec >= PASSIVE_TICK_SEC:
		var elapsed: float = _passive_accum_sec
		_passive_accum_sec = 0.0
		_tick_passive_gold(elapsed)


func _tick_passive_gold(elapsed_sec: float) -> void:
	var oro_por_min: float = 0.0
	for d: Variant in player_state.get("dragones", []):
		if d is Dictionary:
			var sp: Dictionary = get_species(int(d.get("especie_id", 0)))
			oro_por_min += float(sp.get("oro_por_minuto", 0))

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
			}
		]
	}


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
		if not player_state.has("estructuras"):
			player_state["estructuras"] = []

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


func start_breeding(parent_a_id: int, parent_b_id: int) -> Dictionary:
	var huevos: Array = player_state.get("nido_huevos", [])
	if huevos.size() >= 3:
		return {"ok": false, "msg": "El Nido está lleno (máx. 3 huevos). Eclosiona uno primero."}

	var result_id: int = _resolve_breeding_species(parent_a_id, parent_b_id)
	var sp: Dictionary = get_species(result_id)
	var egg: Dictionary = {
		"especie_id": result_id,
		"nombre": str(sp.get("nombre", "Dragón")),
		"tiempo_incubacion_seg": int(sp.get("tiempo_incubacion_seg", 300))
	}
	huevos.append(egg)
	player_state["nido_huevos"] = huevos
	save_game()
	return {"ok": true, "egg": egg, "msg": "Cruce iniciado: huevo de %s enviado al Nido." % egg["nombre"]}


func hatch_next_egg() -> Dictionary:
	var huevos: Array = player_state.get("nido_huevos", [])
	if huevos.is_empty():
		return {"ok": false, "msg": "No hay huevos en el Nido. Usa Cruce primero."}

	var egg: Dictionary = huevos.pop_front()
	player_state["nido_huevos"] = huevos

	var dragones: Array = player_state.get("dragones", [])
	var next_uid: int = dragones.size() + 1
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
	return {"ok": true, "dragon": new_dragon, "nombre": str(egg.get("nombre", "Dragón")), "msg": "¡Eclosionó %s!" % str(egg.get("nombre", "Dragón"))}


func _resolve_breeding_species(parent_a_id: int, parent_b_id: int) -> int:
	var sp_a: Dictionary = get_species(parent_a_id)
	var sp_b: Dictionary = get_species(parent_b_id)
	var elem_a: int = int(sp_a.get("elemento_primario_id", 1))
	var elem_b: int = int(sp_b.get("elemento_primario_id", 1))

	if elem_a == elem_b:
		return elem_a

	var candidates: Array[int] = []
	for sp: Variant in especies_by_id.values():
		if sp is Dictionary:
			var p: int = int(sp.get("elemento_primario_id", 0))
			var s: Variant = sp.get("elemento_secundario_id", null)
			if s != null and ((p == elem_a and int(s) == elem_b) or (p == elem_b and int(s) == elem_a)):
				candidates.append(int(sp.get("id", 1)))

	if candidates.is_empty():
		return elem_a
	return candidates[randi() % candidates.size()]


func get_species(species_id: int) -> Dictionary:
	return especies_by_id.get(species_id, {})


func get_element(element_id: int) -> Dictionary:
	return elementos_by_id.get(element_id, {})


func get_resources() -> Dictionary:
	return player_state.get("recursos", {"oro": 0, "comida": 0, "gemas": 0})


func _emit_resources() -> void:
	var res: Dictionary = get_resources()
	resources_changed.emit(
		int(res.get("oro", 0)),
		int(res.get("comida", 0)),
		int(res.get("gemas", 0))
	)
