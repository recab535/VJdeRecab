extends Control

## Pantalla de carga animada estilo Dragon City 2012:
## fondo degradado vibrante, estrellas/motas flotantes, trío de dragones 48x48 animados,
## barra de progreso brillante y transición suave a scenes/main.tscn.

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const TIPS: Array[String] = [
	"Cargando el catálogo oficial de 68 especies de dragones...",
	"Alineando las 5 Islas Flotantes y sus 4 parcelas en el horizonte...",
	"Encendiendo los cristales del Adoratorio de Cría y la Torre Nido...",
	"Activando los 8 Tótems Potenciadores y el Portal de 50 Capítulos..."
]

@onready var bg_color: ColorRect = get_node_or_null("BgColor") as ColorRect
@onready var pb_carga: ProgressBar = %PbCarga
@onready var lbl_tip: Label = %LblTip
@onready var lbl_porcentaje: Label = %LblPorcentaje
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var logo_box: VBoxContainer = %LogoBox

var _progress: float = 0.0
var _transitioning: bool = false
var _time: float = 0.0
var _showcase_dragons: Array[TextureRect] = []
var _motes: Array[Dictionary] = []


func _ready() -> void:
	_build_animated_backdrop()
	_build_dragon_showcase()
	if pb_carga:
		pb_carga.value = 0.0
	if fade_overlay:
		fade_overlay.color = Color(0.03, 0.05, 0.1, 1.0)
		var tw_in: Tween = create_tween()
		tw_in.tween_property(fade_overlay, "color:a", 0.0, 0.35)
	if logo_box:
		logo_box.modulate.a = 0.0
		var tw_logo: Tween = create_tween()
		tw_logo.tween_property(logo_box, "modulate:a", 1.0, 0.48)
	ResourceLoader.load_threaded_request(MAIN_SCENE_PATH)


func _build_animated_backdrop() -> void:
	# Fondo degradado cielo místico
	var grad: Gradient = Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.05, 0.13, 0.32, 1.0),
		Color(0.11, 0.30, 0.58, 1.0),
		Color(0.18, 0.48, 0.78, 1.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var grad_tex: GradientTexture2D = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)

	var bg_rect: TextureRect = TextureRect.new()
	bg_rect.texture = grad_tex
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)
	move_child(bg_rect, 1 if bg_color else 0)

	# 24 motas luminosas flotantes (estrellas / polen mágico)
	var motes_layer: Control = Control.new()
	motes_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	motes_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(motes_layer)
	move_child(motes_layer, 2)

	for i: int in range(24):
		var dot: ColorRect = ColorRect.new()
		var sz: float = randf_range(4.0, 9.0)
		dot.custom_minimum_size = Vector2(sz, sz)
		dot.size = Vector2(sz, sz)
		dot.color = Color(1.0, 0.92, 0.56, randf_range(0.28, 0.78)) if i % 2 == 0 else Color(0.62, 0.90, 1.0, randf_range(0.25, 0.72))
		dot.position = Vector2(randf_range(40.0, 1880.0), randf_range(40.0, 1040.0))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		motes_layer.add_child(dot)
		_motes.append({
			"node": dot,
			"base_x": dot.position.x,
			"speed_y": randf_range(16.0, 42.0),
			"phase": randf() * TAU
		})


func _build_dragon_showcase() -> void:
	if logo_box == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)

	var preview_ids: Array[int] = [1, 2, 3]
	for idx: int in range(preview_ids.size()):
		var tr: TextureRect = TextureRect.new()
		tr.texture = Dragon2D.build_dragon_texture(preview_ids[idx], "adulto" if idx == 1 else "joven")
		tr.custom_minimum_size = Vector2(96, 96) if idx == 1 else Vector2(80, 80)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
		_showcase_dragons.append(tr)

	logo_box.add_child(row)
	logo_box.move_child(row, 0)


func _process(delta: float) -> void:
	_time += delta
	for m: Dictionary in _motes:
		var dot: ColorRect = m["node"]
		dot.position.y -= float(m["speed_y"]) * delta
		dot.position.x = float(m["base_x"]) + sin(_time * 1.5 + float(m["phase"])) * 18.0
		if dot.position.y < -16.0:
			dot.position.y = 1096.0

	for i: int in range(_showcase_dragons.size()):
		var tr: TextureRect = _showcase_dragons[i]
		tr.position.y = sin(_time * 3.0 + float(i) * 1.2) * 5.0

	if _transitioning:
		return

	_progress = minf(100.0, _progress + delta * 64.0)
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
		tw.tween_property(fade_overlay, "color:a", 1.0, 0.30)
		await tw.finished
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed: PackedScene = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene
		if packed:
			get_tree().change_scene_to_packed(packed)
			return
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
