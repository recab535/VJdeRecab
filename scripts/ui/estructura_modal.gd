extends Control

## Modal contextual unificado y en tiempo real para estructuras especiales:
## Mina de Gemas (1/isla, 24h), Campo de Entrenamiento, Guardería de Crías (máx 4) y Granja.

signal status_message(msg: String)
signal nursery_dragon_stored(dragon_uid: int)
signal nursery_dragon_retrieved(dragon_data: Dictionary)

@onready var lbl_titulo: Label = %LblEstTitulo
@onready var lbl_detalle: Label = %LblEstDetalle
@onready var box_acciones: VBoxContainer = %BoxAcciones
@onready var btn_cerrar: Button = %BtnCerrarEst

var _current_kind: String = ""
var _current_island_id: int = 1
var _live_accum: float = 0.0


func _ready() -> void:
	visible = false
	if btn_cerrar:
		btn_cerrar.pressed.connect(func() -> void: visible = false)


func _process(delta: float) -> void:
	if not visible:
		return
	_live_accum += delta
	if _live_accum >= 1.0:
		_live_accum = 0.0
		if _current_kind in ["mina_gemas", "campo_entrenamiento", "granja_comida"]:
			_refresh()


func open_for(kind: String, island_id: int = 1) -> void:
	_current_kind = kind
	_current_island_id = island_id
	_live_accum = 0.0
	_refresh()
	visible = true
	pivot_offset = size * 0.5
	scale = Vector2(0.94, 0.94)
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)


func _play_sfx(kind: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", kind)


func _refresh() -> void:
	for c: Node in box_acciones.get_children():
		c.queue_free()

	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	match _current_kind:
		"mina_gemas":
			_render_gem_mine(core)
		"campo_entrenamiento":
			_render_training_camp(core)
		"guarderia_crias":
			_render_nursery(core)
		"granja_comida":
			_render_food_farm(core)
		_:
			lbl_titulo.text = "Estructura"
			lbl_detalle.text = ""


func _render_gem_mine(core: Node) -> void:
	lbl_titulo.text = "💎 Mina de Gemas — Isla %d" % _current_island_id
	var mines: Dictionary = core.player_state.get("minas_gemas", {})
	var key: String = str(_current_island_id)
	var built: bool = mines.has(key) and bool(mines[key].get("construida", false))
	var total_built: int = mines.size()

	if not built:
		lbl_detalle.text = "Construye una Mina de Gemas en esta isla (máx. 1 por isla, %d/5 construidas).\nCosto: 10 Gemas • Produce 1 Gema cada 24 horas." % total_built
		_add_action_button("Construir Mina de Gemas (10 💎)", func() -> void:
			var r: Dictionary = core.build_gem_mine_on_island(_current_island_id)
			status_message.emit(str(r.get("msg", "")))
			if r.get("ok", false):
				var am: Node = get_node_or_null("/root/AudioManager")
				if am and am.has_method("play_sfx"):
					am.call("play_sfx", "coin")
			_refresh()
		)
	else:
		var m: Dictionary = mines[key]
		var ready_flag: bool = bool(m.get("lista", false)) or float(m.get("restante_seg", 1.0)) <= 0.0
		var rem_s: int = int(ceil(float(m.get("restante_seg", 0.0))))
		lbl_detalle.text = ("✨ ¡1 Gema lista para recoger!" if ready_flag else "Produciendo 1 Gema... Faltan %dh %02dm %02ds." % [rem_s / 3600, (rem_s % 3600) / 60, rem_s % 60]) + "\nTotal Minas activas: %d/5 (hasta %d Gemas/día)." % [total_built, total_built]
		var btn: Button = _add_action_button("Recoger +1 Gema 💎", func() -> void:
			var r: Dictionary = core.collect_gem_mine(_current_island_id)
			status_message.emit(str(r.get("msg", "")))
			if r.get("ok", false):
				var am: Node = get_node_or_null("/root/AudioManager")
				if am and am.has_method("play_sfx"):
					am.call("play_sfx", "coin")
			_refresh()
		)
		btn.disabled = not ready_flag


func _render_training_camp(core: Node) -> void:
	lbl_titulo.text = "⚔ Campo de Entrenamiento"
	var tr: Dictionary = core.player_state.get("entrenamiento", {})
	if bool(tr.get("activo", false)):
		var uid: int = int(tr.get("dragon_uid", -1))
		var d: Dictionary = core.get_dragon_by_uid(uid)
		var sp: Dictionary = core.get_species(int(d.get("especie_id", 1)))
		var rem: int = int(ceil(float(tr.get("restante_seg", 0.0))))
		lbl_detalle.text = "Entrenando a %s (+10%% stats de combate).\nTiempo restante: %02d:%02d." % [str(sp.get("nombre", "Dragón")), rem / 60, rem % 60]
		_add_action_button("Acelerar entrenamiento (3 💎)", func() -> void:
			var r: Dictionary = core.speedup_training_with_gems(3)
			status_message.emit(str(r.get("msg", "")))
			if r.get("ok", false):
				_play_sfx("level_up")
			_refresh()
		)
	else:
		lbl_detalle.text = "Selecciona un dragón para entrenar (300 Oro • 5 min) y aumentar permanentemente +10%% sus estadísticas de combate."
		for d_var: Variant in core.player_state.get("dragones", []):
			if d_var is Dictionary:
				var d: Dictionary = d_var
				var uid: int = int(d.get("uid", -1))
				var sp_id: int = int(d.get("especie_id", 1))
				var sp: Dictionary = core.get_species(sp_id)
				var t_lvl: int = int(d.get("entrenamiento_nivel", 0))
				var etapa: String = str(d.get("etapa", "cria"))
				_add_dragon_action_row(
					sp_id,
					etapa,
					"Entrenar %s (Rango +%d) — 300 Oro" % [str(sp.get("nombre", "Dragón")), t_lvl],
					func() -> void:
						var r: Dictionary = core.start_training(uid, 300, 300)
						status_message.emit(str(r.get("msg", "")))
						if r.get("ok", false):
							_play_sfx("click")
						_refresh()
				)


func _render_nursery(core: Node) -> void:
	var guarderia: Array = core.player_state.get("guarderia", [])
	lbl_titulo.text = "🐣 Guardería de Crías (%d / 4)" % guarderia.size()
	lbl_detalle.text = "Guarda hasta 4 dragoncitos pequeños cuando no tengas espacio libre en tus hábitats."

	if guarderia.is_empty():
		var lbl_empty: Label = Label.new()
		lbl_empty.text = "No hay crías en la Guardería actualmente."
		box_acciones.add_child(lbl_empty)
	else:
		for i: int in range(guarderia.size()):
			var d_var: Variant = guarderia[i]
			if d_var is Dictionary:
				var sp_id: int = int(d_var.get("especie_id", 1))
				var sp: Dictionary = core.get_species(sp_id)
				var etapa: String = str(d_var.get("etapa", "cria"))
				var idx: int = i
				_add_dragon_action_row(
					sp_id,
					etapa,
					"Retirar %s (Niv.%d)" % [str(sp.get("nombre", "Cría")), int(d_var.get("nivel", 1))],
					func() -> void:
						var r: Dictionary = core.retrieve_dragon_from_nursery(idx)
						status_message.emit(str(r.get("msg", "")))
						if r.get("ok", false):
							_play_sfx("hatch")
							nursery_dragon_retrieved.emit(r.get("dragon", {}))
						_refresh()
				)

	if guarderia.size() < 4:
		var dragones: Array = core.player_state.get("dragones", [])
		if dragones.size() > 1:
			var last_d: Dictionary = dragones[dragones.size() - 1]
			var sp_id: int = int(last_d.get("especie_id", 1))
			var sp_last: Dictionary = core.get_species(sp_id)
			_add_dragon_action_row(
				sp_id,
				str(last_d.get("etapa", "cria")),
				"Enviar %s a Guardería" % str(sp_last.get("nombre", "Cría")),
				func() -> void:
					var r: Dictionary = core.store_dragon_in_nursery(last_d)
					if r.get("ok", false):
						dragones.pop_back()
						core.player_state["dragones"] = dragones
						core.save_game()
						_play_sfx("click")
						nursery_dragon_stored.emit(int(last_d.get("uid", -1)))
					status_message.emit(str(r.get("msg", "")))
					_refresh()
			)


func _render_food_farm(core: Node) -> void:
	lbl_titulo.text = "🍎 Granja de Comida"
	var granjas: Array = core.player_state.get("granjas_comida", [])
	var g: Dictionary = granjas[0] if not granjas.is_empty() else {}
	if bool(g.get("produciendo", false)):
		var rem: int = int(ceil(float(g.get("restante_seg", 0.0))))
		lbl_detalle.text = "Cosecha en progreso: +%d Comida (%02d:%02d restantes)." % [int(g.get("cantidad", 180)), rem / 60, rem % 60]
		_add_action_button("Acelerar cosecha (2 💎)", func() -> void:
			var r: Dictionary = core.speedup_food_farm(2)
			status_message.emit(str(r.get("msg", "")))
			if r.get("ok", false):
				_play_sfx("coin")
			_refresh()
		)
	else:
		lbl_detalle.text = "Produce Comida por tiempo para subir de nivel a tus dragones."
		_add_action_button("Sembrar Fruta (+180 Comida • 2 min • 200 Oro)", func() -> void:
			var r: Dictionary = core.start_food_production(200, 180, 120)
			status_message.emit(str(r.get("msg", "")))
			if r.get("ok", false):
				_play_sfx("click")
			_refresh()
		)


func _add_dragon_action_row(sp_id: int, etapa: String, btn_text: String, cb: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon: TextureRect = TextureRect.new()
	icon.texture = Dragon2D.build_dragon_texture(sp_id, etapa)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var btn: Button = Button.new()
	btn.text = btn_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(cb)
	row.add_child(btn)
	box_acciones.add_child(row)


func _add_action_button(text: String, cb: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(cb)
	box_acciones.add_child(btn)
	return btn
