extends Control

## Diálogo narrativo interactivo del Maestro Kael, Guardián del Santuario.
## Guía al jugador nuevo en la intro y 4 pasos interactivos sin bloquear clics del juego.

signal tutorial_finished

@onready var dialog_box: PanelContainer = %DialogBox
@onready var portrait_rect: TextureRect = %PortraitRect
@onready var lbl_speaker: Label = %LblSpeaker
@onready var lbl_text: Label = %LblText
@onready var btn_next: Button = %BtnNext
@onready var btn_skip: Button = %BtnSkip
@onready var arrow_hint: Label = %ArrowHint

const STEPS: Array[Dictionary] = [
	{
		"mode": "button",
		"text": "¡Bienvenido, Domador! Soy el Maestro Kael, Guardián del Santuario. Las islas vecinas han quedado selladas... Cría dragones y devuélveles la luz.",
		"arrow_pos": Vector2(460, 120),
		"arrow_text": "✨"
	},
	{
		"mode": "action",
		"action": "oro_o_alimentar",
		"text": "Paso 1/4: Clica tu Hábitat de Tierra para recoger oro o usa el botón Alimentar para subir de nivel a un dragón.",
		"arrow_pos": Vector2(930, 910),
		"arrow_text": "⬇"
	},
	{
		"mode": "action",
		"action": "cruce",
		"text": "Paso 2/4: ¡Bien hecho! Ahora clica el Adoratorio de cristales en la isla (o el botón Cruce) para cruzar a Terracota y Ascua.",
		"arrow_pos": Vector2(650, 910),
		"arrow_text": "⬇"
	},
	{
		"mode": "action",
		"action": "eclosion",
		"text": "Paso 3/4: ¡Hay un huevo incubando! Clica la Torre Nido en la isla (o el botón Nido) y eclosiónalo.",
		"arrow_pos": Vector2(790, 910),
		"arrow_text": "⬇"
	},
	{
		"mode": "action",
		"action": "combate",
		"text": "Paso 4/4: ¡Tu equipo está listo! Pulsa Combate para enfrentar tu primera batalla 1v1 en el Sendero Terracota.",
		"arrow_pos": Vector2(1210, 910),
		"arrow_text": "⬇"
	}
]

var _step_idx: int = 0
var _active: bool = false
var _char_accum: float = 0.0
var _arrow_time: float = 0.0
var _arrow_base_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if portrait_rect:
		portrait_rect.texture = _create_kael_portrait()
	if btn_next:
		btn_next.pressed.connect(_on_next_pressed)
	if btn_skip:
		btn_skip.pressed.connect(_complete_all)


func start_tutorial() -> void:
	_active = true
	visible = true
	_show_step(0)


func _process(delta: float) -> void:
	if not _active or not visible:
		return

	if lbl_text and lbl_text.visible_characters >= 0 and lbl_text.visible_characters < lbl_text.get_total_character_count():
		_char_accum += delta * 42.0
		if _char_accum >= 1.0:
			var add_chars: int = int(floor(_char_accum))
			_char_accum -= float(add_chars)
			lbl_text.visible_characters = mini(
				lbl_text.visible_characters + add_chars,
				lbl_text.get_total_character_count()
			)

	if arrow_hint and arrow_hint.visible:
		_arrow_time += delta * 4.5
		arrow_hint.position = _arrow_base_pos + Vector2(0.0, sin(_arrow_time) * 10.0)


func _show_step(idx: int) -> void:
	if idx >= STEPS.size():
		_complete_all()
		return
	_step_idx = idx
	var data: Dictionary = STEPS[idx]
	lbl_speaker.text = "Maestro Kael — Guardián del Santuario"
	lbl_text.text = str(data.get("text", ""))
	lbl_text.visible_characters = 0
	_char_accum = 0.0

	var is_btn_step: bool = str(data.get("mode", "button")) == "button"
	btn_next.visible = is_btn_step
	btn_next.text = "Continuar"

	if arrow_hint:
		_arrow_base_pos = data.get("arrow_pos", Vector2(960, 900))
		arrow_hint.position = _arrow_base_pos
		arrow_hint.text = str(data.get("arrow_text", "⬇"))
		arrow_hint.visible = true


func _on_next_pressed() -> void:
	if lbl_text.visible_characters < lbl_text.get_total_character_count():
		lbl_text.visible_characters = lbl_text.get_total_character_count()
		return
	_show_step(_step_idx + 1)


func notify_action(action_name: String) -> void:
	if not _active or _step_idx < 0 or _step_idx >= STEPS.size():
		return
	var data: Dictionary = STEPS[_step_idx]
	if str(data.get("mode", "")) == "action" and str(data.get("action", "")) == action_name:
		_show_step(_step_idx + 1)


func _complete_all() -> void:
	_active = false
	visible = false
	if arrow_hint:
		arrow_hint.visible = false
	tutorial_finished.emit()


func _create_kael_portrait() -> ImageTexture:
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.12, 0.16, 0.28, 1.0))

	var hood: Color = Color(0.22, 0.36, 0.72, 1.0)
	var hood_dark: Color = Color(0.14, 0.22, 0.48, 1.0)
	var skin: Color = Color(0.92, 0.76, 0.62, 1.0)
	var beard: Color = Color(0.88, 0.90, 0.96, 1.0)
	var gold: Color = Color(1.0, 0.84, 0.28, 1.0)
	var eye: Color = Color(0.32, 0.88, 1.0, 1.0)

	# Capucha y manto
	for y: int in range(3, 23):
		for x: int in range(5, 19):
			if y < 6 and (x < 7 or x > 16):
				continue
			img.set_pixel(x, y, hood_dark if (x == 5 or x == 18 or y == 3) else hood)

	# Rostro y barba del sabio
	for y: int in range(7, 13):
		for x: int in range(8, 16):
			img.set_pixel(x, y, skin)
	for y: int in range(13, 19):
		for x: int in range(8, 16):
			if y > 16 and (x < 10 or x > 13):
				continue
			img.set_pixel(x, y, beard)

	# Ojos brillantes y broche dorado
	img.set_pixel(10, 9, eye)
	img.set_pixel(13, 9, eye)
	img.set_pixel(11, 19, gold)
	img.set_pixel(12, 19, gold)
	# Orbe del báculo a la derecha
	for y: int in range(8, 23):
		img.set_pixel(20, y, Color(0.55, 0.35, 0.18, 1.0))
	img.set_pixel(20, 6, gold)
	img.set_pixel(19, 7, gold)
	img.set_pixel(20, 7, eye)
	img.set_pixel(21, 7, gold)

	return ImageTexture.create_from_image(img)
