extends Node3D
class_name Dragon2D

## Entidad visual 2.5D de dragón: Sprite3D billboarded mirando a cámara con pixel art.

@export var especie_id: int = 1
@export var dragon_nombre: String = "Dragón Terracota"
@export var sprite_prefijo: String = "dragon_terracota"
@export var etapa: String = "cria"

@onready var sprite: Sprite3D = $Sprite3D
@onready var label_nombre: Label3D = $Label3D

var _anim_time: float = 0.0
var _base_y: float = 0.48


func _ready() -> void:
	if sprite:
		_base_y = sprite.position.y
	setup_visual(especie_id, dragon_nombre, sprite_prefijo, etapa)


func _process(delta: float) -> void:
	_anim_time += delta * 3.0
	if sprite:
		sprite.position.y = _base_y + sin(_anim_time) * 0.04


func setup_visual(id: int, nombre: String, prefijo: String, stage: String = "cria") -> void:
	especie_id = id
	dragon_nombre = nombre
	sprite_prefijo = prefijo
	etapa = stage

	if label_nombre:
		label_nombre.text = dragon_nombre

	if sprite == null:
		return

	var tex_path: String = "res://assets/sprites/dragons/%s_%s.png" % [sprite_prefijo, etapa]
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	else:
		sprite.texture = _create_placeholder_pixel_art(especie_id)


func _create_placeholder_pixel_art(id: int) -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Paleta por defecto para Terracota (ID 1) o variación por ID
	var body_color: Color = Color(0.84, 0.42, 0.22, 1.0) if id == 1 else Color.from_hsv(fmod(id * 0.13, 1.0), 0.72, 0.85, 1.0)
	var belly_color: Color = body_color.lightened(0.32)
	var outline: Color = Color(0.18, 0.10, 0.08, 1.0)

	# Silueta pixel art 16x16 simple de dragón
	for y: int in range(4, 13):
		for x: int in range(4, 12):
			if (x == 4 or x == 11) and (y == 4 or y == 12):
				continue
			img.set_pixel(x, y, body_color)

	# Borde inferior y vientre
	for x: int in range(5, 11):
		img.set_pixel(x, 12, outline)
		img.set_pixel(x, 10, belly_color)
		img.set_pixel(x, 11, belly_color)

	# Alas laterales
	for y: int in range(6, 10):
		img.set_pixel(2, y, body_color.darkened(0.15))
		img.set_pixel(3, y, body_color)
		img.set_pixel(12, y, body_color)
		img.set_pixel(13, y, body_color.darkened(0.15))

	# Cuernos y ojos
	img.set_pixel(5, 3, outline)
	img.set_pixel(10, 3, outline)
	img.set_pixel(6, 6, Color(1, 1, 1, 1))
	img.set_pixel(9, 6, Color(1, 1, 1, 1))
	img.set_pixel(6, 7, outline)
	img.set_pixel(9, 7, outline)

	return ImageTexture.create_from_image(img)
