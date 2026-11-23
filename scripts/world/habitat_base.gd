extends Node3D
class_name HabitatBase

## Plataforma 3D de hábitat con puntos de anclaje para dragones 2.5D y sombra.

@export var elemento_id: int = 1
@export var capacidad_maxima: int = 2

@onready var spots: Array[Node3D] = [$AreaDragones/DragonSpot1, $AreaDragones/DragonSpot2]

var dragons_count: int = 0


func has_free_slot() -> bool:
	return dragons_count < capacidad_maxima and dragons_count < spots.size()


func place_dragon(dragon_node: Node3D) -> bool:
	if not has_free_slot():
		return false
	var spot: Node3D = spots[dragons_count]
	spot.add_child(dragon_node)
	dragon_node.position = Vector3.ZERO
	dragons_count += 1
	return true
