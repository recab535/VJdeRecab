extends CanvasLayer
class_name HudBasic

## HUD base a 1920x1080: recursos, botones principales, rotación horizontal y vista previa de isla.

signal rotate_left_requested
signal rotate_right_requested
signal prev_island_requested
signal next_island_requested
signal panel_requested(panel_name: String)
signal unlock_island_requested(island_id: int, cost_oro: int, level_req: int)
signal unlock_parcel_requested(island_id: int, parcel_index: int, cost_oro: int, level_req: int)
signal clear_obstacle_requested(obs_id: String)
signal speedup_obstacle_requested(obs_id: String)
signal feed_dragon_requested(dragon_uid: int)
signal collect_habitat_oro_requested
signal open_habitat_feed_requested

@onready var lbl_nivel_jugador: Label = %LblNivelJugador
@onready var pb_nivel_jugador: ProgressBar = %PbNivelJugador
@onready var lbl_oro: Label = %LblOro
@onready var lbl_comida: Label = %LblComida
@onready var lbl_gemas: Label = %LblGemas
@onready var btn_rotar_izq: Button = %BtnRotarIzq
@onready var btn_rotar_der: Button = %BtnRotarDer
@onready var btn_isla_ant: Button = %BtnIslaAnt
@onready var lbl_isla_actual: Label = %LblIslaActual
@onready var btn_isla_sig: Button = %BtnIslaSig
@onready var panel_obstaculo: PanelContainer = %PanelObstaculo
@onready var lbl_obs_titulo: Label = %LblObsTitulo
@onready var lbl_obs_detalle: Label = %LblObsDetalle
@onready var pb_obs_tiempo: ProgressBar = %PbObsTiempo
@onready var btn_limpiar_obs: Button = %BtnLimpiarObs
@onready var btn_acelerar_obs: Button = %BtnAcelerarObs
@onready var btn_cerrar_obs: Button = %BtnCerrarObs
@onready var panel_isla_preview: PanelContainer = %PanelIslaPreview
@onready var lbl_isla_titulo: Label = %LblIslaTitulo
@onready var lbl_isla_detalle: Label = %LblIslaDetalle
@onready var btn_desbloquear_isla: Button = %BtnDesbloquearIsla
@onready var btn_cerrar_preview: Button = %BtnCerrarPreview
@onready var lbl_estado_accion: Label = %LblEstadoAccion
@onready var panel_alimentar: PanelContainer = %PanelAlimentar
@onready var lbl_dragon_titulo: Label = %LblDragonTitulo
@onready var lbl_dragon_stats: Label = %LblDragonStats
@onready var pb_dragon_xp: ProgressBar = %PbDragonXP
@onready var panel_habitat_menu: PanelContainer = %PanelHabitatMenu
@onready var lbl_habitat_menu_info: Label = %LblHabitatMenuInfo
@onready var btn_recoger_oro: Button = %BtnRecogerOro
@onready var btn_habitat_alimentar: Button = %BtnHabitatAlimentar
@onready var btn_cerrar_habitat_menu: Button = %BtnCerrarHabitatMenu
@onready var btn_anterior_dragon: Button = %BtnAnteriorDragon
@onready var btn_siguiente_dragon: Button = %BtnSiguienteDragon
@onready var btn_alimentar_dragon: Button = %BtnAlimentarDragon
@onready var btn_cerrar_alimentar: Button = %BtnCerrarAlimentar

var _preview_island_id: int = -1
var _preview_parcel_idx: int = -1
var _preview_cost_oro: int = 0
var _preview_level_req: int = 1
var _selected_obs_id: String = ""
var _feed_dragons_list: Array[Dictionary] = []
var _feed_selected_idx: int = 0
var _current_comida: int = 0
var _last_oro: int = -1
var _last_comida: int = -1
var _last_gemas: int = -1


func _ready() -> void:
	btn_rotar_izq.pressed.connect(func() -> void: rotate_left_requested.emit())
	btn_rotar_der.pressed.connect(func() -> void: rotate_right_requested.emit())
	if btn_isla_ant:
		btn_isla_ant.pressed.connect(func() -> void: prev_island_requested.emit())
	if btn_isla_sig:
		btn_isla_sig.pressed.connect(func() -> void: next_island_requested.emit())
	btn_cerrar_preview.pressed.connect(hide_island_preview)
	btn_desbloquear_isla.pressed.connect(func() -> void:
		if _preview_parcel_idx >= 0:
			unlock_parcel_requested.emit(_preview_island_id, _preview_parcel_idx, _preview_cost_oro, _preview_level_req)
		elif _preview_island_id > 0:
			unlock_island_requested.emit(_preview_island_id, _preview_cost_oro, _preview_level_req)
	)
	if btn_cerrar_obs:
		btn_cerrar_obs.pressed.connect(hide_obstacle_panel)
	if btn_limpiar_obs:
		btn_limpiar_obs.pressed.connect(func() -> void:
			if not _selected_obs_id.is_empty():
				clear_obstacle_requested.emit(_selected_obs_id)
		)
	if btn_acelerar_obs:
		btn_acelerar_obs.pressed.connect(func() -> void:
			if not _selected_obs_id.is_empty():
				speedup_obstacle_requested.emit(_selected_obs_id)
		)

	if btn_cerrar_alimentar:
		btn_cerrar_alimentar.pressed.connect(hide_dragon_feed_panel)
	if btn_recoger_oro:
		btn_recoger_oro.pressed.connect(func() -> void: collect_habitat_oro_requested.emit())
	if btn_habitat_alimentar:
		btn_habitat_alimentar.pressed.connect(func() -> void: open_habitat_feed_requested.emit())
	if btn_cerrar_habitat_menu:
		btn_cerrar_habitat_menu.pressed.connect(hide_habitat_menu)
	if btn_anterior_dragon:
		btn_anterior_dragon.pressed.connect(func() -> void: _cycle_feed_dragon(-1))
	if btn_siguiente_dragon:
		btn_siguiente_dragon.pressed.connect(func() -> void: _cycle_feed_dragon(1))
	if btn_alimentar_dragon:
		btn_alimentar_dragon.pressed.connect(func() -> void:
			if _feed_selected_idx >= 0 and _feed_selected_idx < _feed_dragons_list.size():
				var uid: int = int(_feed_dragons_list[_feed_selected_idx].get("uid", -1))
				if uid > 0:
					feed_dragon_requested.emit(uid)
		)

	for btn_name: String in ["BtnTienda", "BtnAlmacen", "BtnCruce", "BtnNido", "BtnAlimentar", "BtnBestiario", "BtnCombate"]:
		var btn: Button = find_child(btn_name, true, false) as Button
		if btn:
			btn.pressed.connect(func() -> void: panel_requested.emit(btn.text))

	panel_isla_preview.visible = false
	if panel_alimentar:
		panel_alimentar.visible = false
	call_deferred("_attach_button_tweens", self)


func set_player_level(level: int, xp_ratio: float = 0.25) -> void:
	if lbl_nivel_jugador:
		lbl_nivel_jugador.text = "Nivel %d — Domador" % level
	if pb_nivel_jugador:
		pb_nivel_jugador.value = clampf(xp_ratio * 100.0, 0.0, 100.0)


func _attach_button_tweens(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Button:
			var btn: Button = child as Button
			if not btn.has_meta("tween_bound"):
				btn.set_meta("tween_bound", true)
				btn.mouse_entered.connect(func() -> void:
					btn.pivot_offset = btn.size * 0.5
					var tw: Tween = btn.create_tween()
					tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				)
				btn.mouse_exited.connect(func() -> void:
					btn.pivot_offset = btn.size * 0.5
					var tw: Tween = btn.create_tween()
					tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				)
				btn.button_down.connect(func() -> void:
					btn.pivot_offset = btn.size * 0.5
					var tw: Tween = btn.create_tween()
					tw.tween_property(btn, "scale", Vector2(0.94, 0.94), 0.06)
				)
				btn.button_up.connect(func() -> void:
					btn.pivot_offset = btn.size * 0.5
					var tw: Tween = btn.create_tween()
					tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.08)
				)
		_attach_button_tweens(child)


func set_resources(oro: int, comida: int, gemas: int) -> void:
	_current_comida = comida
	lbl_oro.text = "🪙 Oro: %d" % oro
	lbl_comida.text = "🍎 Comida: %d" % comida
	lbl_gemas.text = "💎 Gemas: %d" % gemas
	if _last_oro >= 0 and oro > _last_oro:
		_bump_label(lbl_oro)
	if _last_comida >= 0 and comida > _last_comida:
		_bump_label(lbl_comida)
	if _last_gemas >= 0 and gemas > _last_gemas:
		_bump_label(lbl_gemas)
	_last_oro = oro
	_last_comida = comida
	_last_gemas = gemas
	if panel_alimentar and panel_alimentar.visible:
		_refresh_feed_panel_ui()


func _bump_label(lbl: Control) -> void:
	if lbl == null:
		return
	lbl.pivot_offset = lbl.size * 0.5
	var tw: Tween = lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.16, 1.16), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pop_open(panel: Control) -> void:
	if panel == null:
		return
	panel.visible = true
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw: Tween = panel.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.14)


func show_status_message(msg: String) -> void:
	if lbl_estado_accion:
		lbl_estado_accion.text = msg


func set_focused_island(island_id: int) -> void:
	if lbl_isla_actual:
		lbl_isla_actual.text = "Isla %d / 5" % island_id


func show_island_preview(info: Dictionary, current_oro: int, player_level: int = 1) -> void:
	_preview_island_id = int(info.get("id", -1))
	_preview_parcel_idx = -1
	_preview_cost_oro = int(info.get("costo_oro", 2500))
	_preview_level_req = int(info.get("nivel_req", 1))
	lbl_isla_titulo.text = str(info.get("nombre", "Isla Bloqueada"))
	lbl_isla_detalle.text = "Cuadrícula: 14×14 (4 parcelas)\nElementos: %s\nNivel requerido: %d | Costo: %d Oro" % [
		str(info.get("elementos", "Varios")),
		_preview_level_req,
		_preview_cost_oro
	]
	btn_desbloquear_isla.text = "Desbloquear (%d Oro)" % _preview_cost_oro
	btn_desbloquear_isla.disabled = current_oro < _preview_cost_oro or player_level < _preview_level_req
	_pop_open(panel_isla_preview)


func show_parcel_preview(info: Dictionary, current_oro: int, player_level: int = 1) -> void:
	_preview_island_id = int(info.get("island_id", 1))
	_preview_parcel_idx = int(info.get("parcel_index", info.get("parcela", 1)))
	_preview_cost_oro = int(info.get("costo_oro", 750))
	_preview_level_req = int(info.get("nivel_req", 1))
	lbl_isla_titulo.text = "Parcela %d — Isla %d" % [_preview_parcel_idx + 1, _preview_island_id]
	lbl_isla_detalle.text = "Desbloquea espacio construible adicional (cuadrante 7×7).\nNivel requerido: %d | Costo: %d Oro" % [
		_preview_level_req,
		_preview_cost_oro
	]
	btn_desbloquear_isla.text = "Comprar Parcela (%d Oro)" % _preview_cost_oro
	btn_desbloquear_isla.disabled = current_oro < _preview_cost_oro or player_level < _preview_level_req
	_pop_open(panel_isla_preview)


func hide_island_preview() -> void:
	panel_isla_preview.visible = false


func show_obstacle_panel(obs: Dictionary, spec: Dictionary, current_oro: int, current_gems: int) -> void:
	if panel_obstaculo == null:
		return
	_selected_obs_id = str(obs.get("id", ""))
	var nombre: String = str(spec.get("nombre", "Obstáculo"))
	var dur: float = maxf(1.0, float(spec.get("duracion_seg", 600)))
	var rem: float = maxf(0.0, float(obs.get("restante_seg", dur)))
	var limpiando: bool = bool(obs.get("limpiando", false))
	var cost_oro: int = int(spec.get("costo_oro", 150))
	var cost_gems: int = int(spec.get("gemas_acelerar", 2))
	var exp_rew: int = int(spec.get("exp", 20))

	lbl_obs_titulo.text = "%s (+%d EXP)" % [nombre, exp_rew]
	var mins: int = int(ceil(rem / 60.0))
	lbl_obs_detalle.text = ("Limpiando... Faltan %d min" % mins) if limpiando else ("Tiempo de limpieza: %d min | Costo: %d Oro" % [int(dur / 60.0), cost_oro])
	pb_obs_tiempo.value = clampf(((dur - rem) / dur) * 100.0, 0.0, 100.0) if limpiando else 0.0
	btn_limpiar_obs.text = "En progreso..." if limpiando else ("Limpiar (%d Oro)" % cost_oro)
	btn_limpiar_obs.disabled = limpiando or current_oro < cost_oro
	btn_acelerar_obs.text = "Acelerar (%d Gemas)" % cost_gems
	btn_acelerar_obs.disabled = current_gems < cost_gems
	panel_obstaculo.visible = true


func hide_obstacle_panel() -> void:
	if panel_obstaculo:
		panel_obstaculo.visible = false


func show_dragon_feed_panel(dragons_info: Array[Dictionary], current_comida: int, selected_index: int = 0) -> void:
	if panel_alimentar == null or dragons_info.is_empty():
		return
	_feed_dragons_list = dragons_info
	_current_comida = current_comida
	_feed_selected_idx = clampi(selected_index, 0, _feed_dragons_list.size() - 1)
	_refresh_feed_panel_ui()
	panel_alimentar.visible = true


func hide_dragon_feed_panel() -> void:
	if panel_alimentar:
		panel_alimentar.visible = false


func show_habitat_menu(info_text: String, oro_acumulado: int, has_dragons: bool) -> void:
	if panel_habitat_menu == null:
		return
	if lbl_habitat_menu_info:
		lbl_habitat_menu_info.text = info_text
	if btn_recoger_oro:
		btn_recoger_oro.text = "Recoger (+%d Oro)" % oro_acumulado
		btn_recoger_oro.disabled = oro_acumulado <= 0
	if btn_habitat_alimentar:
		btn_habitat_alimentar.disabled = not has_dragons
	panel_habitat_menu.visible = true


func hide_habitat_menu() -> void:
	if panel_habitat_menu:
		panel_habitat_menu.visible = false


func get_feed_selected_index() -> int:
	return _feed_selected_idx


func _cycle_feed_dragon(delta_idx: int) -> void:
	if _feed_dragons_list.is_empty():
		return
	_feed_selected_idx = wrapi(_feed_selected_idx + delta_idx, 0, _feed_dragons_list.size())
	_refresh_feed_panel_ui()


func _refresh_feed_panel_ui() -> void:
	if _feed_dragons_list.is_empty() or _feed_selected_idx < 0 or _feed_selected_idx >= _feed_dragons_list.size():
		return

	var info: Dictionary = _feed_dragons_list[_feed_selected_idx]
	var nombre: String = str(info.get("nombre", "Dragón"))
	var nivel: int = int(info.get("nivel", 1))
	var max_nivel: int = int(info.get("max_nivel", 10))
	var etapa: String = str(info.get("etapa", "cria")).capitalize()
	var cost: int = int(info.get("cost_comida", 50))
	var hp: int = int(info.get("hp", 100))
	var atk: int = int(info.get("atk", 20))
	var spd: int = int(info.get("spd", 15))
	var oro_min: int = int(info.get("oro_por_min", 12))

	lbl_dragon_titulo.text = "%s — Nv. %d/%d (%s)" % [nombre, nivel, max_nivel, etapa]
	lbl_dragon_stats.text = "HP: %d  |  ATK: %d  |  SPD: %d\nProducción: %d Oro/min" % [hp, atk, spd, oro_min]
	if pb_dragon_xp:
		pb_dragon_xp.value = clampf((float(nivel) / float(max_nivel)) * 100.0, 0.0, 100.0)

	var multiple: bool = _feed_dragons_list.size() > 1
	btn_anterior_dragon.visible = multiple
	btn_siguiente_dragon.visible = multiple

	if nivel >= max_nivel:
		btn_alimentar_dragon.text = "Nivel Máximo"
		btn_alimentar_dragon.disabled = true
	else:
		btn_alimentar_dragon.text = "Alimentar (%d Comida)" % cost
		btn_alimentar_dragon.disabled = _current_comida < cost
