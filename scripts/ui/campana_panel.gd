extends Control

## Carrusel horizontal de 50 capítulos PvE cargados desde data/campana_50.json.
## Cada capítulo exige 1 especie única del catálogo (especie_requerida_id) para habilitar Pelear.

signal chapter_battle_requested(chapter_data: Dictionary)

const CAMPAIGN_JSON_PATH: String = "res://data/campana_50.json"

const ARC_COLORS: Dictionary = {
	1: Color(0.66, 0.44, 0.24),
	2: Color(0.92, 0.34, 0.18),
	3: Color(0.22, 0.62, 0.94),
	4: Color(0.28, 0.78, 0.36),
	5: Color(0.95, 0.82, 0.22),
	6: Color(0.56, 0.88, 0.98),
	7: Color(0.64, 0.68, 0.74),
	8: Color(0.42, 0.24, 0.58),
	9: Color(0.92, 0.72, 0.24)
}

var _chapters_cache: Array = []

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


func _ensure_chapters_loaded() -> void:
	if not _chapters_cache.is_empty():
		return
	var core: Node = get_node_or_null("/root/GameCore")
	if core and core.has_method("get_campaign_chapters"):
		var from_core: Array = core.call("get_campaign_chapters")
		if not from_core.is_empty():
			_chapters_cache = from_core
			return
	if FileAccess.file_exists(CAMPAIGN_JSON_PATH):
		var f: FileAccess = FileAccess.open(CAMPAIGN_JSON_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("capitulos"):
				_chapters_cache = (parsed as Dictionary)["capitulos"]


func build_chapter_data(cap_num: int) -> Dictionary:
	_ensure_chapters_loaded()
	for cap_var: Variant in _chapters_cache:
		if cap_var is Dictionary and int(cap_var.get("capitulo", 0)) == cap_num:
			var d: Dictionary = (cap_var as Dictionary).duplicate(true)
			var eid: int = int(d.get("elemento_id", 1))
			d["color"] = ARC_COLORS.get(eid, ARC_COLORS[1])
			return d
	return {
		"capitulo": cap_num,
		"titulo": "Capítulo %d" % cap_num,
		"arco": "Tierra",
		"elemento_id": 1,
		"color": ARC_COLORS[1],
		"especie_requerida_id": 1,
		"oro": 500,
		"comida": 260,
		"gemas": 1,
		"exp": 85,
		"enemigos": [{"especie_id": 2, "nivel": 1}]
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
		var titulo: String = str(data.get("titulo", ""))
		lbl_arc.text = "Arco %s%s" % [str(data["arco"]), ("\n" + titulo) if not titulo.is_empty() else ""]
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
		if is_done:
			lbl_rew.text = "Repetición (ya superado):\n+%d Oro • +%d Comida\n0 Gemas • +%d EXP" % [
				maxi(50, int(round(float(data["oro"]) * 0.35))),
				maxi(25, int(round(float(data["comida"]) * 0.35))),
				maxi(15, int(round(float(data["exp"]) * 0.30)))
			]
		else:
			lbl_rew.text = "Recompensas (1ª vez):\n+%d Oro • +%d Comida\n+%d Gemas • +%d EXP" % [
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
