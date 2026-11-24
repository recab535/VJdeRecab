extends Node3D

## Escena principal 2.5D: gestiona el archipiélago de 5 islas consecutivas,
## parcelas, obstáculos, estructuras fijas, hábitats, dragones 2D, HUD y GameCore.

const HABITAT_SCENE_PATH: String = "res://scenes/world/habitat_base.tscn"
const DRAGON_SCENE_PATH: String = "res://scenes/dragons/dragon_2d.tscn"
const COMBAT_ARENA_SCENE_PATH: String = "res://scenes/combat/combat_arena.tscn"

var _habitat_scene_cache: PackedScene = null
var _dragon_scene_cache: PackedScene = null
var _combat_arena_scene_cache: PackedScene = null

@onready var archipielago: Node3D = $Archipielago
@onready var adoratorio_cria: Node3D = $Archipielago/Isla1/AdoratorioCria
@onready var adoratorio_extra: Node3D = $Archipielago/Isla1/AdoratorioExtra
@onready var torre_nido: Node3D = $Archipielago/Isla1/TorreNido
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: HudBasic = $HUD
@onready var bestiario_panel: Control = $HUD/RootControl/BestiarioPanel
@onready var breeding_panel: Control = $HUD/RootControl/BreedingPanel
@onready var nest_panel: Control = $HUD/RootControl/NestPanel
@onready var shop_panel: Control = $HUD/RootControl/ShopPanel
@onready var tutorial_dialog: Control = $HUD/RootControl/TutorialDialog
@onready var estructura_modal: Control = $HUD/RootControl/EstructuraModal
@onready var almacen_panel: Control = $HUD/RootControl/AlmacenPanel
@onready var campana_panel: Control = $HUD/RootControl/CampanaPanel

var _islands: Dictionary = {}
var _built_habitats: Dictionary = {}
var _booster_totems_root: Node3D = null
var _placed_tiles_count: int = 0
var _active_combat_arena: Node3D = null
var _active_feed_filter_uids: Array[int] = []
var _pending_habitat_purchase: Dictionary = {}
var _moving_habitat_slot_idx: int = -1
var _selected_habitat: HabitatBase = null
var _focused_island_id: int = 1


func _ready() -> void:
	hud.rotate_left_requested.connect(camera_rig.rotate_left)
	hud.rotate_right_requested.connect(camera_rig.rotate_right)
	hud.prev_island_requested.connect(camera_rig.focus_prev_island)
	hud.next_island_requested.connect(camera_rig.focus_next_island)
	hud.panel_requested.connect(_on_panel_requested)
	hud.unlock_island_requested.connect(_on_unlock_island_requested)
	hud.unlock_parcel_requested.connect(_on_unlock_parcel_requested)
	hud.clear_obstacle_requested.connect(_on_clear_obstacle_requested)
	hud.speedup_obstacle_requested.connect(_on_speedup_obstacle_requested)
	hud.feed_dragon_requested.connect(_on_feed_dragon_requested)
	hud.collect_habitat_oro_requested.connect(_on_collect_habitat_oro_requested)
	hud.open_habitat_feed_requested.connect(_on_open_habitat_feed_requested)
	hud.move_habitat_requested.connect(_on_move_habitat_requested)
	hud.context_panel_closed.connect(camera_rig.clear_entity_focus)
	camera_rig.focused_island_changed.connect(_on_focused_island_changed)

	if adoratorio_cria and adoratorio_cria.has_signal("adoratorio_clicked"):
		adoratorio_cria.connect("adoratorio_clicked", func() -> void:
			camera_rig.focus_on_target(adoratorio_cria.global_position, 13.5)
			_on_panel_requested("Cruce")
		)
	if adoratorio_extra and adoratorio_extra.has_signal("adoratorio_clicked"):
		adoratorio_extra.connect("adoratorio_clicked", func() -> void:
			camera_rig.focus_on_target(adoratorio_extra.global_position, 13.5)
			_on_panel_requested("Cruce")
		)
	if torre_nido and torre_nido.has_signal("torre_nido_clicked"):
		torre_nido.connect("torre_nido_clicked", func() -> void:
			camera_rig.focus_on_target(torre_nido.global_position, 13.5)
			_on_panel_requested("Nido")
		)
	if estructura_modal:
		if estructura_modal.has_signal("status_message"):
			estructura_modal.connect("status_message", hud.show_status_message)
		if estructura_modal.has_signal("nursery_dragon_stored"):
			estructura_modal.connect("nursery_dragon_stored", _on_nursery_dragon_stored)
		if estructura_modal.has_signal("nursery_dragon_retrieved"):
			estructura_modal.connect("nursery_dragon_retrieved", _on_nursery_dragon_retrieved)
	_connect_special_structures(archipielago)

	if breeding_panel and breeding_panel.has_signal("breeding_completed"):
		breeding_panel.connect("breeding_completed", _on_breeding_completed)
	if nest_panel and nest_panel.has_signal("egg_hatched"):
		nest_panel.connect("egg_hatched", _on_egg_hatched)
	if shop_panel:
		if shop_panel.has_signal("habitat_purchase_requested"):
			shop_panel.connect("habitat_purchase_requested", _on_shop_habitat_requested)
		if shop_panel.has_signal("status_message"):
			shop_panel.connect("status_message", hud.show_status_message)
	if almacen_panel:
		if almacen_panel.has_signal("status_message"):
			almacen_panel.connect("status_message", hud.show_status_message)
		if almacen_panel.has_signal("place_tile_requested"):
			almacen_panel.connect("place_tile_requested", _on_place_tile_requested)
	if campana_panel and campana_panel.has_signal("chapter_battle_requested"):
		campana_panel.connect("chapter_battle_requested", _on_chapter_battle_requested)

	_register_islands()
	_close_overlay_panels()

	if has_node("/root/GameCore"):
		var core: Node = get_node("/root/GameCore")
		core.resources_changed.connect(hud.set_resources)
		core.dragon_leveled_up.connect(_on_dragon_leveled_up)
		core.player_level_changed.connect(_on_player_level_changed)
		core.world_state_changed.connect(_sync_all_islands)
		core.obstacles_updated.connect(_sync_all_islands)
		core.boosters_updated.connect(_sync_booster_totems)

		var res: Dictionary = core.get_resources()
		hud.set_resources(int(res.get("oro", 0)), int(res.get("comida", 0)), int(res.get("gemas", 0)))
		var lvl: int = core.get_player_level()
		var exp_cur: int = int(core.player_state.get("exp_jugador", 0))
		hud.set_player_level(lvl, float(exp_cur) / float(core.get_player_exp_needed(lvl)))

		_sync_all_islands()
		_sync_booster_totems()
		_restore_world_from_save(core)
		if tutorial_dialog and core.has_method("is_tutorial_completed") and not core.is_tutorial_completed():
			tutorial_dialog.tutorial_finished.connect(core.complete_tutorial)
			tutorial_dialog.start_tutorial()
	else:
		hud.set_resources(1500, 500, 35)


func _register_islands() -> void:
	_islands.clear()
	if archipielago == null:
		return
	for child: Node in archipielago.get_children():
		if child is Node3D and "island_id" in child:
			var iid: int = int(child.get("island_id"))
			_islands[iid] = child
			if child.has_signal("island_locked_clicked"):
				child.connect("island_locked_clicked", _on_island_preview_requested)
			if child.has_signal("parcel_locked_clicked"):
				child.connect("parcel_locked_clicked", _on_parcel_preview_requested)
			if child.has_signal("slot_clicked_on_island"):
				child.connect("slot_clicked_on_island", _on_island_slot_clicked)
			if child.has_signal("obstacle_clicked_on_island"):
				child.connect("obstacle_clicked_on_island", _on_obstacle_clicked)


func _sync_all_islands() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	if adoratorio_extra:
		adoratorio_extra.visible = bool(core.player_state.get("segundo_adoratorio", false))
	var obs: Array = core.player_state.get("obstaculos", [])
	for iid: int in _islands.keys():
		var isl: Node3D = _islands[iid]
		if isl.has_method("apply_state"):
			isl.call("apply_state", core.is_island_unlocked(iid), core.get_unlocked_parcels(iid), obs)
		if isl.has_method("set_slots_placement_mode"):
			var show_grid: bool = (not _pending_habitat_purchase.is_empty()) or (_moving_habitat_slot_idx >= 0)
			isl.call("set_slots_placement_mode", show_grid, _built_habitats)


func _connect_special_structures(root: Node) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		if child.has_signal("structure_clicked") and not child.is_connected("structure_clicked", _on_special_structure_clicked):
			var node_ref: Node3D = child as Node3D
			child.connect("structure_clicked", func(k: String, iid: int) -> void:
				if node_ref:
					camera_rig.focus_on_target(node_ref.global_position, 13.5)
				_on_special_structure_clicked(k, iid)
			)
		_connect_special_structures(child)


func _on_special_structure_clicked(kind: String, island_id: int) -> void:
	_close_overlay_panels()
	if kind == "portal_historia":
		_on_panel_requested("Combate")
		return
	if estructura_modal and estructura_modal.has_method("open_for"):
		estructura_modal.call("open_for", kind, island_id)


func _restore_world_from_save(core: Node) -> void:
	for est: Variant in core.player_state.get("estructuras", []):
		if est is Dictionary:
			_spawn_habitat_at_slot(int(est.get("slot_index", 0)), int(est.get("elemento_id", 1)))

	for d: Variant in core.player_state.get("dragones", []):
		if d is Dictionary:
			_spawn_dragon_into_free_habitat(core, d)

	_sync_all_islands()


func _find_slot_node_by_global_index(global_slot_idx: int) -> Node3D:
	for iid: int in _islands.keys():
		var isl: Node3D = _islands[iid]
		var slots: Array = isl.get("slot_nodes") if "slot_nodes" in isl else []
		for sn: Variant in slots:
			if sn is Node3D and int(sn.get("slot_index")) == global_slot_idx:
				return sn as Node3D
	return null


func _spawn_habitat_at_slot(slot_index: int, elemento_id: int = 1) -> HabitatBase:
	if _built_habitats.has(slot_index):
		return _built_habitats[slot_index]
	var slot_node: Node3D = _find_slot_node_by_global_index(slot_index)
	if slot_node == null:
		return null
	if _habitat_scene_cache == null:
		_habitat_scene_cache = load(HABITAT_SCENE_PATH) as PackedScene
	var hab: HabitatBase = _habitat_scene_cache.instantiate() as HabitatBase
	hab.elemento_id = elemento_id
	slot_node.add_child(hab)
	hab.position = Vector3.ZERO
	hab.set_element_theme(elemento_id)
	hab.habitat_clicked.connect(_on_habitat_clicked)
	_built_habitats[slot_index] = hab
	if slot_node.has_method("set_placement_highlight"):
		slot_node.call("set_placement_highlight", false, false)
	return hab


func _spawn_dragon_into_free_habitat(core: Node, dragon_data: Dictionary) -> bool:
	var sp_id: int = int(dragon_data.get("especie_id", 1))
	var d_uid: int = int(dragon_data.get("uid", -1))
	var d_nivel: int = maxi(1, int(dragon_data.get("nivel", 1)))
	var sp: Dictionary = core.get_species(sp_id)
	var elem_prim: int = int(sp.get("elemento_primario_id", 0))
	var elem_sec_var: Variant = sp.get("elemento_secundario_id", null)
	var elem_sec: int = int(elem_sec_var) if elem_sec_var != null else 0

	var chosen_hab: HabitatBase = null
	for slot_idx: int in _built_habitats.keys():
		var hab: HabitatBase = _built_habitats[slot_idx]
		if hab.has_free_slot() and (hab.elemento_id == elem_prim or (elem_sec > 0 and hab.elemento_id == elem_sec)):
			chosen_hab = hab
			break
	if chosen_hab == null:
		for slot_idx: int in _built_habitats.keys():
			var hab: HabitatBase = _built_habitats[slot_idx]
			if hab.has_free_slot():
				chosen_hab = hab
				break

	if chosen_hab == null:
		return false

	if _dragon_scene_cache == null:
		_dragon_scene_cache = load(DRAGON_SCENE_PATH) as PackedScene
	var d_node: Dragon2D = _dragon_scene_cache.instantiate() as Dragon2D
	chosen_hab.place_dragon(d_node, d_uid)
	d_node.setup_visual(
		sp_id,
		str(sp.get("nombre", "Dragón Terracota")),
		str(sp.get("sprite_prefijo", "dragon_terracota")),
		str(dragon_data.get("etapa", "cria")),
		d_uid,
		d_nivel
	)
	chosen_hab.recalculate_oro_rate(core)
	return true


func _on_nursery_dragon_stored(dragon_uid: int) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	for hab_var: Variant in _built_habitats.values():
		if hab_var is HabitatBase:
			var hab: HabitatBase = hab_var as HabitatBase
			if hab.remove_dragon_by_uid(dragon_uid):
				hab.recalculate_oro_rate(core)
				break


func _on_nursery_dragon_retrieved(dragon_data: Dictionary) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null or dragon_data.is_empty():
		return
	var placed: bool = _spawn_dragon_into_free_habitat(core, dragon_data)
	if not placed:
		hud.show_status_message("Cría retirada, pero no hay espacio libre en hábitats. Construye un Hábitat.")


func _on_focused_island_changed(island_id: int) -> void:
	_focused_island_id = island_id
	hud.set_focused_island(island_id)


func _on_player_level_changed(level: int, exp_cur: int, exp_needed: int) -> void:
	hud.set_player_level(level, float(exp_cur) / float(maxi(1, exp_needed)))


func _on_island_preview_requested(info: Dictionary) -> void:
	if info.has("world_pos") and info["world_pos"] is Vector3:
		camera_rig.focus_on_target(info["world_pos"], 18.5)
	var core: Node = get_node_or_null("/root/GameCore")
	var oro_actual: int = int(core.get_resources().get("oro", 0)) if core else 0
	var lvl: int = core.get_player_level() if core else 1
	hud.show_island_preview(info, oro_actual, lvl)


func _on_parcel_preview_requested(_island_id: int, _parcel_idx: int, info: Dictionary) -> void:
	if info.has("world_pos") and info["world_pos"] is Vector3:
		camera_rig.focus_on_target(info["world_pos"], 15.0)
	var core: Node = get_node_or_null("/root/GameCore")
	var oro_actual: int = int(core.get_resources().get("oro", 0)) if core else 0
	var lvl: int = core.get_player_level() if core else 1
	hud.show_parcel_preview(info, oro_actual, lvl)


func _on_unlock_island_requested(island_id: int, cost_oro: int, level_req: int) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	var res: Dictionary = core.unlock_island_with_level(island_id, cost_oro, level_req)
	if res.get("ok", false):
		hud.hide_island_preview()
		_play_sfx("coin")
	hud.show_status_message(str(res.get("msg", "")))


func _on_unlock_parcel_requested(island_id: int, parcel_idx: int, cost_oro: int, level_req: int) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	var res: Dictionary = core.unlock_parcel(island_id, parcel_idx, cost_oro, level_req)
	if res.get("ok", false):
		hud.hide_island_preview()
		_play_sfx("coin")
	hud.show_status_message(str(res.get("msg", "")))


func _on_obstacle_clicked(obs_node: Node3D) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null or obs_node == null:
		return
	camera_rig.focus_on_target(obs_node.global_position, 13.0)
	var oid: String = str(obs_node.get("obstacle_id"))
	var obs: Dictionary = core.get_obstacle_by_id(oid)
	if obs.is_empty():
		return
	var spec: Dictionary = core.OBSTACLE_SPECS.get(str(obs.get("tipo", "arbusto")), core.OBSTACLE_SPECS["arbusto"])
	var res: Dictionary = core.get_resources()
	hud.show_obstacle_panel(obs, spec, int(res.get("oro", 0)), int(res.get("gemas", 0)))


func _on_clear_obstacle_requested(obs_id: String) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	var res: Dictionary = core.start_clear_obstacle(obs_id)
	hud.show_status_message(str(res.get("msg", "")))
	if res.get("ok", false):
		hud.hide_obstacle_panel()
		_play_sfx("coin")


func _on_speedup_obstacle_requested(obs_id: String) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	var res: Dictionary = core.speedup_obstacle_with_gems(obs_id)
	hud.show_status_message(str(res.get("msg", "")))
	if res.get("ok", false):
		hud.hide_obstacle_panel()
		_play_sfx("coin")


func _on_panel_requested(panel_name: String) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	match panel_name:
		"Tienda":
			_close_overlay_panels()
			if shop_panel and shop_panel.has_method("open_shop"):
				shop_panel.call("open_shop", int(core.get_resources().get("oro", 0)), _focused_island_id)
				hud.show_status_message("Tienda abierta.")
		"Almacén":
			_close_overlay_panels()
			if almacen_panel and almacen_panel.has_method("open_almacen"):
				almacen_panel.call("open_almacen")
				hud.show_status_message("Almacén abierto.")
		"Cruce":
			_close_overlay_panels()
			if breeding_panel and breeding_panel.has_method("open_breeding"):
				breeding_panel.call("open_breeding")
				hud.show_status_message("Adoratorio de Cría abierto.")
		"Nido":
			_close_overlay_panels()
			if nest_panel and nest_panel.has_method("open_nest"):
				nest_panel.call("open_nest")
				hud.show_status_message("Torre Nido abierta.")
		"Alimentar":
			_close_overlay_panels()
			_active_feed_filter_uids.clear()
			_open_feed_panel(core, _active_feed_filter_uids, 0)
		"Bestiario":
			_close_overlay_panels()
			if bestiario_panel and bestiario_panel.has_method("open_bestiario"):
				bestiario_panel.call("open_bestiario")
				hud.show_status_message("Bestiario abierto.")
		"Combate":
			_close_overlay_panels()
			if campana_panel and campana_panel.has_method("open_campaign"):
				campana_panel.call("open_campaign")
				hud.show_status_message("Carrusel de 50 capítulos abierto.")
		_:
			hud.show_status_message("Panel %s seleccionado." % panel_name)


func _close_overlay_panels() -> void:
	if bestiario_panel:
		bestiario_panel.visible = false
	if breeding_panel:
		breeding_panel.visible = false
	if nest_panel:
		nest_panel.visible = false
	if shop_panel:
		shop_panel.visible = false
	if estructura_modal:
		estructura_modal.visible = false
	if almacen_panel:
		almacen_panel.visible = false
	if campana_panel:
		campana_panel.visible = false
	if hud:
		hud.hide_dragon_feed_panel()
		hud.hide_island_preview()
		hud.hide_habitat_menu()
		hud.hide_obstacle_panel()


func _on_breeding_completed(res: Dictionary) -> void:
	hud.show_status_message(str(res.get("msg", "")))
	if res.get("ok", false):
		_play_sfx("hatch")
		if tutorial_dialog and tutorial_dialog.has_method("notify_action"):
			tutorial_dialog.call("notify_action", "cruce")


func _on_egg_hatched(res: Dictionary) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	if res.get("ok", false):
		var placed: bool = _spawn_dragon_into_free_habitat(core, res.get("dragon", {}))
		var extra: String = "" if placed else " (Sin espacio libre: puedes guardarlo en la Guardería o construir un Hábitat)"
		hud.show_status_message(str(res.get("msg", "")) + extra)
		if tutorial_dialog and tutorial_dialog.has_method("notify_action"):
			tutorial_dialog.call("notify_action", "eclosion")
	else:
		hud.show_status_message(str(res.get("msg", "")))


func _on_chapter_battle_requested(chapter_data: Dictionary) -> void:
	_open_combat_arena(chapter_data)


func _open_combat_arena(chapter_data: Variant = {}) -> void:
	if is_instance_valid(_active_combat_arena):
		return
	if tutorial_dialog and tutorial_dialog.has_method("notify_action"):
		tutorial_dialog.call("notify_action", "combate")

	if _combat_arena_scene_cache == null:
		_combat_arena_scene_cache = load(COMBAT_ARENA_SCENE_PATH) as PackedScene
	_active_combat_arena = _combat_arena_scene_cache.instantiate() as Node3D
	if chapter_data is Dictionary and not chapter_data.is_empty():
		_active_combat_arena.set("auto_start_default_chapter", false)
	add_child(_active_combat_arena)

	if archipielago:
		archipielago.visible = false
	hud.visible = false
	if camera_rig and camera_rig.camera:
		camera_rig.camera.current = false
	if _active_combat_arena.get("arena_camera"):
		_active_combat_arena.get("arena_camera").current = true

	var mgr: Node = _active_combat_arena.get("combat_manager")
	if mgr:
		if not mgr.is_connected("combat_finished", _on_combat_finished):
			mgr.connect("combat_finished", _on_combat_finished)
		if chapter_data is Dictionary and not chapter_data.is_empty() and mgr.has_method("start_chapter_data"):
			mgr.call("start_chapter_data", chapter_data, _active_combat_arena)


func _on_combat_finished(victory: bool, rewards: Dictionary) -> void:
	if is_instance_valid(_active_combat_arena):
		_active_combat_arena.queue_free()
		_active_combat_arena = null

	if archipielago:
		archipielago.visible = true
	hud.visible = true
	if camera_rig and camera_rig.camera:
		camera_rig.camera.current = true

	if victory:
		hud.show_status_message("¡Capítulo superado! +%d Oro, +%d Comida, +%d Gemas, +%d EXP." % [
			int(rewards.get("oro", 0)),
			int(rewards.get("comida", 0)),
			int(rewards.get("gemas", 0)),
			int(rewards.get("exp", 0))
		])
	else:
		hud.show_status_message("Combate finalizado. Regresaste al Santuario.")


func _on_habitat_clicked(hab: HabitatBase) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null or hab == null:
		return
	_close_overlay_panels()
	_selected_habitat = hab
	camera_rig.focus_on_target(hab.global_position, 13.2)
	var elem_info: Dictionary = core.get_element(hab.elemento_id)
	var elem_name: String = str(elem_info.get("nombre", "Tierra"))
	var oro_acum: int = int(floor(hab.accumulated_oro))
	var oro_max: int = hab.get_max_gold()
	var oro_rate: int = int(round(hab.recalculate_oro_rate(core)))
	hud.show_habitat_menu(
		"Hábitat %s (%d/%d • %d/%d Oro • %d/min)" % [elem_name, hab.dragons_count, hab.capacidad_maxima, oro_acum, oro_max, oro_rate],
		oro_acum,
		not hab.hosted_dragon_uids.is_empty()
	)


func _on_collect_habitat_oro_requested() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if _selected_habitat == null or core == null:
		return
	var collected: int = _selected_habitat.collect_oro()
	if collected > 0:
		core.add_oro(collected)
		hud.show_status_message("¡Recogiste +%d Oro del hábitat!" % collected)
		if tutorial_dialog and tutorial_dialog.has_method("notify_action"):
			tutorial_dialog.call("notify_action", "oro_o_alimentar")
	_on_habitat_clicked(_selected_habitat)


func _on_open_habitat_feed_requested() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if _selected_habitat == null or core == null:
		return
	if _selected_habitat.hosted_dragon_uids.is_empty():
		hud.show_status_message("Este hábitat está vacío.")
		return
	_active_feed_filter_uids = _selected_habitat.hosted_dragon_uids.duplicate()
	hud.hide_habitat_menu()
	_open_feed_panel(core, _active_feed_filter_uids, 0)


func _on_feed_dragon_requested(dragon_uid: int) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	var res: Dictionary = core.feed_dragon(dragon_uid)
	hud.show_status_message(str(res.get("msg", "")))
	if res.get("ok", false) and tutorial_dialog and tutorial_dialog.has_method("notify_action"):
		tutorial_dialog.call("notify_action", "oro_o_alimentar")
	var keep_idx: int = hud.get_feed_selected_index()
	_open_feed_panel(core, _active_feed_filter_uids, keep_idx)


func _on_dragon_leveled_up(dragon_uid: int, new_nivel: int, new_etapa: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", "level_up")
	var core: Node = get_node_or_null("/root/GameCore")
	for hab_var: Variant in _built_habitats.values():
		if hab_var is HabitatBase:
			var hab: HabitatBase = hab_var as HabitatBase
			if hab.refresh_dragon_visual(dragon_uid, new_nivel, new_etapa):
				hab.recalculate_oro_rate(core)
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
			"especie_id": int(d.get("especie_id", 1)),
			"nombre": str(sp.get("nombre", "Dragón")),
			"nivel": nivel,
			"max_nivel": core.MAX_DRAGON_LEVEL,
			"feed_steps": int(d.get("feed_steps", 0)),
			"etapa": str(d.get("etapa", "cria")),
			"cost_comida": core.get_feed_cost(nivel),
			"hp": int(stats.get("hp", 100)),
			"atk": int(stats.get("atk", 20)),
			"spd": int(stats.get("spd", 15)),
			"oro_por_min": int(stats.get("oro_por_min", 12)),
			"booster_mult": float(stats.get("booster_mult", 1.0)),
			"entrenamiento_nivel": int(stats.get("entrenamiento_nivel", 0))
		})
	return result


func _on_shop_habitat_requested(elemento_id: int, cost_oro: int, nombre: String) -> void:
	_pending_habitat_purchase = {"elemento_id": elemento_id, "cost_oro": cost_oro, "nombre": nombre}
	_sync_all_islands()
	hud.show_status_message("Modo colocación: clica un espacio verde iluminado para construir %s (Esc cancelar)." % nombre)


func _on_shop_egg_requested(especie_id: int, cost_oro: int) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core:
		var res: Dictionary = core.buy_egg(especie_id, cost_oro)
		hud.show_status_message(str(res.get("msg", "")))


func _on_shop_farm_requested(cost_oro: int) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core:
		var res: Dictionary = core.start_food_production(cost_oro, 180, 120)
		hud.show_status_message(str(res.get("msg", "")))


func _on_move_habitat_requested() -> void:
	if _selected_habitat == null:
		return
	var found_slot: int = -1
	for k: int in _built_habitats.keys():
		if _built_habitats[k] == _selected_habitat:
			found_slot = k
			break
	if found_slot < 0:
		return
	_moving_habitat_slot_idx = found_slot
	_pending_habitat_purchase.clear()
	hud.hide_habitat_menu()
	camera_rig.clear_entity_focus()
	_sync_all_islands()
	hud.show_status_message("Modo movimiento: selecciona una celda libre iluminada en verde (Esc cancelar).")


func _on_island_slot_clicked(_island_id: int, global_slot_idx: int, slot_node: Node3D) -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	if _moving_habitat_slot_idx >= 0:
		if _built_habitats.has(global_slot_idx):
			hud.show_status_message("Ese espacio ya está ocupado.")
			return
		var res_mv: Dictionary = core.move_habitat_slot(_moving_habitat_slot_idx, global_slot_idx)
		if res_mv.get("ok", false):
			var hab: HabitatBase = _built_habitats[_moving_habitat_slot_idx]
			_built_habitats.erase(_moving_habitat_slot_idx)
			if hab.get_parent():
				hab.get_parent().remove_child(hab)
			slot_node.add_child(hab)
			hab.position = Vector3.ZERO
			_built_habitats[global_slot_idx] = hab
			_play_sfx("click")
		_moving_habitat_slot_idx = -1
		_sync_all_islands()
		hud.show_status_message(str(res_mv.get("msg", "")))
		return

	if _pending_habitat_purchase.is_empty():
		return
	if _built_habitats.has(global_slot_idx):
		hud.show_status_message("Ese espacio ya está ocupado.")
		return
	var elem_id: int = int(_pending_habitat_purchase.get("elemento_id", 1))
	var cost: int = int(_pending_habitat_purchase.get("cost_oro", 250))
	var res: Dictionary = core.build_habitat(global_slot_idx, elem_id, cost)
	if res.get("ok", false):
		_spawn_habitat_at_slot(global_slot_idx, elem_id)
		core.add_player_exp(30)
		_play_sfx("coin")
	_pending_habitat_purchase.clear()
	_sync_all_islands()
	hud.show_status_message(str(res.get("msg", "")))


func _has_open_overlay_panel() -> bool:
	var panels: Array = [bestiario_panel, breeding_panel, nest_panel, shop_panel, estructura_modal, almacen_panel, campana_panel]
	for p: Variant in panels:
		if p is Control and (p as Control).visible:
			return true
	if hud:
		if (hud.panel_alimentar and hud.panel_alimentar.visible) \
		or (hud.panel_isla_preview and hud.panel_isla_preview.visible) \
		or (hud.panel_habitat_menu and hud.panel_habitat_menu.visible) \
		or (hud.panel_obstaculo and hud.panel_obstaculo.visible):
			return true
	return false


func _play_sfx(kind: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", kind)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if not _pending_habitat_purchase.is_empty() or _moving_habitat_slot_idx >= 0:
				_pending_habitat_purchase.clear()
				_moving_habitat_slot_idx = -1
				_sync_all_islands()
				_play_sfx("click")
				hud.show_status_message("Modo colocación/movimiento cancelado.")
			elif _has_open_overlay_panel():
				_close_overlay_panels()
				camera_rig.clear_entity_focus()
				_play_sfx("click")
		elif event.keycode == KEY_M:
			var am: Node = get_node_or_null("/root/AudioManager")
			if am and am.has_method("toggle_mute"):
				var muted: bool = bool(am.call("toggle_mute"))
				hud.show_status_message("Audio silenciado." if muted else "Audio activado.")


func _sync_booster_totems() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	var isl1: Node3D = _islands.get(1, null)
	if core == null or isl1 == null:
		return
	if _booster_totems_root == null or not is_instance_valid(_booster_totems_root):
		_booster_totems_root = Node3D.new()
		_booster_totems_root.name = "PotenciadoresActivos"
		isl1.add_child(_booster_totems_root)
	for c: Node in _booster_totems_root.get_children():
		c.queue_free()

	var placed: Array = core.player_state.get("potenciadores_colocados", [])
	for i: int in range(placed.size()):
		var eid: int = int(placed[i])
		var totem: BoosterTotem = BoosterTotem.new()
		totem.position = Vector3(-5.8 + float(i) * 1.55, 0.56, 5.8)
		_booster_totems_root.add_child(totem)
		totem.setup(eid)


func _on_place_tile_requested(_tile_id: String, tile_color: Color) -> void:
	var isl: Node3D = _islands.get(_focused_island_id, _islands.get(1, null))
	if isl and isl.has_method("add_decorative_tile"):
		isl.call("add_decorative_tile", tile_color, _placed_tiles_count)
		_placed_tiles_count += 1
