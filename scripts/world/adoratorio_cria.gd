extends Node3D

## Adoratorio de Cría: altar místico de piedra con cristales brillantes.
## Al clicarlo abre directamente el panel de Cruce.

signal adoratorio_clicked

@onready var cristal_central: MeshInstance3D = $CristalCentral
@onready var area_click: Area3D = $AreaClick

var _time: float = 0.0
var _base_y: float = 1.15


func _ready() -> void:
	if cristal_central:
		_base_y = cristal_central.position.y
	if area_click:
		area_click.input_event.connect(_on_area_input_event)


func _process(delta: float) -> void:
	_time += delta
	if cristal_central:
		cristal_central.rotation.y += delta * 1.4
		cristal_central.position.y = _base_y + sin(_time * 2.2) * 0.08


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		adoratorio_clicked.emit()
