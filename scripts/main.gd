extends Node3D

## Escena principal 2.5D: conecta HUD, CameraRig, hábitats, dragones 2D y GameCore.

const HABITAT_SCENE: PackedScene = preload("res://scenes/world/habitat_base.tscn")
const DRAGON_SCENE: PackedScene = preload("res://scenes/dragons/dragon_2d.tscn")
const COMBAT_ARENA_SCENE: PackedScene = preload("res://scenes/combat/combat_arena.tscn")
const BUILD_SLOT_SCRIPT: Script = preload("res://scripts/world/build_slot.gd")

@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HudBasic = $HUD
@onready var isla_inicial: Node3D = $IslaInicial
@onready var isla_bloqueada: LockedIsland = $IslaBloqueadaPreview
@onready var slots_container: Node3D = $IslaInicial/SlotsConstruibles
@onready var bestiario_panel: BestiarioPanel = $HUD/RootControl/BestiarioPanel
@onready var breeding_panel: BreedingPanel = $HUD/RootControl/BreedingPanel
@onready var nest_panel: NestPanel = $HUD/RootControl/NestPanel
@onready var shop_panel: ShopPanel = $HUD/RootControl/ShopPanel

var _built_habitats: Dictionary = {}
var _active_combat_arena: CombatArena = null
var _active_feed_filter_uids: Array[int] = []
var _pending_habitat_purchase: Dictionary = {}
var _selected_habitat: HabitatBase = null


func _ready() -> void:
	hud.rotate_left_requested.connect(camera_rig.rotate_left)
	hud.rotate_right_requested.connect(camera_rig.rotate_right)
	hud.panel_requested.connect(_on_panel_requested)
	hud.unlock_island_requested.connect(_on_unlock_island_requested)
	hud.feed_dragon_requested.connect(_on_feed_dragon_requested)
	hud.collect_habitat_oro_requested.connect(_on_collect_habitat_oro_requested)
	hud.open_habitat_feed_requested.connect(_on_open_habitat_feed_requested)

	if isla_bloqueada:
		isla_bloqueada.preview_requested.connect(_on_island_preview_requested)

	if breeding_panel:
		breeding_panel.breeding_completed.connect(_on_breeding_completed)
	if nest_panel:
		nest_panel.egg_hatched.connect(_on_egg_hatched)
	if shop_panel:
		shop_panel.habitat_purchase_requested.connect(_on_shop_habitat_requested)
		shop_panel.egg_purchase_requested.connect(_on_shop_egg_requested)
		shop_panel.farm_purchase_requested.connect(_on_shop_farm_requested)

	_setup_build_slots()

	if has_node("/root/GameCore"):
		var core: Node = get_node("/root/GameCore")
		core.resources_changed.connect(hud.set_resources)
		core.dragon_leveled_up.connect(_on_dragon_leveled_up)
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
			_spawn_habitat_at_slot(int(est.get("slot_index", 0)), int(est.get("elemento_id", 1)))

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


func _spawn_habitat_at_slot(slot_index: int, elemento_id: int = 1) -> HabitatBase:
	if _built_habitats.has(slot_index):
		return _built_habitats[slot_index]
	var all_slots: Array[Node3D] = _get_all_slot_nodes()
	var slot_node: Node3D = all_slots[slot_index] if slot_index >= 0 and slot_index < all_slots.size() else null
	if slot_node == null:
		return null
	var hab: HabitatBase = HABITAT_SCENE.instantiate() as HabitatBase
	hab.elemento_id = elemento_id
	slot_node.add_child(hab)
	hab.position = Vector3.ZERO
	hab.set_element_theme(elemento_id)
	hab.habitat_clicked.connect(_on_habitat_clicked)
	_built_habitats[slot_index] = hab
	if slot_node is BuildSlot:
		(slot_node as BuildSlot).set_placement_highlight(false, false)
	return hab


func _spawn_dragon_into_free_habitat(core: Node, dragon_data: Dictionary) -> bool:
	var sp_id: int = int(dragon_data.get("especie_id", 1))
	var d_uid: int = int(dragon_data.get("uid", -1))
	var d_nivel: int = maxi(1, int(dragon_data.get("nivel", 1)))
	var sp: Dictionary = core.get_species(sp_id)
	for slot_idx: int in _built_habitats.keys():
		var hab: HabitatBase = _built_habitats[slot_idx]
		if hab.has_free_slot():
			var d_node: Dragon2D = DRAGON_SCENE.instantiate() as Dragon2D
			hab.place_dragon(d_node, d_uid)
			d_node.setup_visual(
				sp_id,
				str(sp.get("nombre", "Dragón Terracota")),
				str(sp.get("sprite_prefijo", "dragon_terracota")),
				str(dragon_data.get("etapa", "cria")),
				d_uid,
				d_nivel
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
			_close_overlay_panels()
			if shop_panel:
				var oro_actual: int = int(core.get_resources().get("oro", 0))
				shop_panel.open_shop(oro_actual)
				hud.show_status_message("Tienda abierta: elige una categoría.")
		"Cruce":
			_close_overlay_panels()
			if breeding_panel:
				breeding_panel.open_breeding()
				hud.show_status_message("Selector de Cruce abierto.")
		"Nido":
			_close_overlay_panels()
			if nest_panel:
				nest_panel.open_nest()
				hud.show_status_message("Nido de incubación abierto.")
		"Alimentar":
			_close_overlay_panels()
			_active_feed_filter_uids.clear()
			_open_feed_panel(core, _active_feed_filter_uids, 0)
		"Bestiario":
			_close_overlay_panels()
			if bestiario_panel:
				bestiario_panel.open_bestiario()
				hud.show_status_message("Bestiario abierto.")
		"Combate":
			_close_overlay_panels()
			_open_combat_arena()
		_:
			hud.show_status_message("Panel %s disponible en próxima iteración." % panel_name)


func _close_overlay_panels() -> void:
	if bestiario_panel and bestiario_panel.visible:
		bestiario_panel.visible = false
	if breeding_panel and breeding_panel.visible:
		breeding_panel.visible = false
	if nest_panel and nest_panel.visible:
		nest_panel.visible = false
	if shop_panel and shop_panel.visible:
		shop_panel.visible = false
	if hud:
		hud.hide_dragon_feed_panel()
		hud.hide_island_preview()
		hud.hide_habitat_menu()


func _on_breeding_completed(res: Dictionary) -> void:
	hud.show_status_message(str(res.get("msg", "")))


func _on_egg_hatched(res: Dictionary) -> void:
	if not has_node("/root/GameCore"):
		return
	var core: Node = get_node("/root/GameCore")
	if res.get("ok", false):
		var placed: bool = _spawn_dragon_into_free_habitat(core, res.get("dragon", {}))
		var extra: String = "" if placed else " (Construye otro hábitat en Tienda para alojarlo)"
		hud.show_status_message(str(res.get("msg", "")) + extra)
	else:
		hud.show_status_message(str(res.get("msg", "")))


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


func _on_habitat_clicked(hab: HabitatBase) -> void:
	if not has_node("/root/GameCore") or hab == null:
		return
	_close_overlay_panels()
	_selected_habitat = hab
	var core: Node = get_node("/root/GameCore")
	var elem_info: Dictionary = core.get_element(hab.elemento_id)
	var elem_name: String = str(elem_info.get("nombre", "Tierra"))
	var oro_acum: int = int(floor(hab.accumulated_oro))
	hud.show_habitat_menu(
		"Hábitat %s (%d/%d)" % [elem_name, hab.dragons_count, hab.capacidad_maxima],
		oro_acum,
		not hab.hosted_dragon_uids.is_empty()
	)


func _on_collect_habitat_oro_requested() -> void:
	if _selected_habitat == null or not has_node("/root/GameCore"):
		return
	var collected: int = _selected_habitat.collect_oro()
	if collected > 0:
		get_node("/root/GameCore").add_oro(collected)
		hud.show_status_message("¡Recogiste +%d Oro del hábitat!" % collected)
	_on_habitat_clicked(_selected_habitat)


func _on_open_habitat_feed_requested() -> void:
	if _selected_habitat == null or not has_node("/root/GameCore"):
		return
	if _selected_habitat.hosted_dragon_uids.is_empty():
		hud.show_status_message("Este hábitat está vacío.")
		return
	var core: Node = get_node("/root/GameCore")
	_active_feed_filter_uids = _selected_habitat.hosted_dragon_uids.duplicate()
	hud.hide_habitat_menu()
	_open_feed_panel(core, _active_feed_filter_uids, 0)


func _on_feed_dragon_requested(dragon_uid: int) -> void:
	if not has_node("/root/GameCore"):
		return
	var core: Node = get_node("/root/GameCore")
	var res: Dictionary = core.feed_dragon(dragon_uid)
	hud.show_status_message(str(res.get("msg", "")))
	var keep_idx: int = hud.get_feed_selected_index()
	_open_feed_panel(core, _active_feed_filter_uids, keep_idx)


func _on_dragon_leveled_up(dragon_uid: int, new_nivel: int, new_etapa: String) -> void:
	for hab_var: Variant in _built_habitats.values():
		if hab_var is HabitatBase:
			var hab: HabitatBase = hab_var
			if hab.refresh_dragon_visual(dragon_uid, new_nivel, new_etapa):
				break


func _open_feed_panel(core: Node, filter_uids: Array[int], selected_index: int) -> void:
	var info_list: Array[Dictionary] = _build_feed_info_list(core, filter_uids)
	if info_list.is_empty():
		hud.show_status_message("No hay dragones disponibles para alimentar.")
		return
	var comida_actual: int = int(core.get_resources().get("comida", 0))
	hud.show_dragon_feed_panel(info_list, comida_actual, selected_index)


func _build_feed_info_list(core: Node, filter_uids: Array[int]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for d_var: Variant in core.player_state.get("dragones", []):
		if not (d_var is Dictionary):
			continue
		var d: Dictionary = d_var
		var uid: int = int(d.get("uid", -1))
		if not filter_uids.is_empty() and not filter_uids.has(uid):
			continue
		var sp: Dictionary = core.get_species(int(d.get("especie_id", 1)))
		var nivel: int = maxi(1, int(d.get("nivel", 1)))
		var stats: Dictionary = core.get_dragon_stats(d)
		result.append({
			"uid": uid,
			"nombre": str(sp.get("nombre", "Dragón")),
			"nivel": nivel,
			"max_nivel": core.MAX_DRAGON_LEVEL,
			"etapa": str(d.get("etapa", "cria")),
			"cost_comida": core.get_feed_cost(nivel),
			"hp": int(stats.get("hp", 100)),
			"atk": int(stats.get("atk", 20)),
			"spd": int(stats.get("spd", 15)),
			"oro_por_min": int(stats.get("oro_por_min", 12))
		})
	return result


func _setup_build_slots() -> void:
	var all_slots: Array[Node3D] = []
	if slots_container:
		for c: Node in slots_container.get_children():
			if c is Node3D:
				all_slots.append(c)
	if isla_bloqueada and isla_bloqueada.slots_container:
		for c: Node in isla_bloqueada.slots_container.get_children():
			if c is Node3D:
				all_slots.append(c)

	for i: int in range(all_slots.size()):
		var slot: Node3D = all_slots[i]
		if slot.get_script() == null:
			slot.set_script(BUILD_SLOT_SCRIPT)
			slot._ready()
		slot.set("slot_index", i)
		if slot.has_signal("slot_clicked") and not slot.is_connected("slot_clicked", _on_build_slot_clicked):
			slot.connect("slot_clicked", _on_build_slot_clicked)
		if slot.has_method("set_placement_highlight"):
			slot.call("set_placement_highlight", false, not _built_habitats.has(i))


func _on_shop_habitat_requested(elemento_id: int, cost_oro: int, nombre: String) -> void:
	if _find_next_free_slot() == -1:
		hud.show_status_message("No quedan espacios libres en las islas desbloqueadas.")
		return
	_pending_habitat_purchase = {"elemento_id": elemento_id, "cost_oro": cost_oro, "nombre": nombre}
	_set_placement_mode(true)
	hud.show_status_message("Modo colocación: clica un espacio verde para construir %s (Esc para cancelar)." % nombre)


func _on_shop_egg_requested(especie_id: int, cost_oro: int) -> void:
	if has_node("/root/GameCore"):
		var res: Dictionary = get_node("/root/GameCore").buy_egg(especie_id, cost_oro)
		hud.show_status_message(str(res.get("msg", "")))


func _on_shop_farm_requested(cost_oro: int) -> void:
	if has_node("/root/GameCore"):
		var res: Dictionary = get_node("/root/GameCore").buy_food_farm(cost_oro)
		hud.show_status_message(str(res.get("msg", "")))


func _set_placement_mode(active: bool) -> void:
	var all_slots: Array[Node3D] = _get_all_slot_nodes()
	for i: int in range(all_slots.size()):
		var slot: Node3D = all_slots[i]
		if slot.has_method("set_placement_highlight"):
			slot.call("set_placement_highlight", active, not _built_habitats.has(i))


func _on_build_slot_clicked(slot_node: Node3D) -> void:
	if _pending_habitat_purchase.is_empty() or not has_node("/root/GameCore"):
		return
	var slot_idx: int = int(slot_node.get("slot_index"))
	if _built_habitats.has(slot_idx):
		hud.show_status_message("Ese espacio ya está ocupado.")
		return
	var core: Node = get_node("/root/GameCore")
	var elem_id: int = int(_pending_habitat_purchase.get("elemento_id", 1))
	var cost: int = int(_pending_habitat_purchase.get("cost_oro", 250))
	var res: Dictionary = core.build_habitat(slot_idx, elem_id, cost)
	if res.get("ok", false):
		_spawn_habitat_at_slot(slot_idx, elem_id)
	_pending_habitat_purchase.clear()
	_set_placement_mode(false)
	hud.show_status_message(str(res.get("msg", "")))


func _unhandled_input(event: InputEvent) -> void:
	if not _pending_habitat_purchase.is_empty() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_pending_habitat_purchase.clear()
		_set_placement_mode(false)
		hud.show_status_message("Modo colocación cancelado.")
