extends Node3D
class_name HabitatBase

## Plataforma 3D de hábitat con puntos de anclaje para dragones 2.5D y sombra.

signal habitat_clicked(habitat: HabitatBase)

@export var elemento_id: int = 1
@export var capacidad_maxima: int = 2

const ELEMENT_COLORS: Dictionary = {
	1: Color(0.64, 0.48, 0.30, 1.0),
	2: Color(0.86, 0.32, 0.18, 1.0),
	3: Color(0.22, 0.56, 0.88, 1.0),
	4: Color(0.28, 0.72, 0.34, 1.0),
	5: Color(0.92, 0.78, 0.22, 1.0),
	6: Color(0.58, 0.86, 0.96, 1.0),
	7: Color(0.62, 0.66, 0.72, 1.0),
	8: Color(0.34, 0.24, 0.44, 1.0)
}

@onready var spots: Array[Node3D] = [$AreaDragones/DragonSpot1, $AreaDragones/DragonSpot2]
@onready var area_click: Area3D = get_node_or_null("AreaClick")

var dragons_count: int = 0
var hosted_dragon_uids: Array[int] = []
var hosted_dragons: Array[Dragon2D] = []


func _ready() -> void:
	if area_click:
		area_click.input_event.connect(_on_area_input_event)
	set_element_theme(elemento_id)


func set_element_theme(elem_id: int) -> void:
	elemento_id = elem_id
	var plat: MeshInstance3D = get_node_or_null("PlataformaHabitat") as MeshInstance3D
	if plat:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = ELEMENT_COLORS.get(elem_id, ELEMENT_COLORS[1])
		mat.roughness = 0.82
		plat.material_override = mat


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
