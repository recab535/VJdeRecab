extends Node3D
class_name LockedIsland

## Isla bloqueada interactiva: emite señal para abrir su vista previa al clicar.

signal preview_requested(island_info: Dictionary)

@export var island_id: int = 2
@export var island_name: String = "Isla 2 — Bruma Volcánica"
@export var unlock_cost_oro: int = 2500
@export var slots_disponibles: int = 4
@export var elementos_texto: String = "Fuego / Tierra"
@export var unlocked_material: Material

@onready var area_click: Area3D = $AreaClick
@onready var mesh_bloqueada: MeshInstance3D = $MeshBloqueada
@onready var slots_container: Node3D = $SlotsConstruibles

var is_unlocked: bool = false


func _ready() -> void:
	if area_click:
		area_click.input_event.connect(_on_area_input_event)
	if slots_container:
		slots_container.visible = is_unlocked


func set_unlocked(unlocked: bool) -> void:
	is_unlocked = unlocked
	if slots_container:
		slots_container.visible = unlocked
	if area_click:
		area_click.input_ray_pickable = not unlocked
	if mesh_bloqueada and unlocked:
		if unlocked_material != null:
			mesh_bloqueada.material_override = unlocked_material
		else:
			var fallback_mat := StandardMaterial3D.new()
			fallback_mat.albedo_color = Color(0.55, 0.30, 0.22, 1.0)
			fallback_mat.roughness = 0.88
			mesh_bloqueada.material_override = fallback_mat


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if is_unlocked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		preview_requested.emit({
			"id": island_id,
			"nombre": island_name,
			"costo_oro": unlock_cost_oro,
			"slots": slots_disponibles,
			"elementos": elementos_texto
		})
