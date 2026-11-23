extends Node3D
class_name HabitatBase

## Plataforma 3D de hábitat con puntos de anclaje para dragones 2.5D y sombra.

signal habitat_clicked(habitat: HabitatBase)

@export var elemento_id: int = 1
@export var capacidad_maxima: int = 2

@onready var spots: Array[Node3D] = [$AreaDragones/DragonSpot1, $AreaDragones/DragonSpot2]
@onready var area_click: Area3D = get_node_or_null("AreaClick")

var dragons_count: int = 0
var hosted_dragon_uids: Array[int] = []
var hosted_dragons: Array[Dragon2D] = []


func _ready() -> void:
	if area_click:
		area_click.input_event.connect(_on_area_input_event)


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		habitat_clicked.emit(self)


func has_free_slot() -> bool:
	return dragons_count < capacidad_maxima and dragons_count < spots.size()


func place_dragon(dragon_node: Node3D, dragon_uid: int = -1) -> bool:
	if not has_free_slot():
		return false
	var spot: Node3D = spots[dragons_count]
	spot.add_child(dragon_node)
	dragon_node.position = Vector3.ZERO
	dragons_count += 1
	if dragon_uid > 0:
		hosted_dragon_uids.append(dragon_uid)
	if dragon_node is Dragon2D:
		hosted_dragons.append(dragon_node as Dragon2D)
	return true


func refresh_dragon_visual(dragon_uid: int, new_nivel: int, new_etapa: String) -> bool:
	for d_node: Dragon2D in hosted_dragons:
		if is_instance_valid(d_node) and d_node.dragon_uid == dragon_uid:
			d_node.update_progression(new_nivel, new_etapa)
			return true
	return false
