extends Control
class_name BreedingPanel

## Panel selector de especies para cruzar dos dragones y enviar el huevo al Nido.

signal closed
signal breeding_completed(result: Dictionary)

@onready var lbl_nido_estado: Label = %LblNidoEstado
@onready var btn_cerrar: Button = %BtnCerrar
@onready var lbl_padre_a: Label = %LblPadreA
@onready var list_padre_a: VBoxContainer = %ListPadreA
@onready var icon_resultado: TextureRect = %IconResultado
@onready var lbl_resultado_titulo: Label = %LblResultadoTitulo
@onready var lbl_resultado_detalle: Label = %LblResultadoDetalle
@onready var btn_iniciar_cruce: Button = %BtnIniciarCruce
@onready var lbl_feedback: Label = %LblFeedback
@onready var lbl_padre_b: Label = %LblPadreB
@onready var list_padre_b: VBoxContainer = %ListPadreB

var _selected_a: Dictionary = {}
var _selected_b: Dictionary = {}


func _ready() -> void:
	visible = false
	btn_cerrar.pressed.connect(close_breeding)
	btn_iniciar_cruce.pressed.connect(_on_iniciar_cruce_pressed)


func open_breeding() -> void:
	visible = true
	lbl_feedback.text = ""
	_selected_a = {}
	_selected_b = {}
	refresh()
	pivot_offset = size * 0.5
	scale = Vector2(0.95, 0.95)
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)


func close_breeding() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	var huevos: Array = core.get_nest_eggs()
	var max_slots: int = core.get_nest_max_slots() if core.has_method("get_nest_max_slots") else 1
	lbl_nido_estado.text = "Nido: %d / %d huevos" % [huevos.size(), max_slots]

	var options_a: Array[Dictionary] = _build_parent_options(core, false)
	var options_b: Array[Dictionary] = _build_parent_options(core, true)

	if _selected_a.is_empty() and not options_a.is_empty():
		_selected_a = options_a[0]
	if _selected_b.is_empty():
		for opt: Dictionary in options_b:
			if int(opt.get("uid", -1)) != int(_selected_a.get("uid", -2)) or bool(opt.get("is_guest", false)):
				_selected_b = opt
				break

	_populate_parent_list(core, list_padre_a, options_a, true)
	_populate_parent_list(core, list_padre_b, options_b, false)
	_update_preview(core)


func _build_parent_options(core: Node, include_guests_if_needed: bool) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var owned: Array = core.player_state.get("dragones", [])
	for d_var: Variant in owned:
		if not (d_var is Dictionary):
			continue
		var d: Dictionary = d_var
		var sp_id: int = int(d.get("especie_id", 1))
		var sp: Dictionary = core.get_species(sp_id)
		list.append({
			"uid": int(d.get("uid", -1)),
			"especie_id": sp_id,
			"nombre": str(sp.get("nombre", "Dragón #%d" % sp_id)),
			"nivel": maxi(1, int(d.get("nivel", 1))),
			"etapa": str(d.get("etapa", "cria")),
			"elementos": sp.get("elementos", []),
			"prefijo": str(sp.get("sprite_prefijo", "dragon_terracota")),
			"is_guest": false
		})

	if include_guests_if_needed and list.size() < 2:
		for guest_id: int in [2, 3, 4]:
			var sp: Dictionary = core.get_species(guest_id)
			if sp.is_empty():
				continue
			list.append({
				"uid": -100 - guest_id,
				"especie_id": guest_id,
				"nombre": str(sp.get("nombre", "Dragón #%d" % guest_id)),
				"nivel": 1,
				"etapa": "joven",
				"elementos": sp.get("elementos", []),
				"prefijo": str(sp.get("sprite_prefijo", "dragon_terracota")),
				"is_guest": true
			})

	return list


func _populate_parent_list(core: Node, container: VBoxContainer, options: Array[Dictionary], is_side_a: bool) -> void:
	for child: Node in container.get_children():
		child.queue_free()

	if options.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No tienes dragones disponibles."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(empty_lbl)
		return

	var current_sel: Dictionary = _selected_a if is_side_a else _selected_b
	var other_sel: Dictionary = _selected_b if is_side_a else _selected_a

	for opt: Dictionary in options:
		var uid: int = int(opt.get("uid", -1))
		var sp_id: int = int(opt.get("especie_id", 1))
		var is_selected: bool = uid == int(current_sel.get("uid", -999))
		var is_taken_by_other: bool = (not bool(opt.get("is_guest", false))) and uid == int(other_sel.get("uid", -999))

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = is_taken_by_other
		btn.icon = _resolve_species_texture(sp_id, str(opt.get("etapa", "cria")))
		btn.expand_icon = true

		var elem_str: String = _format_elements(core, opt.get("elementos", []))
		var tag: String = "Invitado" if bool(opt.get("is_guest", false)) else "Nv.%d" % int(opt.get("nivel", 1))
		var prefix_mark: String = "▶ " if is_selected else ""
		btn.text = "%s%s (%s) — %s" % [prefix_mark, str(opt.get("nombre", "Dragón")), tag, elem_str]
		if is_selected:
			btn.modulate = Color(0.82, 1.0, 0.85, 1.0)

		btn.pressed.connect(func() -> void:
			if is_side_a:
				_selected_a = opt
			else:
				_selected_b = opt
			lbl_feedback.text = ""
			var am: Node = get_node_or_null("/root/AudioManager")
			if am and am.has_method("play_sfx"):
				am.call("play_sfx", "click")
			refresh()
		)
		container.add_child(btn)


func _update_preview(core: Node) -> void:
	lbl_padre_a.text = "Padre 1: %s" % str(_selected_a.get("nombre", "Ninguno"))
	lbl_padre_b.text = "Padre 2: %s" % str(_selected_b.get("nombre", "Ninguno"))

	if _selected_a.is_empty() or _selected_b.is_empty():
		lbl_resultado_titulo.text = "Selecciona 2 dragones"
		lbl_resultado_detalle.text = "Elige un Padre 1 y un Padre 2 para previsualizar el huevo resultante."
		btn_iniciar_cruce.disabled = true
		icon_resultado.texture = null
		return

	var sp_a_id: int = int(_selected_a.get("especie_id", 1))
	var sp_b_id: int = int(_selected_b.get("especie_id", 1))
	var preview: Dictionary = core.get_breeding_preview(sp_a_id, sp_b_id)
	var candidates: Array = preview.get("candidates", [])

	if candidates.is_empty():
		lbl_resultado_titulo.text = "Sin resultado"
		lbl_resultado_detalle.text = "No se encontró combinación válida."
		btn_iniciar_cruce.disabled = true
		return

	icon_resultado.texture = _resolve_species_texture(int(candidates[0]), "cria")

	var names: PackedStringArray = []
	for cid: Variant in candidates:
		var sp: Dictionary = core.get_species(int(cid))
		names.append("%s (%s)" % [str(sp.get("nombre", "?")), _format_elements(core, sp.get("elementos", []))])

	var min_t: int = int(preview.get("min_time_seg", 300))
	var max_t: int = int(preview.get("max_time_seg", 300))
	var time_str: String = _format_time(min_t) if min_t == max_t else "%s - %s" % [_format_time(min_t), _format_time(max_t)]

	lbl_resultado_titulo.text = "Posible resultado (%d)" % candidates.size()
	lbl_resultado_detalle.text = "%s\n\nIncubación: %s" % ["\n• ".join([""] + Array(names)).strip_edges(), time_str]

	var max_slots: int = core.get_nest_max_slots() if core.has_method("get_nest_max_slots") else 1
	var cur_eggs: int = core.get_nest_eggs().size()
	var nido_lleno: bool = cur_eggs >= max_slots
	btn_iniciar_cruce.disabled = nido_lleno
	btn_iniciar_cruce.text = "Nido Lleno (%d/%d)" % [cur_eggs, max_slots] if nido_lleno else "Iniciar Cruce"


func _on_iniciar_cruce_pressed() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null or _selected_a.is_empty() or _selected_b.is_empty():
		return

	var sp_a_id: int = int(_selected_a.get("especie_id", 1))
	var sp_b_id: int = int(_selected_b.get("especie_id", 1))
	var res: Dictionary = core.start_breeding(sp_a_id, sp_b_id)
	lbl_feedback.text = str(res.get("msg", ""))
	breeding_completed.emit(res)
	refresh()


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


func _resolve_species_texture(sp_id: int, etapa: String = "cria") -> Texture2D:
	return Dragon2D.build_dragon_texture(sp_id, etapa)
