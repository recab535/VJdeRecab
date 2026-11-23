extends Node3D
class_name Dragon2D

## Entidad visual 2.5D de dragón: Sprite3D billboarded mirando a cámara con pixel art.

@export var especie_id: int = 1
@export var dragon_nombre: String = "Dragón Terracota"
@export var sprite_prefijo: String = "dragon_terracota"
@export var etapa: String = "cria"
@export var dragon_uid: int = -1
@export var nivel: int = 1

@onready var sprite: Sprite3D = $Sprite3D
@onready var label_nombre: Label3D = $Label3D

var _anim_time: float = 0.0
var _base_y: float = 0.48
var patrol_enabled: bool = false
var _patrol_target: Vector3 = Vector3.ZERO
var _patrol_timer: float = 1.5


func _ready() -> void:
	if sprite:
		_base_y = sprite.position.y
	setup_visual(especie_id, dragon_nombre, sprite_prefijo, etapa)


func _process(delta: float) -> void:
	_anim_time += delta * 3.0
	if sprite:
		sprite.position.y = _base_y + sin(_anim_time) * 0.04
	if patrol_enabled:
		_patrol_timer -= delta
		if _patrol_timer <= 0.0:
			_patrol_timer = randf_range(1.8, 3.8)
			_patrol_target = Vector3(randf_range(-0.38, 0.38), 0.0, randf_range(-0.22, 0.22))
		var diff: Vector3 = _patrol_target - position
		if diff.length() > 0.03:
			var step: Vector3 = diff.normalized() * minf(diff.length(), delta * 0.45)
			if sprite and absf(step.x) > 0.001:
				sprite.flip_h = step.x < 0.0
			position += step


func setup_visual(id: int, nombre: String, prefijo: String, stage: String = "cria", uid: int = -1, lvl: int = 1) -> void:
	especie_id = id
	dragon_nombre = nombre
	sprite_prefijo = prefijo
	etapa = stage
	if uid > 0:
		dragon_uid = uid
	nivel = maxi(1, lvl)

	if label_nombre:
		label_nombre.text = "%s (Nv.%d)" % [dragon_nombre, nivel]

	if sprite == null:
		return

	var stage_scale: float = 1.0 if etapa == "cria" else (1.15 if etapa == "joven" else 1.3)
	sprite.scale = Vector3.ONE * stage_scale

	var tex_path: String = "res://assets/sprites/dragons/%s_%s.png" % [sprite_prefijo, etapa]
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	else:
		sprite.texture = _create_placeholder_pixel_art(especie_id)


func update_progression(new_nivel: int, new_etapa: String) -> void:
	setup_visual(especie_id, dragon_nombre, sprite_prefijo, new_etapa, dragon_uid, new_nivel)


func _create_placeholder_pixel_art(id: int) -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var pal: Dictionary = _get_element_palette(id)
	_draw_base_dragon(img, pal)
	_draw_element_details(img, id, pal)

	return ImageTexture.create_from_image(img)


func _set_px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		img.set_pixel(x, y, col)


func _get_element_palette(id: int) -> Dictionary:
	match id:
		1: # Tierra (Terracota)
			return {
				"body": Color(0.78, 0.42, 0.22, 1.0),
				"belly": Color(0.92, 0.74, 0.50, 1.0),
				"accent": Color(0.55, 0.30, 0.16, 1.0),
				"highlight": Color(0.96, 0.85, 0.66, 1.0),
				"outline": Color(0.20, 0.11, 0.07, 1.0),
				"eye": Color(1.0, 0.95, 0.80, 1.0),
			}
		2: # Fuego
			return {
				"body": Color(0.88, 0.22, 0.14, 1.0),
				"belly": Color(0.98, 0.68, 0.22, 1.0),
				"accent": Color(1.0, 0.48, 0.10, 1.0),
				"highlight": Color(1.0, 0.92, 0.35, 1.0),
				"outline": Color(0.24, 0.06, 0.05, 1.0),
				"eye": Color(1.0, 0.96, 0.60, 1.0),
			}
		3: # Agua
			return {
				"body": Color(0.16, 0.52, 0.88, 1.0),
				"belly": Color(0.68, 0.92, 0.98, 1.0),
				"accent": Color(0.10, 0.76, 0.86, 1.0),
				"highlight": Color(0.85, 0.98, 1.0, 1.0),
				"outline": Color(0.06, 0.16, 0.34, 1.0),
				"eye": Color(0.95, 1.0, 1.0, 1.0),
			}
		4: # Planta
			return {
				"body": Color(0.22, 0.68, 0.28, 1.0),
				"belly": Color(0.76, 0.92, 0.54, 1.0),
				"accent": Color(0.38, 0.84, 0.32, 1.0),
				"highlight": Color(0.92, 0.98, 0.68, 1.0),
				"outline": Color(0.09, 0.24, 0.11, 1.0),
				"eye": Color(1.0, 0.96, 0.72, 1.0),
			}
		5: # Eléctrico
			return {
				"body": Color(0.95, 0.78, 0.14, 1.0),
				"belly": Color(1.0, 0.95, 0.62, 1.0),
				"accent": Color(1.0, 0.92, 0.28, 1.0),
				"highlight": Color(1.0, 1.0, 0.88, 1.0),
				"outline": Color(0.18, 0.16, 0.30, 1.0),
				"eye": Color(0.40, 0.92, 1.0, 1.0),
			}
		6: # Hielo
			return {
				"body": Color(0.52, 0.84, 0.98, 1.0),
				"belly": Color(0.90, 0.97, 1.0, 1.0),
				"accent": Color(0.32, 0.68, 0.92, 1.0),
				"highlight": Color(1.0, 1.0, 1.0, 1.0),
				"outline": Color(0.14, 0.28, 0.44, 1.0),
				"eye": Color(0.95, 1.0, 1.0, 1.0),
			}
		7: # Metal
			return {
				"body": Color(0.60, 0.66, 0.74, 1.0),
				"belly": Color(0.84, 0.88, 0.92, 1.0),
				"accent": Color(0.40, 0.46, 0.54, 1.0),
				"highlight": Color(0.96, 0.98, 1.0, 1.0),
				"outline": Color(0.14, 0.16, 0.20, 1.0),
				"eye": Color(1.0, 0.55, 0.20, 1.0),
			}
		8: # Oscuro
			return {
				"body": Color(0.28, 0.15, 0.42, 1.0),
				"belly": Color(0.50, 0.30, 0.64, 1.0),
				"accent": Color(0.72, 0.20, 0.78, 1.0),
				"highlight": Color(0.92, 0.42, 0.88, 1.0),
				"outline": Color(0.08, 0.04, 0.14, 1.0),
				"eye": Color(1.0, 0.25, 0.45, 1.0),
			}
		_:
			var base_col: Color = Color.from_hsv(fmod(id * 0.13, 1.0), 0.72, 0.85, 1.0)
			return {
				"body": base_col,
				"belly": base_col.lightened(0.32),
				"accent": base_col.darkened(0.20),
				"highlight": base_col.lightened(0.45),
				"outline": Color(0.16, 0.10, 0.12, 1.0),
				"eye": Color(1.0, 1.0, 1.0, 1.0),
			}


func _draw_base_dragon(img: Image, pal: Dictionary) -> void:
	var body_color: Color = pal["body"]
	var belly_color: Color = pal["belly"]
	var outline: Color = pal["outline"]
	var eye_color: Color = pal["eye"]

	# Cuerpo central 16x16
	for y: int in range(4, 13):
		for x: int in range(4, 12):
			if (x == 4 or x == 11) and (y == 4 or y == 12):
				continue
			_set_px(img, x, y, body_color)

	# Borde inferior y vientre
	for x: int in range(5, 11):
		_set_px(img, x, 12, outline)
		_set_px(img, x, 10, belly_color)
		_set_px(img, x, 11, belly_color)

	# Patas pequeñas
	_set_px(img, 5, 13, outline)
	_set_px(img, 6, 13, body_color.darkened(0.15))
	_set_px(img, 9, 13, body_color.darkened(0.15))
	_set_px(img, 10, 13, outline)

	# Ojos
	_set_px(img, 6, 6, eye_color)
	_set_px(img, 9, 6, eye_color)
	_set_px(img, 6, 7, outline)
	_set_px(img, 9, 7, outline)


func _draw_element_details(img: Image, id: int, pal: Dictionary) -> void:
	var body_color: Color = pal["body"]
	var accent: Color = pal["accent"]
	var highlight: Color = pal["highlight"]
	var outline: Color = pal["outline"]

	match id:
		1: # Tierra: cuernos robustos y placas rocosas
			_set_px(img, 4, 3, accent)
			_set_px(img, 5, 2, highlight)
			_set_px(img, 5, 3, outline)
			_set_px(img, 11, 3, accent)
			_set_px(img, 10, 2, highlight)
			_set_px(img, 10, 3, outline)
			for y: int in range(7, 11):
				_set_px(img, 3, y, accent)
				_set_px(img, 12, y, accent)
			_set_px(img, 2, 8, outline)
			_set_px(img, 13, 8, outline)
			_set_px(img, 7, 4, accent)
			_set_px(img, 8, 4, accent)
		2: # Fuego: cresta y alas de llamas
			_set_px(img, 7, 2, highlight)
			_set_px(img, 8, 1, highlight)
			_set_px(img, 7, 3, accent)
			_set_px(img, 8, 3, accent)
			_set_px(img, 6, 3, accent)
			for y: int in range(5, 10):
				_set_px(img, 3, y, accent)
				_set_px(img, 12, y, accent)
			_set_px(img, 2, 5, highlight)
			_set_px(img, 2, 7, accent)
			_set_px(img, 1, 6, highlight)
			_set_px(img, 13, 5, highlight)
			_set_px(img, 13, 7, accent)
			_set_px(img, 14, 6, highlight)
		3: # Agua: aleta dorsal y aletas laterales/cola
			_set_px(img, 7, 2, highlight)
			_set_px(img, 8, 2, accent)
			_set_px(img, 7, 3, accent)
			_set_px(img, 8, 3, accent)
			for y: int in range(6, 11):
				_set_px(img, 2, y, accent)
				_set_px(img, 3, y, highlight if y == 6 else body_color)
				_set_px(img, 13, y, accent)
				_set_px(img, 12, y, highlight if y == 6 else body_color)
			_set_px(img, 1, 7, highlight)
			_set_px(img, 1, 9, accent)
			_set_px(img, 14, 7, highlight)
			_set_px(img, 14, 9, accent)
		4: # Planta: brote de hojas en cabeza y alas foliáceas
			_set_px(img, 7, 3, outline)
			_set_px(img, 8, 3, outline)
			_set_px(img, 6, 2, accent)
			_set_px(img, 5, 2, highlight)
			_set_px(img, 9, 2, accent)
			_set_px(img, 10, 2, highlight)
			for y: int in range(6, 10):
				_set_px(img, 3, y, accent)
				_set_px(img, 12, y, accent)
			_set_px(img, 2, 6, highlight)
			_set_px(img, 2, 7, accent)
			_set_px(img, 1, 7, highlight)
			_set_px(img, 13, 6, highlight)
			_set_px(img, 13, 7, accent)
			_set_px(img, 14, 7, highlight)
		5: # Eléctrico: orejas/rayos en zigzag y chispas
			_set_px(img, 5, 3, highlight)
			_set_px(img, 4, 2, accent)
			_set_px(img, 5, 1, highlight)
			_set_px(img, 10, 3, highlight)
			_set_px(img, 11, 2, accent)
			_set_px(img, 10, 1, highlight)
			_set_px(img, 3, 6, accent)
			_set_px(img, 2, 7, highlight)
			_set_px(img, 3, 8, accent)
			_set_px(img, 1, 9, highlight)
			_set_px(img, 12, 6, accent)
			_set_px(img, 13, 7, highlight)
			_set_px(img, 12, 8, accent)
			_set_px(img, 14, 9, highlight)
		6: # Hielo: cristales afilados en corona y alas
			_set_px(img, 6, 3, highlight)
			_set_px(img, 7, 2, highlight)
			_set_px(img, 8, 1, highlight)
			_set_px(img, 9, 3, accent)
			_set_px(img, 3, 5, highlight)
			_set_px(img, 2, 6, accent)
			_set_px(img, 3, 7, highlight)
			_set_px(img, 2, 8, highlight)
			_set_px(img, 12, 5, highlight)
			_set_px(img, 13, 6, accent)
			_set_px(img, 12, 7, highlight)
			_set_px(img, 13, 8, highlight)
		7: # Metal: placas metálicas angulares y cresta blindada
			_set_px(img, 6, 3, outline)
			_set_px(img, 7, 3, highlight)
			_set_px(img, 8, 3, highlight)
			_set_px(img, 9, 3, outline)
			_set_px(img, 7, 2, accent)
			_set_px(img, 8, 2, highlight)
			for y: int in range(6, 10):
				_set_px(img, 3, y, highlight if y == 6 else accent)
				_set_px(img, 2, y, outline if y == 9 else highlight)
				_set_px(img, 12, y, highlight if y == 6 else accent)
				_set_px(img, 13, y, outline if y == 9 else highlight)
		8: # Oscuro: cuernos curvos, alas sombrías y aura oscura
			_set_px(img, 5, 3, outline)
			_set_px(img, 4, 2, outline)
			_set_px(img, 4, 1, accent)
			_set_px(img, 10, 3, outline)
			_set_px(img, 11, 2, outline)
			_set_px(img, 11, 1, accent)
			for y: int in range(6, 10):
				_set_px(img, 3, y, outline)
				_set_px(img, 2, y, accent if y % 2 == 0 else outline)
				_set_px(img, 12, y, outline)
				_set_px(img, 13, y, accent if y % 2 == 0 else outline)
			# Partículas de aura oscura alrededor
			_set_px(img, 1, 4, Color(0.58, 0.18, 0.78, 0.75))
			_set_px(img, 14, 4, Color(0.58, 0.18, 0.78, 0.75))
			_set_px(img, 1, 11, Color(0.45, 0.12, 0.65, 0.65))
			_set_px(img, 14, 11, Color(0.45, 0.12, 0.65, 0.65))
		_:
			for y: int in range(6, 10):
				_set_px(img, 2, y, body_color.darkened(0.15))
				_set_px(img, 3, y, body_color)
				_set_px(img, 12, y, body_color)
				_set_px(img, 13, y, body_color.darkened(0.15))
			_set_px(img, 5, 3, outline)
			_set_px(img, 10, 3, outline)
