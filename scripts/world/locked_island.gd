extends Node3D
class_name LockedIsland

## Isla bloqueada interactiva: emite señal para abrir su vista previa al clicar.

signal preview_requested(island_info: Dictionary)

@export var island_id: int = 2
@export var island_name: String = "Isla 2 — Bruma Volcánica"
@export var unlock_cost_oro: int = 2500
@export var slots_disponibles: int = 4
@export var elementos_texto: String = "Fuego / Tierra"

@onready var area_click: Area3D = $AreaClick


func _ready() -> void:
	if area_click:
		area_click.input_event.connect(_on_area_input_event)


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		preview_requested.emit({
			"id": island_id,
			"nombre": island_name,
			"costo_oro": unlock_cost_oro,
			"slots": slots_disponibles,
			"elementos": elementos_texto
		})
