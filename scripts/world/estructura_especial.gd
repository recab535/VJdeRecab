extends Node3D

## Estructura especial clicable en la isla (Mina de Gemas, Portal de Historia,
## Campo de Entrenamiento, Guardería de Crías).

signal structure_clicked(kind: String, island_id: int)

@export var kind: String = "portal_historia"
@export var island_id: int = 1
@export var spin_node_path: NodePath = NodePath("")

@onready var area_click: Area3D = $AreaClick

var _spin_node: Node3D = null


func _ready() -> void:
	if not spin_node_path.is_empty():
		_spin_node = get_node_or_null(spin_node_path) as Node3D
	if area_click:
		area_click.input_event.connect(_on_area_input_event)


func _process(delta: float) -> void:
	if _spin_node:
		_spin_node.rotation.y += delta * 1.2


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		structure_clicked.emit(kind, island_id)
