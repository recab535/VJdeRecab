extends CanvasLayer
class_name HudBasic

## HUD base a 1920x1080: recursos, botones principales y rotación horizontal.

signal rotate_left_requested
signal rotate_right_requested
signal panel_requested(panel_name: String)

@onready var lbl_oro: Label = %LblOro
@onready var lbl_comida: Label = %LblComida
@onready var lbl_gemas: Label = %LblGemas
@onready var btn_rotar_izq: Button = %BtnRotarIzq
@onready var btn_rotar_der: Button = %BtnRotarDer


func _ready() -> void:
	btn_rotar_izq.pressed.connect(func() -> void: rotate_left_requested.emit())
	btn_rotar_der.pressed.connect(func() -> void: rotate_right_requested.emit())

	for btn_name: String in ["BtnTienda", "BtnCruce", "BtnNido", "BtnBestiario", "BtnCombate"]:
		var btn: Button = find_child(btn_name, true, false) as Button
		if btn:
			btn.pressed.connect(func() -> void: panel_requested.emit(btn.text))


func set_resources(oro: int, comida: int, gemas: int) -> void:
	lbl_oro.text = "Oro: %d" % oro
	lbl_comida.text = "Comida: %d" % comida
	lbl_gemas.text = "Gemas: %d" % gemas
