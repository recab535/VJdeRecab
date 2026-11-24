extends Node3D
class_name Dragon2D

## Entidad visual 2.5D de dragón: Sprite3D billboarded con pixel art 48x48 procedural
## (contorno, sombreado 3 tonos, variantes por elemento primario/secundario, rareza y etapa),
## sombra proyectada en suelo y vida/movimiento/reacciones autónomas en hábitats.

@export var especie_id: int = 1
@export var dragon_nombre: String = "Dragón Terracota"
@export var sprite_prefijo: String = "dragon_terracota"
@export var etapa: String = "cria"
@export var dragon_uid: int = -1
@export var nivel: int = 1

@onready var sprite: Sprite3D = $Sprite3D
@onready var label_nombre: Label3D = $Label3D

const CANVAS_SIZE: int = 48
static var _tex_cache: Dictionary = {}


static func clear_cache() -> void:
	_tex_cache.clear()

enum AnimState { IDLE, WALK, SPECIAL_ANIM }

var _anim_time: float = 0.0
var _base_y: float = 0.54
var _base_scale: Vector3 = Vector3.ONE
var patrol_enabled: bool = false
var patrol_bounds: Vector2 = Vector2(0.46, 0.28)
var _state: AnimState = AnimState.IDLE
var _state_timer: float = 1.8
var _patrol_target: Vector3 = Vector3.ZERO
var _special_phase: float = 0.0
var _hop_phase: float = 0.0
var _blink_timer: float = 3.2
var _shadow_disc: MeshInstance3D = null


func _ready() -> void:
	_anim_time = randf() * TAU
	_state_timer = randf_range(1.2, 2.8)
	_blink_timer = randf_range(2.2, 4.8)
	_ensure_ground_shadow()
	if sprite:
		_base_y = sprite.position.y
	if label_nombre:
		label_nombre.visible = false
	setup_visual(especie_id, dragon_nombre, sprite_prefijo, etapa, dragon_uid, nivel)


func _ensure_ground_shadow() -> void:
	if _shadow_disc != null:
		return
	_shadow_disc = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.34
	cm.height = 0.012
	cm.radial_segments = 14
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.05, 0.06, 0.10, 0.42)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_disc.mesh = cm
	_shadow_disc.material_override = mat
	_shadow_disc.position = Vector3(0.0, 0.015, 0.0)
	add_child(_shadow_disc)


func _process(delta: float) -> void:
	_anim_time += delta * 3.0
	var moving: bool = false
	var special_hop: float = 0.0
	var special_tilt: float = 0.0

	if patrol_enabled:
		_state_timer -= delta
		match _state:
			AnimState.IDLE:
				if _state_timer <= 0.0:
					if randf() < 0.72:
						_enter_walk_state()
					else:
						_enter_special_state()
			AnimState.WALK:
				var diff: Vector3 = _patrol_target - position
				diff.y = 0.0
				if diff.length() > 0.035 and _state_timer > 0.0:
					moving = true
					var step: Vector3 = diff.normalized() * minf(diff.length(), delta * 0.52)
					if sprite and absf(step.x) > 0.001:
						sprite.flip_h = step.x < 0.0
					position.x = clampf(position.x + step.x, -patrol_bounds.x, patrol_bounds.x)
					position.z = clampf(position.z + step.z, -patrol_bounds.y, patrol_bounds.y)
					_hop_phase += delta * 9.5
				else:
					_enter_idle_state()
			AnimState.SPECIAL_ANIM:
				_special_phase += delta * 6.5
				special_hop = absf(sin(_special_phase)) * 0.24
				special_tilt = sin(_special_phase * 2.0) * 0.14
				if _state_timer <= 0.0:
					_enter_idle_state()

	if sprite:
		var idle_bob: float = sin(_anim_time) * 0.032
		var walk_hop: float = absf(sin(_hop_phase)) * 0.072 if moving else 0.0
		sprite.position.y = _base_y + idle_bob + walk_hop + special_hop
		sprite.rotation.z = lerpf(sprite.rotation.z, special_tilt, clampf(delta * 10.0, 0.0, 1.0))

		# Respiración y parpadeo sutil en Idle
		_blink_timer -= delta
		var blink_squash: float = 1.0
		if _blink_timer <= 0.0:
			if _blink_timer > -0.10:
				blink_squash = 0.94
			else:
				_blink_timer = randf_range(2.6, 5.4)
		var breathe: float = 1.0 + sin(_anim_time * 1.1) * 0.028
		sprite.scale = Vector3(_base_scale.x * (2.0 - breathe), _base_scale.y * breathe * blink_squash, _base_scale.z)


func _enter_idle_state() -> void:
	_state = AnimState.IDLE
	_state_timer = randf_range(1.6, 3.4)


func _enter_walk_state() -> void:
	_state = AnimState.WALK
	_state_timer = randf_range(2.2, 4.2)
	_patrol_target = Vector3(
		randf_range(-patrol_bounds.x, patrol_bounds.x),
		0.0,
		randf_range(-patrol_bounds.y, patrol_bounds.y)
	)


func _enter_special_state() -> void:
	_state = AnimState.SPECIAL_ANIM
	_state_timer = 0.85
	_special_phase = 0.0
	if sprite and randf() < 0.5:
		sprite.flip_h = not sprite.flip_h


func play_reaction(emote: String = "♥", jump: bool = true) -> void:
	if jump and sprite:
		var tw: Tween = create_tween()
		tw.tween_property(self, "position:y", 0.22, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var lbl: Label3D = Label3D.new()
	lbl.text = emote
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 26
	lbl.outline_size = 6
	lbl.modulate = Color(1.0, 0.90, 0.36, 1.0) if emote.contains("Nv") or emote == "★" else Color(1.0, 0.65, 0.82, 1.0)
	lbl.position = Vector3(0.0, 1.28, 0.0)
	add_child(lbl)

	var tw_lbl: Tween = create_tween()
	tw_lbl.set_parallel(true)
	tw_lbl.tween_property(lbl, "position:y", 1.92, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_lbl.tween_property(lbl, "modulate:a", 0.0, 0.95)
	tw_lbl.chain().tween_callback(lbl.queue_free)


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

	var stage_scale: float = 0.94 if etapa == "cria" else (1.12 if etapa == "joven" else 1.28)
	_base_scale = Vector3.ONE * stage_scale
	sprite.scale = _base_scale
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var tex_path: String = "res://assets/sprites/dragons/%s_%s.png" % [sprite_prefijo, etapa]
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
		sprite.pixel_size = 0.022
	else:
		sprite.texture = build_dragon_texture(especie_id, etapa)
		sprite.pixel_size = 0.023


func update_progression(new_nivel: int, new_etapa: String) -> void:
	var evolved: bool = new_etapa != etapa
	setup_visual(especie_id, dragon_nombre, sprite_prefijo, new_etapa, dragon_uid, new_nivel)
	if evolved and sprite:
		var tw: Tween = create_tween()
		tw.tween_property(sprite, "modulate", Color(1.5, 1.35, 0.65, 1.0), 0.18)
		tw.parallel().tween_property(self, "rotation:y", rotation.y + TAU, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
		play_reaction("✦ %s!" % new_etapa.capitalize(), true)
	else:
		play_reaction("⬆ Nv.%d!" % new_nivel, true)


## Fábrica pública cacheada de texturas pixel art 48x48 (reutilizable en Bestiario, Combate y Tienda)
static func build_dragon_texture(id: int, stage: String = "adulto") -> ImageTexture:
	var cache_key: String = "%d_%s" % [id, stage]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]

	var prim_id: int = clampi(id, 1, 9)
	var sec_id: int = 0
	var rareza: String = "PURO"

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameCore"):
		var core: Node = tree.root.get_node("GameCore")
		var sp: Dictionary = core.call("get_species", id)
		if not sp.is_empty():
			prim_id = int(sp.get("elemento_primario_id", 1))
			var sec_var: Variant = sp.get("elemento_secundario_id", null)
			sec_id = int(sec_var) if sec_var != null else 0
			rareza = str(sp.get("rareza", "PURO"))

	var pal_prim: Dictionary = _get_element_palette(prim_id)
	var pal_sec: Dictionary = _get_element_palette(sec_id) if sec_id > 0 else pal_prim

	# Para variantes híbridas B/A o IDs distintos, variar ligeramente el matiz para identidad única
	var hue_shift: float = float((id * 17) % 11 - 5) * 0.012
	var pal: Dictionary = {
		"body": _shift_hue(pal_prim["body"], hue_shift),
		"body_dark": _shift_hue(pal_prim["body"], hue_shift).darkened(0.26),
		"body_light": _shift_hue(pal_prim["body"], hue_shift).lightened(0.24),
		"belly": pal_prim["belly"],
		"belly_dark": pal_prim["belly"].darkened(0.18),
		"wing": pal_sec["accent"] if sec_id > 0 else pal_prim["accent"],
		"wing_dark": (pal_sec["accent"] if sec_id > 0 else pal_prim["accent"]).darkened(0.28),
		"accent": pal_sec["highlight"] if sec_id > 0 else pal_prim["highlight"],
		"outline": pal_prim["outline"],
		"eye": pal_prim["eye"]
	}

	var img: Image = Image.create(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	_draw_dragon_48(img, pal, prim_id, sec_id, stage, rareza)
	_apply_pixel_outline(img, pal["outline"])

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_tex_cache[cache_key] = tex
	return tex


static func _shift_hue(col: Color, delta_h: float) -> Color:
	return Color.from_hsv(fposmod(col.h + delta_h, 1.0), col.s, col.v, col.a)


static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 1 and x < CANVAS_SIZE - 1 and y >= 1 and y < CANVAS_SIZE - 1:
		img.set_pixel(x, y, col)


static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color, light_col: Color, dark_col: Color) -> void:
	var min_x: int = maxi(1, int(floor(cx - rx)))
	var max_x: int = mini(CANVAS_SIZE - 2, int(ceil(cx + rx)))
	var min_y: int = maxi(1, int(floor(cy - ry)))
	var max_y: int = mini(CANVAS_SIZE - 2, int(ceil(cy + ry)))
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var nx: float = (float(x) - cx) / maxf(rx, 0.1)
			var ny: float = (float(y) - cy) / maxf(ry, 0.1)
			if nx * nx + ny * ny <= 1.0:
				var shade: float = nx * 0.45 + ny * 0.65
				if shade < -0.32:
					_px(img, x, y, light_col)
				elif shade > 0.36:
					_px(img, x, y, dark_col)
				else:
					_px(img, x, y, col)


static func _draw_dragon_48(img: Image, pal: Dictionary, prim_id: int, sec_id: int, stage: String, rareza: String) -> void:
	var body: Color = pal["body"]
	var b_light: Color = pal["body_light"]
	var b_dark: Color = pal["body_dark"]
	var belly: Color = pal["belly"]
	var belly_d: Color = pal["belly_dark"]
	var wing: Color = pal["wing"]
	var wing_d: Color = pal["wing_dark"]
	var accent: Color = pal["accent"]
	var eye: Color = pal["eye"]
	var outline: Color = pal["outline"]

	var is_baby: bool = (stage == "cria")
	var is_adult: bool = (stage == "adulto")

	# 1. Cola curva hacia la izquierda
	var tail_len: int = 8 if is_baby else (12 if stage == "joven" else 15)
	for t: int in range(tail_len):
		var tx: int = 17 - t
		var ty: int = 33 - int(round(sin(float(t) * 0.32) * 3.0)) - (t / 4)
		var r: int = 2 if t < tail_len / 2 else 1
		for dy: int in range(-r, r + 1):
			_px(img, tx, ty + dy, b_dark if dy > 0 else body)
	# Punta elemental de la cola
	var tip_x: int = 17 - tail_len
	var tip_y: int = 33 - int(round(sin(float(tail_len) * 0.32) * 3.0)) - (tail_len / 4)
	_fill_ellipse(img, float(tip_x), float(tip_y), 2.5 if is_adult else 1.8, 2.5 if is_adult else 1.8, wing, accent, wing_d)

	# 2. Ala trasera (detrás del cuerpo)
	var wing_span: float = 5.0 if is_baby else (9.5 if stage == "joven" else 13.5)
	var wing_h: float = 5.0 if is_baby else (8.5 if stage == "joven" else 11.5)
	for wx: int in range(0, int(wing_span)):
		var ratio: float = float(wx) / maxf(wing_span, 1.0)
		var top_y: int = int(round(22.0 - ratio * wing_h))
		var bot_y: int = int(round(26.0 - ratio * (wing_h * 0.45) + sin(ratio * PI * 3.0) * 1.4))
		for wy: int in range(top_y, bot_y + 1):
			var px_x: int = 20 - wx
			_px(img, px_x, wy, wing_d if wy > bot_y - 2 else (accent if wy == top_y else wing))

	# 3. Torso principal + vientre escamado
	var body_cx: float = 23.0
	var body_cy: float = 30.0 if is_baby else 29.0
	var body_rx: float = 6.8 if is_baby else (7.8 if stage == "joven" else 8.8)
	var body_ry: float = 6.2 if is_baby else (7.2 if stage == "joven" else 8.2)
	_fill_ellipse(img, body_cx, body_cy, body_rx, body_ry, body, b_light, b_dark)

	# Placas del vientre (derecha-frontal)
	_fill_ellipse(img, body_cx + 2.5, body_cy + 1.5, body_rx * 0.55, body_ry * 0.65, belly, belly.lightened(0.15), belly_d)
	for sy: int in range(int(body_cy - 3), int(body_cy + 5), 2):
		for sx: int in range(int(body_cx + 1), int(body_cx + 6)):
			_px(img, sx, sy, belly_d)

	# 4. Patas delanteras y traseras con garras
	_fill_ellipse(img, 19.0, 37.5, 2.8, 3.2, b_dark, body, b_dark)
	_fill_ellipse(img, 27.5, 37.5, 2.8, 3.2, body, b_light, b_dark)
	for claw_x: int in [17, 19, 21, 26, 28, 30]:
		_px(img, claw_x, 40, accent)

	# 5. Cuello y Cabeza (cría más cabezona y tierna, adulto más imponente)
	var head_cx: float = 27.0 if is_baby else 28.5
	var head_cy: float = 19.5 if is_baby else (17.5 if stage == "joven" else 15.5)
	var head_rx: float = 6.6 if is_baby else (6.2 if stage == "joven" else 6.8)
	var head_ry: float = 5.8 if is_baby else (5.4 if stage == "joven" else 5.6)

	# Cuello
	_fill_ellipse(img, 25.5, (body_cy + head_cy) * 0.5, 3.6, 4.5, body, b_light, b_dark)
	# Cabeza
	_fill_ellipse(img, head_cx, head_cy, head_rx, head_ry, body, b_light, b_dark)
	# Hocico orientado a la derecha
	_fill_ellipse(img, head_cx + 5.2, head_cy + 1.2, 3.6 if is_adult else 2.8, 2.6 if is_adult else 2.1, body, b_light, b_dark)
	_px(img, int(head_cx + 7), int(head_cy + 0.5), outline) # fosa nasal

	# Ojo expresivo con brillo blanco
	var ex: int = int(head_cx + 2)
	var ey: int = int(head_cy - 1)
	for dy: int in range(0, 3):
		for dx: int in range(0, 3):
			_px(img, ex + dx, ey + dy, eye)
	_px(img, ex + 2, ey + 1, outline)
	_px(img, ex + 2, ey + 2, outline)
	_px(img, ex, ey, Color.WHITE)

	# 6. Ala delantera (resaltada sobre el hombro)
	for wx: int in range(0, int(wing_span * 0.9)):
		var ratio: float = float(wx) / maxf(wing_span * 0.9, 1.0)
		var top_y: int = int(round(25.0 - ratio * (wing_h * 0.9)))
		var bot_y: int = int(round(29.0 - ratio * (wing_h * 0.35)))
		for wy: int in range(top_y, bot_y + 1):
			_px(img, 22 - wx, wy, accent if wy == top_y else wing)

	# 7. Cuernos / Cresta / Detalles según elemento primario (y secundario si es híbrido)
	var horn_h: int = 3 if is_baby else (5 if stage == "joven" else 7)
	match prim_id:
		1: # Tierra: cuernos robustos y placas dorsales
			for h: int in range(horn_h):
				_px(img, int(head_cx - 2 - h / 2), int(head_cy - 5 - h), accent)
				_px(img, int(head_cx - 1 - h / 2), int(head_cy - 5 - h), wing)
		2: # Fuego: cresta flamígera ardiente
			for h: int in range(horn_h + 2):
				_px(img, int(head_cx - 2 + (h % 2)), int(head_cy - 5 - h), accent if h > horn_h / 2 else wing)
				_px(img, int(head_cx - 4), int(head_cy - 3 - h / 2), wing)
		3: # Agua: aleta dorsal fluida y branquias
			for h: int in range(horn_h + 1):
				_px(img, int(head_cx - 3 - h / 2), int(head_cy - 4 - h / 2), accent)
				_px(img, int(head_cx - 2 - h / 2), int(head_cy - 3 - h / 2), wing)
		4: # Planta: corona de hojas y brote
			for h: int in range(horn_h):
				_px(img, int(head_cx - 1 - h), int(head_cy - 5 - h / 2), accent)
				_px(img, int(head_cx + 1 + h / 2), int(head_cy - 6 - h / 2), wing)
		5: # Eléctrico: rayos zigzag sobre la cabeza
			for h: int in range(horn_h + 1):
				var zig: int = 1 if (h % 2 == 0) else -1
				_px(img, int(head_cx - 1 + zig), int(head_cy - 5 - h), accent)
				_px(img, int(head_cx - 2 + zig), int(head_cy - 5 - h), wing)
		6: # Hielo: corona cristalina afilada
			for h: int in range(horn_h + 1):
				_px(img, int(head_cx - 2), int(head_cy - 5 - h), Color.WHITE if h == horn_h else accent)
				_px(img, int(head_cx + 1), int(head_cy - 5 - (h * 2) / 3), accent)
		7: # Metal: cresta blindada angular
			for h: int in range(horn_h):
				_px(img, int(head_cx - 3), int(head_cy - 5 - h), Color.WHITE if h % 2 == 0 else wing)
				_px(img, int(head_cx - 2), int(head_cy - 5 - h), wing_d)
		8: # Oscuro: cuernos curvos sombríos y aura
			for h: int in range(horn_h + 1):
				_px(img, int(head_cx - 3 - h / 2), int(head_cy - 5 - h), wing)
				_px(img, int(head_cx + 1 - h / 2), int(head_cy - 6 - h), accent)
		_: # Legendario (9): corona estelar dorada
			for h: int in range(horn_h + 2):
				_px(img, int(head_cx - 1), int(head_cy - 6 - h), Color(1.0, 0.94, 0.45))
				_px(img, int(head_cx - 4), int(head_cy - 5 - h / 2), accent)
				_px(img, int(head_cx + 2), int(head_cy - 5 - h / 2), accent)

	# Espinas dorsales del elemento secundario para híbridos
	if sec_id > 0:
		for s: int in range(4):
			_px(img, 18 + s * 2, 22 + s, accent)
			_px(img, 18 + s * 2, 21 + s, wing)

	# Halo legendario brillante para los 4 Legendarios
	if rareza == "LEGENDARIO" or prim_id == 9:
		for ang_i: int in range(12):
			var ang: float = float(ang_i) * (TAU / 12.0)
			var hx: int = int(round(head_cx + cos(ang) * 9.0))
			var hy: int = int(round(head_cy - 6.0 + sin(ang) * 2.5))
			_px(img, hx, hy, Color(1.0, 0.92, 0.40, 1.0))


static func _apply_pixel_outline(img: Image, outline_col: Color) -> void:
	var to_outline: Array[Vector2i] = []
	for y: int in range(1, CANVAS_SIZE - 1):
		for x: int in range(1, CANVAS_SIZE - 1):
			if img.get_pixel(x, y).a > 0.05:
				continue
			if (
				img.get_pixel(x - 1, y).a > 0.5
				or img.get_pixel(x + 1, y).a > 0.5
				or img.get_pixel(x, y - 1).a > 0.5
				or img.get_pixel(x, y + 1).a > 0.5
			):
				to_outline.append(Vector2i(x, y))
	for pt: Vector2i in to_outline:
		img.set_pixel(pt.x, pt.y, outline_col)


static func _get_element_palette(elem_id: int) -> Dictionary:
	match elem_id:
		1: # Tierra
			return {
				"body": Color(0.76, 0.44, 0.22, 1.0),
				"belly": Color(0.94, 0.78, 0.54, 1.0),
				"accent": Color(0.56, 0.32, 0.16, 1.0),
				"highlight": Color(0.98, 0.86, 0.62, 1.0),
				"outline": Color(0.18, 0.10, 0.06, 1.0),
				"eye": Color(1.0, 0.96, 0.82, 1.0)
			}
		2: # Fuego
			return {
				"body": Color(0.90, 0.24, 0.14, 1.0),
				"belly": Color(1.0, 0.72, 0.26, 1.0),
				"accent": Color(1.0, 0.48, 0.10, 1.0),
				"highlight": Color(1.0, 0.94, 0.38, 1.0),
				"outline": Color(0.24, 0.06, 0.05, 1.0),
				"eye": Color(1.0, 0.96, 0.58, 1.0)
			}
		3: # Agua
			return {
				"body": Color(0.16, 0.54, 0.90, 1.0),
				"belly": Color(0.70, 0.94, 1.0, 1.0),
				"accent": Color(0.12, 0.78, 0.88, 1.0),
				"highlight": Color(0.88, 0.98, 1.0, 1.0),
				"outline": Color(0.06, 0.16, 0.34, 1.0),
				"eye": Color(0.96, 1.0, 1.0, 1.0)
			}
		4: # Planta
			return {
				"body": Color(0.22, 0.70, 0.30, 1.0),
				"belly": Color(0.78, 0.94, 0.56, 1.0),
				"accent": Color(0.42, 0.86, 0.32, 1.0),
				"highlight": Color(0.94, 0.98, 0.68, 1.0),
				"outline": Color(0.08, 0.22, 0.10, 1.0),
				"eye": Color(1.0, 0.96, 0.70, 1.0)
			}
		5: # Eléctrico
			return {
				"body": Color(0.96, 0.80, 0.16, 1.0),
				"belly": Color(1.0, 0.96, 0.66, 1.0),
				"accent": Color(0.32, 0.88, 1.0, 1.0),
				"highlight": Color(1.0, 1.0, 0.88, 1.0),
				"outline": Color(0.16, 0.14, 0.28, 1.0),
				"eye": Color(0.42, 0.94, 1.0, 1.0)
			}
		6: # Hielo
			return {
				"body": Color(0.52, 0.84, 0.98, 1.0),
				"belly": Color(0.92, 0.98, 1.0, 1.0),
				"accent": Color(0.32, 0.68, 0.94, 1.0),
				"highlight": Color(1.0, 1.0, 1.0, 1.0),
				"outline": Color(0.12, 0.26, 0.42, 1.0),
				"eye": Color(0.96, 1.0, 1.0, 1.0)
			}
		7: # Metal
			return {
				"body": Color(0.62, 0.68, 0.76, 1.0),
				"belly": Color(0.86, 0.90, 0.94, 1.0),
				"accent": Color(0.42, 0.48, 0.58, 1.0),
				"highlight": Color(0.98, 0.99, 1.0, 1.0),
				"outline": Color(0.14, 0.16, 0.22, 1.0),
				"eye": Color(1.0, 0.56, 0.20, 1.0)
			}
		8: # Oscuro
			return {
				"body": Color(0.32, 0.16, 0.48, 1.0),
				"belly": Color(0.54, 0.34, 0.70, 1.0),
				"accent": Color(0.76, 0.22, 0.84, 1.0),
				"highlight": Color(0.96, 0.48, 0.92, 1.0),
				"outline": Color(0.08, 0.04, 0.14, 1.0),
				"eye": Color(1.0, 0.28, 0.48, 1.0)
			}
		_: # Legendario (9)
			return {
				"body": Color(0.44, 0.28, 0.86, 1.0),
				"belly": Color(0.98, 0.90, 0.64, 1.0),
				"accent": Color(0.98, 0.76, 0.24, 1.0),
				"highlight": Color(1.0, 0.96, 0.72, 1.0),
				"outline": Color(0.14, 0.08, 0.26, 1.0),
				"eye": Color(0.52, 0.96, 1.0, 1.0)
			}
