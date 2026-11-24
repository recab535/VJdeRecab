extends Control
class_name BestiarioPanel

## Panel UI del Bestiario: muestra las 68 especies del catálogo (descubiertas y bloqueadas).

signal closed

@onready var lbl_progreso: Label = %LblProgreso
@onready var btn_cerrar: Button = %BtnCerrar
@onready var btn_todos: Button = %BtnTodos
@onready var btn_descubiertos: Button = %BtnDescubiertos
@onready var btn_bloqueados: Button = %BtnBloqueados
@onready var grid_especies: GridContainer = %GridEspecies

var _current_filter: String = "todos"


func _ready() -> void:
	visible = false
	btn_cerrar.pressed.connect(close_bestiario)
	btn_todos.pressed.connect(func() -> void: _set_filter("todos"))
	btn_descubiertos.pressed.connect(func() -> void: _set_filter("descubiertos"))
	btn_bloqueados.pressed.connect(func() -> void: _set_filter("bloqueados"))


func open_bestiario() -> void:
	visible = true
	refresh()


func close_bestiario() -> void:
	visible = false
	closed.emit()


func _set_filter(filter_name: String) -> void:
	_current_filter = filter_name
	refresh()


func refresh() -> void:
	for child: Node in grid_especies.get_children():
		child.queue_free()

	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		lbl_progreso.text = "Descubiertos: 0 / 0"
		return

	var discovered_ids: Dictionary = _get_discovered_species_ids(core)
	var sorted_ids: Array = core.especies_by_id.keys()
	sorted_ids.sort()

	var discovered_count: int = 0
	for raw_id: Variant in sorted_ids:
		var sp_id: int = int(raw_id)
		if discovered_ids.has(sp_id):
			discovered_count += 1

	lbl_progreso.text = "Descubiertos: %d / %d" % [discovered_count, sorted_ids.size()]
	_update_filter_buttons()

	for raw_id: Variant in sorted_ids:
		var sp_id: int = int(raw_id)
		var is_discovered: bool = discovered_ids.has(sp_id)
		if _current_filter == "descubiertos" and not is_discovered:
			continue
		if _current_filter == "bloqueados" and is_discovered:
			continue

		var sp: Dictionary = core.especies_by_id.get(sp_id, {})
		var card: PanelContainer = _create_species_card(core, sp_id, sp, is_discovered)
		grid_especies.add_child(card)


func _get_discovered_species_ids(core: Node) -> Dictionary:
	var discovered: Dictionary = {}
	for d: Variant in core.player_state.get("dragones", []):
		if d is Dictionary:
			var sp_id: int = int(d.get("especie_id", 0))
			if sp_id > 0:
				discovered[sp_id] = true
	for g: Variant in core.player_state.get("guarderia", []):
		if g is Dictionary:
			var sp_id: int = int(g.get("especie_id", 0))
			if sp_id > 0:
				discovered[sp_id] = true
	return discovered


func _update_filter_buttons() -> void:
	btn_todos.disabled = (_current_filter == "todos")
	btn_descubiertos.disabled = (_current_filter == "descubiertos")
	btn_bloqueados.disabled = (_current_filter == "bloqueados")


func _create_species_card(core: Node, sp_id: int, sp: Dictionary, is_discovered: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(245, 132)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var nombre: String = str(sp.get("nombre", "Dragón #%d" % sp_id))
	var rareza: String = str(sp.get("rareza", "PURO"))
	var prefijo: String = str(sp.get("sprite_prefijo", "dragon_terracota"))
	var elem_ids: Array = sp.get("elementos", [])
	var elem_text: String = _format_elements(core, elem_ids)

	card.tooltip_text = "%s (%s)" % [nombre if is_discovered else "Especie bloqueada", prefijo]
	if not is_discovered:
		card.modulate = Color(0.65, 0.68, 0.76, 0.88)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	vbox.add_child(top_row)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _resolve_species_texture(sp_id, prefijo, is_discovered)
	icon.modulate = Color.WHITE if is_discovered else Color(0.10, 0.12, 0.18, 0.95)
	top_row.add_child(icon)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(title_box)

	var lbl_nombre: Label = Label.new()
	lbl_nombre.text = "#%02d %s" % [sp_id, nombre if is_discovered else "???"]
	lbl_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(lbl_nombre)

	var lbl_rareza: Label = Label.new()
	lbl_rareza.text = "Rareza: %s" % rareza
	var rar_col: Color = Color(1.0, 0.84, 0.28) if rareza == "LEGENDARIO" else (Color(0.86, 0.54, 1.0) if rareza == "OPUESTO" else Color(0.85, 0.88, 0.96, 0.92))
	lbl_rareza.modulate = rar_col
	title_box.add_child(lbl_rareza)

	var lbl_elementos: Label = Label.new()
	lbl_elementos.text = "Elementos: %s" % elem_text
	lbl_elementos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_elementos)

	var lbl_estado: Label = Label.new()
	if is_discovered:
		lbl_estado.text = "HP:%d  ATK:%d  SPD:%d  •  %d Oro/m" % [
			int(sp.get("hp_base", 100)),
			int(sp.get("atk_base", 20)),
			int(sp.get("spd_base", 15)),
			int(sp.get("oro_por_minuto", 12))
		]
		lbl_estado.modulate = Color(0.54, 0.96, 0.62, 1.0)
	else:
		lbl_estado.text = "Estado: Bloqueado (Descúbrelo cruzando)"
		lbl_estado.modulate = Color(0.72, 0.72, 0.78, 1.0)
	lbl_estado.add_theme_font_size_override("font_size", 14)
	vbox.add_child(lbl_estado)

	return card


func _format_elements(core: Node, elem_ids: Array) -> String:
	if elem_ids.is_empty():
		return "-"
	var names: PackedStringArray = []
	for raw_elem_id: Variant in elem_ids:
		var elem_data: Dictionary = core.get_element(int(raw_elem_id))
		names.append(str(elem_data.get("nombre", str(raw_elem_id))))
	return " / ".join(names)


func _resolve_species_texture(sp_id: int, prefijo: String, _is_discovered: bool) -> Texture2D:
	var tex_path: String = "res://assets/sprites/dragons/%s_adulto.png" % prefijo
	if ResourceLoader.exists(tex_path):
		return load(tex_path) as Texture2D
	return Dragon2D.build_dragon_texture(sp_id, "adulto")
