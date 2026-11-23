extends CanvasLayer
class_name HudBasic

## HUD base a 1920x1080: recursos, botones principales, rotación horizontal y vista previa de isla.

signal rotate_left_requested
signal rotate_right_requested
signal panel_requested(panel_name: String)
signal unlock_island_requested(island_id: int, cost_oro: int)

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

var _preview_island_id: int = -1
var _preview_cost_oro: int = 0


func _ready() -> void:
	btn_rotar_izq.pressed.connect(func() -> void: rotate_left_requested.emit())
	btn_rotar_der.pressed.connect(func() -> void: rotate_right_requested.emit())
	btn_cerrar_preview.pressed.connect(hide_island_preview)
	btn_desbloquear_isla.pressed.connect(func() -> void:
		if _preview_island_id > 0:
			unlock_island_requested.emit(_preview_island_id, _preview_cost_oro)
	)

	for btn_name: String in ["BtnTienda", "BtnCruce", "BtnNido", "BtnBestiario", "BtnCombate"]:
		var btn: Button = find_child(btn_name, true, false) as Button
		if btn:
			btn.pressed.connect(func() -> void: panel_requested.emit(btn.text))

	panel_isla_preview.visible = false


func set_resources(oro: int, comida: int, gemas: int) -> void:
	lbl_oro.text = "Oro: %d" % oro
	lbl_comida.text = "Comida: %d" % comida
	lbl_gemas.text = "Gemas: %d" % gemas


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
