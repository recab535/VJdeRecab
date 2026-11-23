extends CanvasLayer
class_name HudBasic

## HUD base a 1920x1080: recursos, botones principales, rotación horizontal y vista previa de isla.

signal rotate_left_requested
signal rotate_right_requested
signal panel_requested(panel_name: String)
signal unlock_island_requested(island_id: int, cost_oro: int)
signal feed_dragon_requested(dragon_uid: int)

@onready var lbl_nivel_jugador: Label = %LblNivelJugador
@onready var pb_nivel_jugador: ProgressBar = %PbNivelJugador
@onready var lbl_oro: Label = %LblOro
@onready var lbl_comida: Label = %LblComida
@onready var lbl_gemas: Label = %LblGemas
@onready var btn_rotar_izq: Button = %BtnRotarIzq
@onready var btn_rotar_der: Button = %BtnRotarDer
@onready var panel_isla_preview: PanelContainer = %PanelIslaPreview
@onready var lbl_isla_titulo: Label = %LblIslaTitulo
@onready var lbl_isla_detalle: Label = %LblIslaDetalle
@onready var btn_desbloquear_isla: Button = %BtnDesbloquearIsla
@onready var btn_cerrar_preview: Button = %BtnCerrarPreview
@onready var lbl_estado_accion: Label = %LblEstadoAccion
@onready var panel_alimentar: PanelContainer = %PanelAlimentar
@onready var lbl_dragon_titulo: Label = %LblDragonTitulo
@onready var lbl_dragon_stats: Label = %LblDragonStats
@onready var btn_anterior_dragon: Button = %BtnAnteriorDragon
@onready var btn_siguiente_dragon: Button = %BtnSiguienteDragon
@onready var btn_alimentar_dragon: Button = %BtnAlimentarDragon
@onready var btn_cerrar_alimentar: Button = %BtnCerrarAlimentar

var _preview_island_id: int = -1
var _preview_cost_oro: int = 0
var _feed_dragons_list: Array[Dictionary] = []
var _feed_selected_idx: int = 0
var _current_comida: int = 0


func _ready() -> void:
	btn_rotar_izq.pressed.connect(func() -> void: rotate_left_requested.emit())
	btn_rotar_der.pressed.connect(func() -> void: rotate_right_requested.emit())
	btn_cerrar_preview.pressed.connect(hide_island_preview)
	btn_desbloquear_isla.pressed.connect(func() -> void:
		if _preview_island_id > 0:
			unlock_island_requested.emit(_preview_island_id, _preview_cost_oro)
	)

	if btn_cerrar_alimentar:
		btn_cerrar_alimentar.pressed.connect(hide_dragon_feed_panel)
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

	for btn_name: String in ["BtnTienda", "BtnCruce", "BtnNido", "BtnAlimentar", "BtnBestiario", "BtnCombate"]:
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
	lbl_oro.text = "Oro: %d" % oro
	lbl_comida.text = "Comida: %d" % comida
	lbl_gemas.text = "Gemas: %d" % gemas
	if panel_alimentar and panel_alimentar.visible:
		_refresh_feed_panel_ui()


func show_status_message(msg: String) -> void:
	if lbl_estado_accion:
		lbl_estado_accion.text = msg


func show_island_preview(info: Dictionary, current_oro: int) -> void:
	_preview_island_id = int(info.get("id", -1))
	_preview_cost_oro = int(info.get("costo_oro", 2500))
	lbl_isla_titulo.text = str(info.get("nombre", "Isla Bloqueada"))
	lbl_isla_detalle.text = "Espacios construibles: %d\nElementos: %s\nCosto: %d Oro" % [
		int(info.get("slots", 4)),
		str(info.get("elementos", "Varios")),
		_preview_cost_oro
	]
	btn_desbloquear_isla.text = "Desbloquear (%d Oro)" % _preview_cost_oro
	btn_desbloquear_isla.disabled = current_oro < _preview_cost_oro
	panel_isla_preview.visible = true


func hide_island_preview() -> void:
	panel_isla_preview.visible = false


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

	var multiple: bool = _feed_dragons_list.size() > 1
	btn_anterior_dragon.visible = multiple
	btn_siguiente_dragon.visible = multiple

	if nivel >= max_nivel:
		btn_alimentar_dragon.text = "Nivel Máximo"
		btn_alimentar_dragon.disabled = true
	else:
		btn_alimentar_dragon.text = "Alimentar (%d Comida)" % cost
		btn_alimentar_dragon.disabled = _current_comida < cost
