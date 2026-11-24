class_name IslandGrid
extends RefCounted

## Matriz lógica discreta 14x14 proyectada sobre cada isla flotante.
## Cada celda registra isUnlocked (parcela comprada) e isOccupied (estructura/obstáculo).

const GRID_SIZE: int = 14
const PARCEL_SIZE: int = 7

const FOOTPRINT_SIZES: Dictionary = {
	"baldosa": Vector2i(1, 1),
	"decoracion": Vector2i(2, 2),
	"obstaculo": Vector2i(2, 2),
	"granja": Vector2i(3, 3),
	"guarderia": Vector2i(3, 3),
	"entrenamiento": Vector2i(3, 3),
	"habitat": Vector2i(3, 3),
	"habitat_grande": Vector2i(4, 4),
	"templo": Vector2i(4, 4),
	"portal": Vector2i(4, 4),
	"adoratorio": Vector2i(4, 4),
	"coliseo": Vector2i(5, 5)
}

var cells: Array = []


func _init() -> void:
	cells.clear()
	for z: int in range(GRID_SIZE):
		var row: Array = []
		for x: int in range(GRID_SIZE):
			row.append({
				"isUnlocked": false,
				"isOccupied": false,
				"occupant_id": ""
			})
		cells.append(row)


static func get_footprint(kind: String) -> Vector2i:
	return FOOTPRINT_SIZES.get(kind, Vector2i(3, 3))


func get_parcel_for_cell(cell: Vector2i) -> int:
	var px: int = 0 if cell.x < PARCEL_SIZE else 1
	var pz: int = 0 if cell.y < PARCEL_SIZE else 1
	return pz * 2 + px


func sync_unlocked_parcels(unlocked_parcels: Array) -> void:
	for z: int in range(GRID_SIZE):
		for x: int in range(GRID_SIZE):
			var p_idx: int = get_parcel_for_cell(Vector2i(x, z))
			cells[z][x]["isUnlocked"] = unlocked_parcels.has(p_idx)


func clear_occupants() -> void:
	for z: int in range(GRID_SIZE):
		for x: int in range(GRID_SIZE):
			cells[z][x]["isOccupied"] = false
			cells[z][x]["occupant_id"] = ""


func can_place(origin: Vector2i, footprint: Vector2i, ignore_id: String = "") -> bool:
	if origin.x < 0 or origin.y < 0:
		return false
	if origin.x + footprint.x > GRID_SIZE or origin.y + footprint.y > GRID_SIZE:
		return false
	for dz: int in range(footprint.y):
		for dx: int in range(footprint.x):
			var cell: Dictionary = cells[origin.y + dz][origin.x + dx]
			if not bool(cell["isUnlocked"]):
				return false
			if bool(cell["isOccupied"]) and str(cell["occupant_id"]) != ignore_id:
				return false
	return true


func occupy(origin: Vector2i, footprint: Vector2i, occupant_id: String) -> bool:
	if not can_place(origin, footprint, occupant_id):
		return false
	for dz: int in range(footprint.y):
		for dx: int in range(footprint.x):
			cells[origin.y + dz][origin.x + dx]["isOccupied"] = true
			cells[origin.y + dz][origin.x + dx]["occupant_id"] = occupant_id
	return true


func vacate(occupant_id: String) -> void:
	for z: int in range(GRID_SIZE):
		for x: int in range(GRID_SIZE):
			if str(cells[z][x]["occupant_id"]) == occupant_id:
				cells[z][x]["isOccupied"] = false
				cells[z][x]["occupant_id"] = ""


func local_to_cell(local_pos: Vector3, footprint: Vector2i = Vector2i.ONE) -> Vector2i:
	var gx: int = int(floor(local_pos.x + 7.0 - float(footprint.x) * 0.5))
	var gz: int = int(floor(local_pos.z + 7.0 - float(footprint.y) * 0.5))
	return Vector2i(clampi(gx, 0, GRID_SIZE - footprint.x), clampi(gz, 0, GRID_SIZE - footprint.y))


func cell_to_local(origin: Vector2i, footprint: Vector2i = Vector2i.ONE, y_height: float = 0.60) -> Vector3:
	var wx: float = -7.0 + float(origin.x) + float(footprint.x) * 0.5
	var wz: float = -7.0 + float(origin.y) + float(footprint.y) * 0.5
	return Vector3(wx, y_height, wz)
