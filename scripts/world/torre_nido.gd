extends Node3D

## Torre Nido: torre incubadora con un huevo 3D visible en la cima cuando hay huevos en el Nido.
## Al clicarla abre directamente el panel del Nido.

signal torre_nido_clicked

@onready var huevo_visual: MeshInstance3D = $HuevoVisual
@onready var area_click: Area3D = $AreaClick

var _time: float = 0.0
var _egg_base_y: float = 1.48


func _ready() -> void:
	if huevo_visual:
		_egg_base_y = huevo_visual.position.y
	if area_click:
		area_click.input_event.connect(_on_area_input_event)

	var core: Node = get_node_or_null("/root/GameCore")
	if core:
		if core.has_signal("nest_updated"):
			core.nest_updated.connect(_refresh_egg_visual)
		_refresh_egg_visual()


func _process(delta: float) -> void:
	if huevo_visual and huevo_visual.visible:
		_time += delta * 2.6
		huevo_visual.position.y = _egg_base_y + sin(_time) * 0.05
		huevo_visual.rotation.z = sin(_time * 1.5) * 0.08


func _refresh_egg_visual() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if huevo_visual == null or core == null:
		return
	var huevos: Array = core.get_nest_eggs()
	huevo_visual.visible = not huevos.is_empty()


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		torre_nido_clicked.emit()
