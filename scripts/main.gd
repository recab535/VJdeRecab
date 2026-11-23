extends Node3D

## Escena principal 2.5D: conecta HUD, CameraRig, islas bloqueadas y GameCore.

@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HudBasic = $HUD
@onready var isla_bloqueada: LockedIsland = $IslaBloqueadaPreview
@onready var slots_container: Node3D = $IslaInicial/SlotsConstruibles


func _ready() -> void:
	hud.rotate_left_requested.connect(camera_rig.rotate_left)
	hud.rotate_right_requested.connect(camera_rig.rotate_right)
	hud.panel_requested.connect(_on_panel_requested)
	hud.unlock_island_requested.connect(_on_unlock_island_requested)

	if isla_bloqueada:
		isla_bloqueada.preview_requested.connect(_on_island_preview_requested)

	if has_node("/root/GameCore"):
		var core: Node = get_node("/root/GameCore")
		core.resources_changed.connect(hud.set_resources)
		var res: Dictionary = core.get_resources()
		hud.set_resources(int(res.get("oro", 0)), int(res.get("comida", 0)), int(res.get("gemas", 0)))
	else:
		hud.set_resources(1000, 500, 25)


func _on_island_preview_requested(info: Dictionary) -> void:
	var oro_actual: int = 1000
	if has_node("/root/GameCore"):
		var res: Dictionary = get_node("/root/GameCore").get_resources()
		oro_actual = int(res.get("oro", 0))
	hud.show_island_preview(info, oro_actual)


func _on_unlock_island_requested(_island_id: int, cost_oro: int) -> void:
	hud.show_status_message("Oro insuficiente o pendiente de desbloqueo (%d Oro)." % cost_oro)


func _on_panel_requested(panel_name: String) -> void:
	hud.show_status_message("Panel seleccionado: %s" % panel_name)
