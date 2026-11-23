extends Node3D

## Escena principal 2.5D: conecta HUD, CameraRig, hábitats, dragones 2D y GameCore.

const HABITAT_SCENE: PackedScene = preload("res://scenes/world/habitat_base.tscn")
const DRAGON_SCENE: PackedScene = preload("res://scenes/dragons/dragon_2d.tscn")
const COMBAT_ARENA_SCENE: PackedScene = preload("res://scenes/combat/combat_arena.tscn")

@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HudBasic = $HUD
@onready var isla_inicial: Node3D = $IslaInicial
@onready var isla_bloqueada: LockedIsland = $IslaBloqueadaPreview
@onready var slots_container: Node3D = $IslaInicial/SlotsConstruibles
@onready var bestiario_panel: BestiarioPanel = $HUD/RootControl/BestiarioPanel

var _built_habitats: Dictionary = {}
var _active_combat_arena: CombatArena = null


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
		_restore_world_from_save(core)
	else:
		hud.set_resources(1000, 500, 25)


func _restore_world_from_save(core: Node) -> void:
	if isla_bloqueada and core.is_island_unlocked(isla_bloqueada.island_id):
		isla_bloqueada.set_unlocked(true)

	for est: Variant in core.player_state.get("estructuras", []):
		if est is Dictionary:
			_spawn_habitat_at_slot(int(est.get("slot_index", 0)))

	for d: Variant in core.player_state.get("dragones", []):
		if d is Dictionary:
			_spawn_dragon_into_free_habitat(core, d)


func _get_all_slot_nodes() -> Array[Node3D]:
	var all_slots: Array[Node3D] = []
	if slots_container:
		for child: Node in slots_container.get_children():
			if child is Node3D:
				all_slots.append(child)
	if isla_bloqueada and isla_bloqueada.is_unlocked and isla_bloqueada.slots_container:
		for child: Node in isla_bloqueada.slots_container.get_children():
			if child is Node3D:
				all_slots.append(child)
	return all_slots


func _spawn_habitat_at_slot(slot_index: int) -> HabitatBase:
	if _built_habitats.has(slot_index):
		return _built_habitats[slot_index]
	var all_slots: Array[Node3D] = _get_all_slot_nodes()
	var slot_node: Node3D = all_slots[slot_index] if slot_index >= 0 and slot_index < all_slots.size() else null
	if slot_node == null:
		return null
	var hab: HabitatBase = HABITAT_SCENE.instantiate() as HabitatBase
	slot_node.add_child(hab)
	hab.position = Vector3.ZERO
	_built_habitats[slot_index] = hab
	return hab


func _spawn_dragon_into_free_habitat(core: Node, dragon_data: Dictionary) -> bool:
	var sp_id: int = int(dragon_data.get("especie_id", 1))
	var sp: Dictionary = core.get_species(sp_id)
	for slot_idx: int in _built_habitats.keys():
		var hab: HabitatBase = _built_habitats[slot_idx]
		if hab.has_free_slot():
			var d_node: Dragon2D = DRAGON_SCENE.instantiate() as Dragon2D
			hab.place_dragon(d_node)
			d_node.setup_visual(
				sp_id,
				str(sp.get("nombre", "Dragón Terracota")),
				str(sp.get("sprite_prefijo", "dragon_terracota")),
				str(dragon_data.get("etapa", "cria"))
			)
			return true
	return false


func _on_island_preview_requested(info: Dictionary) -> void:
	var oro_actual: int = 1000
	if has_node("/root/GameCore"):
		var res: Dictionary = get_node("/root/GameCore").get_resources()
		oro_actual = int(res.get("oro", 0))
	hud.show_island_preview(info, oro_actual)


func _on_unlock_island_requested(island_id: int, cost_oro: int) -> void:
	if not has_node("/root/GameCore"):
		hud.show_status_message("GameCore no disponible para desbloquear la isla %d." % island_id)
		return

	var core: Node = get_node("/root/GameCore")
	var res: Dictionary = core.unlock_island(island_id, cost_oro)
	if res.get("ok", false):
		if isla_bloqueada and isla_bloqueada.island_id == island_id:
			isla_bloqueada.set_unlocked(true)
		hud.hide_island_preview()
	hud.show_status_message(str(res.get("msg", "")))


func _on_panel_requested(panel_name: String) -> void:
	if not has_node("/root/GameCore"):
		hud.show_status_message("Panel seleccionado: %s" % panel_name)
		return

	var core: Node = get_node("/root/GameCore")
	match panel_name:
		"Tienda":
			var next_slot: int = _find_next_free_slot()
			if next_slot == -1:
				hud.show_status_message("No quedan espacios libres en las islas desbloqueadas.")
				return
			var res: Dictionary = core.build_habitat(next_slot, 1)
			if res.get("ok", false):
				_spawn_habitat_at_slot(next_slot)
			hud.show_status_message(str(res.get("msg", "")))
		"Cruce":
			var res: Dictionary = core.start_breeding(1, 2)
			hud.show_status_message(str(res.get("msg", "")))
		"Nido":
			var res: Dictionary = core.hatch_next_egg()
			if res.get("ok", false):
				var placed: bool = _spawn_dragon_into_free_habitat(core, res.get("dragon", {}))
				var extra: String = "" if placed else " (Construye otro hábitat en Tienda para alojarlo)"
				hud.show_status_message(str(res.get("msg", "")) + extra)
			else:
				hud.show_status_message(str(res.get("msg", "")))
		"Bestiario":
			if bestiario_panel:
				bestiario_panel.open_bestiario()
				hud.show_status_message("Bestiario abierto.")
		"Combate":
			_open_combat_arena()
		_:
			hud.show_status_message("Panel %s disponible en próxima iteración." % panel_name)


func _open_combat_arena() -> void:
	if is_instance_valid(_active_combat_arena):
		return

	_active_combat_arena = COMBAT_ARENA_SCENE.instantiate() as CombatArena
	add_child(_active_combat_arena)

	if isla_inicial:
		isla_inicial.visible = false
	if isla_bloqueada:
		isla_bloqueada.visible = false
	hud.visible = false
	if camera_rig and camera_rig.camera:
		camera_rig.camera.current = false
	if _active_combat_arena.arena_camera:
		_active_combat_arena.arena_camera.current = true

	if _active_combat_arena.combat_manager:
		_active_combat_arena.combat_manager.combat_finished.connect(_on_combat_finished)
	else:
		_active_combat_arena.retreat_requested.connect(func() -> void: _on_combat_finished(false, {}))


func _on_combat_finished(victory: bool, rewards: Dictionary) -> void:
	if is_instance_valid(_active_combat_arena):
		_active_combat_arena.queue_free()
		_active_combat_arena = null

	if isla_inicial:
		isla_inicial.visible = true
	if isla_bloqueada:
		isla_bloqueada.visible = true
	hud.visible = true
	if camera_rig and camera_rig.camera:
		camera_rig.camera.current = true

	if victory:
		hud.show_status_message("¡Capítulo 1 superado! +%d Oro, +%d Comida, +%d Gemas." % [
			int(rewards.get("oro", 0)),
			int(rewards.get("comida", 0)),
			int(rewards.get("gemas", 0))
		])
	else:
		hud.show_status_message("Combate finalizado. Regresaste a la isla.")


func _find_next_free_slot() -> int:
	var all_slots: Array[Node3D] = _get_all_slot_nodes()
	for i: int in range(all_slots.size()):
		if not _built_habitats.has(i):
			return i
	return -1
