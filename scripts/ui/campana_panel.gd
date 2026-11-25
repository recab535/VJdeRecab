extends Control

## Carrusel horizontal de 50 capítulos PvE (5 por cada uno de los 8 elementos + 10 Legendarios).
## Cada capítulo exige 1 especie específica del catálogo (especie_requerida_id) para habilitar Pelear.

signal chapter_battle_requested(chapter_data: Dictionary)

const ARC_INFO: Array[Dictionary] = [
	{"nombre": "Tierra", "color": Color(0.66, 0.44, 0.24), "elem_id": 1},
	{"nombre": "Fuego", "color": Color(0.92, 0.34, 0.18), "elem_id": 2},
	{"nombre": "Agua", "color": Color(0.22, 0.62, 0.94), "elem_id": 3},
	{"nombre": "Planta", "color": Color(0.28, 0.78, 0.36), "elem_id": 4},
	{"nombre": "Eléctrico", "color": Color(0.95, 0.82, 0.22), "elem_id": 5},
	{"nombre": "Hielo", "color": Color(0.56, 0.88, 0.98), "elem_id": 6},
	{"nombre": "Metal", "color": Color(0.64, 0.68, 0.74), "elem_id": 7},
	{"nombre": "Oscuro", "color": Color(0.42, 0.24, 0.58), "elem_id": 8},
	{"nombre": "Legendario", "color": Color(0.92, 0.72, 0.24), "elem_id": 9}
]

# 50 capítulos -> cada uno exige una especie específica (IDs 1..68 del catálogo oficial)
const CHAPTER_REQUIRED_SPECIES: Array[int] = [
	1, 2, 9, 10, 11,
	2, 21, 22, 23, 24,
	3, 12, 31, 32, 33,
	4, 13, 14, 39, 40,
	5, 25, 26, 34, 45,
	6, 15, 16, 35, 36,
	7, 17, 18, 27, 28,
	8, 19, 20, 29, 30,
	57, 58, 59, 60, 61, 62, 63, 64, 65, 68
]

@onready var scroll_chapters: ScrollContainer = %ScrollChapters
@onready var chapters_row: HBoxContainer = %ChaptersRow
@onready var lbl_progreso: Label = %LblCampProgreso
@onready var btn_scroll_izq: Button = %BtnScrollIzq
@onready var btn_scroll_der: Button = %BtnScrollDer
@onready var btn_cerrar: Button = %BtnCerrarCamp


func _ready() -> void:
	visible = false
	if btn_cerrar:
		btn_cerrar.pressed.connect(func() -> void: visible = false)
	if btn_scroll_izq:
		btn_scroll_izq.pressed.connect(func() -> void: _scroll_by(-560))
	if btn_scroll_der:
		btn_scroll_der.pressed.connect(func() -> void: _scroll_by(560))


func open_campaign() -> void:
	refresh()
	visible = true
	pivot_offset = size * 0.5
	scale = Vector2(0.95, 0.95)
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	call_deferred("_scroll_to_current_chapter")


func _play_sfx(kind: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", kind)


func _scroll_to_current_chapter() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null or scroll_chapters == null:
		return
	var camp: Dictionary = core.player_state.get("campana", {})
	var unlocked_cap: int = maxi(1, int(camp.get("capitulo_desbloqueado", 1)))
	var target_x: int = maxi(0, (unlocked_cap - 2) * 284)
	scroll_chapters.scroll_horizontal = target_x


func _scroll_by(delta_px: int) -> void:
	if scroll_chapters == null:
		return
	_play_sfx("click")
	var target: int = maxi(0, scroll_chapters.scroll_horizontal + delta_px)
	var tw: Tween = create_tween()
	tw.tween_property(scroll_chapters, "scroll_horizontal", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func build_chapter_data(cap_num: int) -> Dictionary:
	var arc_idx: int = mini(8, (cap_num - 1) / 5) if cap_num <= 40 else 8
	var arc: Dictionary = ARC_INFO[arc_idx]
	var req_id: int = CHAPTER_REQUIRED_SPECIES[clampi(cap_num - 1, 0, CHAPTER_REQUIRED_SPECIES.size() - 1)]
	var oro_rew: int = 350 + cap_num * 180
	var comida_rew: int = 180 + cap_num * 95
	var gemas_rew: int = 5 if (cap_num % 5 == 0 or cap_num == 1) else 1
	var exp_rew: int = 60 + cap_num * 25
	var enemy_lvl: int = clampi(1 + int(round(float(cap_num - 1) * 28.0 / 49.0)), 1, 29)
	var elem_id: int = int(arc["elem_id"])
	var e1: int = elem_id if elem_id <= 8 else 65
	var e2: int = mini(68, req_id)
	var e3: int = mini(68, maxi(2, (cap_num + 4) % 64 + 1))
	return {
		"capitulo": cap_num,
		"arco": str(arc["nombre"]),
		"color": arc["color"],
		"especie_requerida_id": req_id,
		"oro": oro_rew,
		"comida": comida_rew,
		"gemas": gemas_rew,
		"exp": exp_rew,
		"enemigos": [
			{"especie_id": e1, "nivel": enemy_lvl},
			{"especie_id": e2, "nivel": enemy_lvl},
			{"especie_id": e3, "nivel": enemy_lvl + 1}
		]
	}


func refresh() -> void:
	for c: Node in chapters_row.get_children():
		c.queue_free()

	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	var camp: Dictionary = core.player_state.get("campana", {"capitulo_desbloqueado": 1, "completados": []})
	var unlocked_cap: int = maxi(1, int(camp.get("capitulo_desbloqueado", 1)))
	var completed: Array = camp.get("completados", [])
	lbl_progreso.text = "Progreso Historia: %d / 50 completados  |  Desbloqueado: Cap. %d" % [completed.size(), unlocked_cap]

	for cap: int in range(1, 51):
		var data: Dictionary = build_chapter_data(cap)
		var req_id: int = int(data["especie_requerida_id"])
		var req_sp: Dictionary = core.get_species(req_id)
		var req_name: String = str(req_sp.get("nombre", "Especie #%d" % req_id))
		var owns_req: bool = core.has_species_in_collection(req_id)
		var is_unlocked: bool = cap <= unlocked_cap
		var is_done: bool = completed.has(cap)

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(268, 360)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		card.add_child(vbox)

		var bar: ColorRect = ColorRect.new()
		bar.custom_minimum_size = Vector2(0, 18)
		bar.color = data["color"]
		vbox.add_child(bar)

		var lbl_cap: Label = Label.new()
		lbl_cap.text = "Capítulo %d%s" % [cap, " ✓" if is_done else ""]
		lbl_cap.add_theme_font_size_override("font_size", 20)
		lbl_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl_cap)

		var lbl_arc: Label = Label.new()
		lbl_arc.text = "Arco %s" % str(data["arco"])
		lbl_arc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl_arc)

		var portrait: TextureRect = TextureRect.new()
		portrait.texture = Dragon2D.build_dragon_texture(req_id, "joven")
		portrait.custom_minimum_size = Vector2(76, 76)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.modulate = Color.WHITE if owns_req else Color(0.14, 0.16, 0.24, 0.92)
		vbox.add_child(portrait)

		var lbl_req: Label = Label.new()
		lbl_req.text = "Dragón obligatorio:\n%s (ID %d)\n%s" % [
			req_name,
			req_id,
			"✔ En tu colección" if owns_req else "✖ No poseído aún"
		]
		lbl_req.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_req.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl_req.add_theme_color_override("font_color", Color(0.42, 0.96, 0.56) if owns_req else Color(1.0, 0.48, 0.45))
		vbox.add_child(lbl_req)

		var lbl_rew: Label = Label.new()
		lbl_rew.text = "Recompensas:\n+%d Oro • +%d Comida\n+%d Gemas • +%d EXP" % [
			int(data["oro"]), int(data["comida"]), int(data["gemas"]), int(data["exp"])
		]
		lbl_rew.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_rew.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(lbl_rew)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		if not is_unlocked:
			btn.text = "Bloqueado (Cap. %d)" % (cap - 1)
			btn.disabled = true
		elif not owns_req:
			btn.text = "Falta %s" % req_name
			btn.disabled = true
		else:
			btn.text = "Pelear (1v1)"
			var captured: Dictionary = data
			btn.pressed.connect(func() -> void:
				_play_sfx("click")
				visible = false
				chapter_battle_requested.emit(captured)
			)
		vbox.add_child(btn)
		chapters_row.add_child(card)
