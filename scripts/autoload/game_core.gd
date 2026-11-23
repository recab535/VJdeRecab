extends Node

## Autoload central: carga el catálogo oficial (data/especies_68.json)
## y gestiona la persistencia del progreso del jugador en user://savegame.json.

const CATALOG_PATH: String = "res://data/especies_68.json"
const SAVE_PATH: String = "user://savegame.json"

signal catalog_loaded(total_species: int)
signal save_loaded
signal resources_changed(oro: int, comida: int, gemas: int)

var elementos_by_id: Dictionary = {}
var especies_by_id: Dictionary = {}
var multiplicadores: Dictionary = {}
var reglas_cruce: Dictionary = {}
var player_state: Dictionary = {}


func _ready() -> void:
	_load_catalog()
	load_game()


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
		"estructuras": [],
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

	save_loaded.emit()
	_emit_resources()


func save_game() -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[GameCore] No se pudo escribir en: " + SAVE_PATH)
		return false
	file.store_string(JSON.stringify(player_state, "\t"))
	return true


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
