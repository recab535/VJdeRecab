extends Node3D

## Escena principal 2.5D: conecta el HUD con el rig de cámara de la isla flotante.

@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HudBasic = $HUD


func _ready() -> void:
	hud.rotate_left_requested.connect(camera_rig.rotate_left)
	hud.rotate_right_requested.connect(camera_rig.rotate_right)
	hud.panel_requested.connect(_on_panel_requested)
	if has_node("/root/GameCore"):
		var core: Node = get_node("/root/GameCore")
		core.resources_changed.connect(hud.set_resources)
		var res: Dictionary = core.get_resources()
		hud.set_resources(int(res.get("oro", 0)), int(res.get("comida", 0)), int(res.get("gemas", 0)))
	else:
		hud.set_resources(1000, 500, 25)


func _on_panel_requested(panel_name: String) -> void:
	print("[HUD] Botón presionado: ", panel_name)
