extends Control

## Diálogo narrativo interactivo del Maestro Kael, Guardián del Santuario.
## Retrato pixel art 48x48, efecto máquina de escribir, animaciones Tween y flecha guía pulsante.

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
		"text": "¡Bienvenido, Domador! Soy el Maestro Kael. Ante ti se extienden 5 Islas Flotantes consecutivas: completa las 4 parcelas de cada isla para disipar las nubes de la siguiente.",
		"target_key": "",
		"arrow_pos": Vector2.ZERO,
		"arrow_text": ""
	},
	{
		"mode": "button",
		"text": "Tu isla ya cuenta con tu Hábitat inicial, el Adoratorio de Cría, la Torre Nido y el Templo de Nivel (hasta Nv.30). Sube tu Nivel de Domador ganando EXP.",
		"target_key": "hud_level",
		"arrow_pos": Vector2(220, 96),
		"arrow_text": "⬆ Tu Nivel"
	},
	{
		"mode": "action",
		"action": "oro_o_alimentar",
		"text": "Paso 1/4: Clica tu Hábitat de Tierra para recoger oro o usa Alimentar para fortalecer a tu Dragón Terracota.",
		"target_key": "habitat_1",
		"arrow_pos": Vector2(930, 900),
		"arrow_text": "⬇ Hábitat"
	},
	{
		"mode": "action",
		"action": "cruce",
		"text": "Paso 2/4: ¡Bien hecho! Clica el Adoratorio de cristales (o el botón Cruce) para cruzar a Terracota y Ascua.",
		"target_key": "adoratorio",
		"arrow_pos": Vector2(650, 900),
		"arrow_text": "⬇ Adoratorio"
	},
	{
		"mode": "action",
		"action": "eclosion",
		"text": "Paso 3/4: Un nuevo huevo descansa en la Torre Nido. ¡Clícala (o pulsa Nido) para incubarlo y eclosionarlo!",
		"target_key": "torre_nido",
		"arrow_pos": Vector2(790, 900),
		"arrow_text": "⬇ Torre Nido"
	},
	{
		"mode": "action",
		"action": "combate",
		"text": "Paso 4/4: ¡Listo para la historia! Pulsa Combate o el Portal de Historia para entrar al carrusel de 50 capítulos.",
		"target_key": "portal_historia",
		"arrow_pos": Vector2(1210, 900),
		"arrow_text": "⬇ Portal"
	}
]

var _step_idx: int = 0
var _active: bool = false
var _char_accum: float = 0.0
var _arrow_time: float = 0.0
var _arrow_base_pos: Vector2 = Vector2.ZERO
var _target_resolver: Callable = Callable()


func set_target_resolver(resolver: Callable) -> void:
	_target_resolver = resolver


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if portrait_rect:
		portrait_rect.texture = _create_kael_portrait_48()
	if btn_next:
		btn_next.pressed.connect(_on_next_pressed)
	if btn_skip:
		btn_skip.pressed.connect(_complete_all)


func start_tutorial() -> void:
	_active = true
	visible = true
	if dialog_box:
		dialog_box.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(dialog_box, "modulate:a", 1.0, 0.32)
	_show_step(0)


func _process(delta: float) -> void:
	if not _active or not visible:
		return

	if lbl_text and lbl_text.visible_characters >= 0 and lbl_text.visible_characters < lbl_text.get_total_character_count():
		_char_accum += delta * 46.0
		if _char_accum >= 1.0:
			var add_chars: int = int(floor(_char_accum))
			_char_accum -= float(add_chars)
			lbl_text.visible_characters = mini(
				lbl_text.visible_characters + add_chars,
				lbl_text.get_total_character_count()
			)

	if arrow_hint and _step_idx >= 0 and _step_idx < STEPS.size():
		var data: Dictionary = STEPS[_step_idx]
		var t_key: String = str(data.get("target_key", ""))
		if t_key.is_empty():
			arrow_hint.visible = false
		else:
			var resolved_pos: Vector2 = _arrow_base_pos
			var show_arrow: bool = true
			if _target_resolver.is_valid():
				var info: Variant = _target_resolver.call(t_key)
				if info is Dictionary and bool(info.get("valid", false)):
					resolved_pos = info.get("pos", _arrow_base_pos)
			var vp_size: Vector2 = get_viewport_rect().size
			resolved_pos.x = clampf(resolved_pos.x - arrow_hint.size.x * 0.5, 24.0, maxf(24.0, vp_size.x - arrow_hint.size.x - 24.0))
			resolved_pos.y = clampf(resolved_pos.y, 74.0, maxf(74.0, vp_size.y - 130.0))
			arrow_hint.visible = show_arrow
			_arrow_time += delta * 5.0
			arrow_hint.position = resolved_pos + Vector2(0.0, sin(_arrow_time) * 10.0)
			var pulse: float = 1.0 + sin(_arrow_time * 1.5) * 0.10
			arrow_hint.scale = Vector2(pulse, pulse)


func _show_step(idx: int) -> void:
	if idx >= STEPS.size():
		_complete_all()
		return
	_step_idx = idx
	var data: Dictionary = STEPS[idx]
	lbl_speaker.text = "Maestro Kael — Guardián del Santuario  (%d/%d)" % [idx + 1, STEPS.size()]
	lbl_text.text = str(data.get("text", ""))
	lbl_text.visible_characters = 0
	_char_accum = 0.0

	var is_btn_step: bool = str(data.get("mode", "button")) == "button"
	btn_next.visible = is_btn_step
	btn_next.text = "Continuar ▶"

	if dialog_box:
		dialog_box.scale = Vector2(0.96, 0.96)
		var tw: Tween = create_tween()
		tw.tween_property(dialog_box, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if arrow_hint:
		var t_key: String = str(data.get("target_key", ""))
		_arrow_base_pos = data.get("arrow_pos", Vector2(960, 900))
		arrow_hint.position = _arrow_base_pos
		arrow_hint.text = str(data.get("arrow_text", "⬇"))
		arrow_hint.visible = not t_key.is_empty()


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


func _create_kael_portrait_48() -> ImageTexture:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	# Fondo cálido pergamino/ámbar del retrato
	for y: int in range(48):
		var t: float = float(y) / 47.0
		var bg: Color = Color(0.24, 0.15, 0.08).lerp(Color(0.42, 0.27, 0.14), t)
		for x: int in range(48):
			img.set_pixel(x, y, bg)

	var hood: Color = Color(0.20, 0.36, 0.76, 1.0)
	var hood_light: Color = Color(0.32, 0.50, 0.88, 1.0)
	var hood_dark: Color = Color(0.11, 0.20, 0.46, 1.0)
	var skin: Color = Color(0.94, 0.78, 0.62, 1.0)
	var skin_shade: Color = Color(0.82, 0.64, 0.48, 1.0)
	var beard: Color = Color(0.92, 0.94, 0.98, 1.0)
	var beard_shade: Color = Color(0.74, 0.78, 0.88, 1.0)
	var gold: Color = Color(1.0, 0.84, 0.28, 1.0)
	var eye: Color = Color(0.36, 0.92, 1.0, 1.0)
	var outline: Color = Color(0.06, 0.08, 0.16, 1.0)

	# Capucha y hombros del Maestro Kael
	for y: int in range(6, 46):
		var half_w: int = 12 if y < 12 else (14 if y < 32 else 17)
		for x: int in range(22 - half_w, 22 + half_w):
			if x < 2 or x > 45:
				continue
			if x == 22 - half_w or x == 22 + half_w - 1 or y == 6:
				img.set_pixel(x, y, outline)
			elif x < 22 - half_w + 3:
				img.set_pixel(x, y, hood_light)
			elif x > 22 + half_w - 4:
				img.set_pixel(x, y, hood_dark)
			else:
				img.set_pixel(x, y, hood)

	# Ribete dorado de la túnica
	for y: int in range(32, 46):
		img.set_pixel(21, y, gold)
		img.set_pixel(22, y, gold)

	# Rostro sombreado
	for y: int in range(14, 26):
		for x: int in range(15, 29):
			img.set_pixel(x, y, skin_shade if (x > 25 or y == 14) else skin)

	# Barba plateada estilizada
	for y: int in range(24, 38):
		var shrink: int = maxi(0, (y - 30) / 2)
		for x: int in range(14 + shrink, 30 - shrink):
			img.set_pixel(x, y, beard_shade if (x > 25 or y > 34) else beard)

	# Cejas y ojos luminosos
	for bx: int in range(17, 21):
		img.set_pixel(bx, 18, beard)
	for bx: int in range(23, 27):
		img.set_pixel(bx, 18, beard)
	for dy: int in range(2):
		for dx: int in range(2):
			img.set_pixel(18 + dx, 20 + dy, eye)
			img.set_pixel(24 + dx, 20 + dy, eye)
	img.set_pixel(18, 20, Color.WHITE)
	img.set_pixel(24, 20, Color.WHITE)

	# Broche dorado central
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			img.set_pixel(22 + dx, 37 + dy, gold)

	# Báculo místico a la derecha con orbe brillante
	for y: int in range(14, 46):
		img.set_pixel(39, y, Color(0.56, 0.36, 0.18, 1.0))
		img.set_pixel(40, y, Color(0.42, 0.25, 0.12, 1.0))
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var d2: int = dx * dx + dy * dy
			if d2 <= 9:
				img.set_pixel(39 + dx, 11 + dy, Color.WHITE if d2 <= 1 else (eye if d2 <= 5 else gold))

	return ImageTexture.create_from_image(img)
