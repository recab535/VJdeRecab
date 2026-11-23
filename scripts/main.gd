extends Node3D

## Escena principal 2.5D: conecta el HUD con el rig de cámara de la isla flotante.

@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HudBasic = $HUD


func _ready() -> void:
	hud.rotate_left_requested.connect(camera_rig.rotate_left)
	hud.rotate_right_requested.connect(camera_rig.rotate_right)
	hud.panel_requested.connect(_on_panel_requested)
	hud.set_resources(1000, 500, 25)


func _on_panel_requested(panel_name: String) -> void:
	print("[HUD] Botón presionado: ", panel_name)
