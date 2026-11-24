extends Control
class_name NestPanel

## Panel UI del Nido: muestra los huevos en incubación, su progreso y permite acelerar o eclosionar.

signal closed
signal egg_hatched(result: Dictionary)

@onready var lbl_capacidad: Label = %LblCapacidad
@onready var btn_mejorar_nido: Button = %BtnMejorarNido
@onready var btn_cerrar: Button = %BtnCerrar
@onready var list_huevos: VBoxContainer = %ListHuevos
@onready var lbl_feedback: Label = %LblFeedback

var _slot_widgets: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	btn_cerrar.pressed.connect(close_nest)
	if btn_mejorar_nido:
		btn_mejorar_nido.pressed.connect(_on_upgrade_nest_pressed)
	var core: Node = get_node_or_null("/root/GameCore")
	if core:
		core.nest_updated.connect(_on_nest_updated)
		core.resources_changed.connect(_on_resources_changed)


func _process(_delta: float) -> void:
	if not visible or _slot_widgets.is_empty():
		return
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	var huevos: Array = core.get_nest_eggs()
	for w: Dictionary in _slot_widgets:
		var idx: int = int(w.get("index", -1))
		if idx < 0 or idx >= huevos.size():
			continue
		var egg_var: Variant = huevos[idx]
		if not (egg_var is Dictionary):
			continue
		var egg: Dictionary = egg_var
		var total_sec: float = maxf(1.0, float(egg.get("tiempo_incubacion_seg", 300)))
		var rem_sec: float = maxf(0.0, float(egg.get("tiempo_restante_seg", 0.0)))
		var listo: bool = bool(egg.get("listo", false)) or rem_sec <= 0.0
		var pct: float = 100.0 if listo else clampf(((total_sec - rem_sec) / total_sec) * 100.0, 0.0, 100.0)

		var bar: ProgressBar = w.get("progress")
		var lbl_time: Label = w.get("lbl_time")
		if bar:
			bar.value = pct
		if lbl_time:
			if listo:
				lbl_time.text = "¡Listo para eclosionar!"
				lbl_time.modulate = Color(0.52, 0.95, 0.58, 1.0)
			else:
				lbl_time.text = "Incubando: %s (%.0f%%)" % [_format_time(int(ceil(rem_sec))), pct]
				lbl_time.modulate = Color(0.92, 0.92, 0.96, 1.0)


func open_nest() -> void:
	visible = true
	lbl_feedback.text = ""
	refresh()


func close_nest() -> void:
	visible = false
	closed.emit()


func _on_upgrade_nest_pressed() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core and core.has_method("upgrade_nest_tower"):
		var r: Dictionary = core.upgrade_nest_tower()
		lbl_feedback.text = str(r.get("msg", ""))
		refresh()


func _on_nest_updated() -> void:
	if visible:
		refresh()


func _on_resources_changed(_oro: int, _comida: int, _gemas: int) -> void:
	if visible:
		refresh()


func refresh() -> void:
	_slot_widgets.clear()
	for child: Node in list_huevos.get_children():
		child.queue_free()

	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	var huevos: Array = core.get_nest_eggs()
	var max_slots: int = core.get_nest_max_slots() if core.has_method("get_nest_max_slots") else 4
	lbl_capacidad.text = "Huevos: %d / %d" % [huevos.size(), max_slots]
	if btn_mejorar_nido and core.has_method("get_next_nest_upgrade_cost"):
		var up_cost: int = core.get_next_nest_upgrade_cost()
		if up_cost < 0:
			btn_mejorar_nido.text = "Máx. Ranuras (4/4)"
			btn_mejorar_nido.disabled = true
		else:
			var cur_gems: int = int(core.get_resources().get("gemas", 0))
			btn_mejorar_nido.text = "+1 Ranura (%d Gemas)" % up_cost
			btn_mejorar_nido.disabled = cur_gems < up_cost

	if huevos.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "El Nido está vacío.\nUsa el botón Cruce para seleccionar dos dragones y generar un huevo."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.custom_minimum_size = Vector2(0, 120)
		list_huevos.add_child(empty_lbl)
		return

	var gemas: int = int(core.get_resources().get("gemas", 0))
	for i: int in range(huevos.size()):
		var egg_var: Variant = huevos[i]
		if egg_var is Dictionary:
			var card: PanelContainer = _create_egg_card(core, i, egg_var, gemas)
			list_huevos.add_child(card)


func _create_egg_card(core: Node, idx: int, egg: Dictionary, gemas: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	var sp_id: int = int(egg.get("especie_id", 1))
	var sp: Dictionary = core.get_species(sp_id)
	var prefijo: String = str(sp.get("sprite_prefijo", "dragon_terracota"))

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _resolve_egg_texture(sp_id, prefijo)
	hbox.add_child(icon)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 6)
	hbox.add_child(info_box)

	var lbl_nombre: Label = Label.new()
	var elem_str: String = _format_elements(core, sp.get("elementos", []))
	lbl_nombre.text = "Huevo #%d: %s (%s)" % [idx + 1, str(egg.get("nombre", "Dragón")), elem_str]
	info_box.add_child(lbl_nombre)

	var total_sec: float = maxf(1.0, float(egg.get("tiempo_incubacion_seg", 300)))
	var rem_sec: float = maxf(0.0, float(egg.get("tiempo_restante_seg", 0.0)))
	var listo: bool = bool(egg.get("listo", false)) or rem_sec <= 0.0
	var pct: float = 100.0 if listo else clampf(((total_sec - rem_sec) / total_sec) * 100.0, 0.0, 100.0)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = pct
	bar.custom_minimum_size = Vector2(0, 20)
	info_box.add_child(bar)

	var lbl_time: Label = Label.new()
	if listo:
		lbl_time.text = "¡Listo para eclosionar!"
		lbl_time.modulate = Color(0.52, 0.95, 0.58, 1.0)
	else:
		lbl_time.text = "Incubando: %s (%.0f%%)" % [_format_time(int(ceil(rem_sec))), pct]
	info_box.add_child(lbl_time)

	var btn_action: Button = Button.new()
	btn_action.custom_minimum_size = Vector2(170, 46)
	if listo:
		btn_action.text = "Eclosionar"
		btn_action.pressed.connect(func() -> void:
			var res: Dictionary = core.hatch_egg_at(idx)
			lbl_feedback.text = str(res.get("msg", ""))
			egg_hatched.emit(res)
			refresh()
		)
	else:
		btn_action.text = "Acelerar (1 Gema)"
		btn_action.disabled = gemas < 1
		btn_action.pressed.connect(func() -> void:
			var res: Dictionary = core.accelerate_egg(idx, 1)
			lbl_feedback.text = str(res.get("msg", ""))
			refresh()
		)
	hbox.add_child(btn_action)

	_slot_widgets.append({
		"index": idx,
		"progress": bar,
		"lbl_time": lbl_time
	})

	return card


func _format_elements(core: Node, elem_ids: Array) -> String:
	if elem_ids.is_empty():
		return "-"
	var names: PackedStringArray = []
	for raw_id: Variant in elem_ids:
		var elem_data: Dictionary = core.get_element(int(raw_id))
		names.append(str(elem_data.get("nombre", str(raw_id))))
	return "/".join(names)


func _format_time(total_sec: int) -> String:
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	return "%02d:%02d" % [mins, secs]


func _resolve_egg_texture(sp_id: int, prefijo: String) -> Texture2D:
	var tex_path: String = "res://assets/sprites/dragons/%s_cria.png" % prefijo
	if ResourceLoader.exists(tex_path):
		return load(tex_path) as Texture2D

	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var shell_color: Color = Color(0.84, 0.42, 0.22, 1.0) if sp_id == 1 else Color.from_hsv(fmod(sp_id * 0.13, 1.0), 0.65, 0.88, 1.0)
	var spot_color: Color = shell_color.lightened(0.35)
	for y: int in range(3, 14):
		for x: int in range(4, 12):
			if (y == 3 or y == 13) and (x < 6 or x > 9):
				continue
			if y == 4 and (x == 4 or x == 11):
				continue
			img.set_pixel(x, y, shell_color)
	img.set_pixel(6, 6, spot_color)
	img.set_pixel(9, 8, spot_color)
	img.set_pixel(7, 10, spot_color)
	return ImageTexture.create_from_image(img)
