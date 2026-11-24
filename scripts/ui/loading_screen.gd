extends Control

## Pantalla de carga inicial con barra de progreso animada y transición suave a scenes/main.tscn.

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const TIPS: Array[String] = [
	"Cargando el catálogo de 68 dragones...",
	"Alineando las 5 Islas Flotantes en el horizonte...",
	"Encendiendo los cristales del Adoratorio de Cría...",
	"Preparando la Torre Nido y las Parcelas del Santuario..."
]

@onready var pb_carga: ProgressBar = %PbCarga
@onready var lbl_tip: Label = %LblTip
@onready var lbl_porcentaje: Label = %LblPorcentaje
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var logo_box: VBoxContainer = %LogoBox

var _progress: float = 0.0
var _transitioning: bool = false


func _ready() -> void:
	if pb_carga:
		pb_carga.value = 0.0
	if fade_overlay:
		fade_overlay.color = Color(0.03, 0.05, 0.1, 1.0)
		var tw_in: Tween = create_tween()
		tw_in.tween_property(fade_overlay, "color:a", 0.0, 0.35)
	if logo_box:
		logo_box.modulate.a = 0.0
		var tw_logo: Tween = create_tween()
		tw_logo.tween_property(logo_box, "modulate:a", 1.0, 0.45)


func _process(delta: float) -> void:
	if _transitioning:
		return

	_progress = minf(100.0, _progress + delta * 68.0)
	if pb_carga:
		pb_carga.value = _progress
	if lbl_porcentaje:
		lbl_porcentaje.text = "%d%%" % int(round(_progress))

	var tip_idx: int = clampi(int(_progress / 26.0), 0, TIPS.size() - 1)
	if lbl_tip:
		lbl_tip.text = TIPS[tip_idx]

	if _progress >= 100.0:
		_transitioning = true
		_go_to_main()


func _go_to_main() -> void:
	if fade_overlay:
		var tw: Tween = create_tween()
		tw.tween_property(fade_overlay, "color:a", 1.0, 0.3)
		await tw.finished
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
