extends Control

## Tienda Definitiva por 5 pestañas:
## 1) Hábitats  2) Estructuras Especiales  3) Potenciadores Elementales (8)
## 4) Decoración de Suelo  5) Paquetes (Gemas / Oro / Comida)

signal habitat_purchase_requested(elemento_id: int, cost_oro: int, nombre: String)
signal status_message(msg: String)

const ELEMENT_COLORS: Dictionary = {
	1: Color(0.66, 0.44, 0.24, 1.0),
	2: Color(0.92, 0.34, 0.18, 1.0),
	3: Color(0.22, 0.62, 0.94, 1.0),
	4: Color(0.28, 0.78, 0.36, 1.0),
	5: Color(0.95, 0.82, 0.22, 1.0),
	6: Color(0.56, 0.88, 0.98, 1.0),
	7: Color(0.64, 0.68, 0.74, 1.0),
	8: Color(0.38, 0.24, 0.52, 1.0)
}

const HABITAT_ITEMS: Array[Dictionary] = [
	{"elemento_id": 1, "nombre": "Hábitat Tierra", "costo": 250},
	{"elemento_id": 2, "nombre": "Hábitat Fuego", "costo": 350},
	{"elemento_id": 3, "nombre": "Hábitat Agua", "costo": 450},
	{"elemento_id": 4, "nombre": "Hábitat Planta", "costo": 550},
	{"elemento_id": 5, "nombre": "Hábitat Eléctrico", "costo": 750},
	{"elemento_id": 6, "nombre": "Hábitat Hielo", "costo": 900},
	{"elemento_id": 7, "nombre": "Hábitat Metal", "costo": 1200},
	{"elemento_id": 8, "nombre": "Hábitat Oscuro", "costo": 1500}
]

const BOOSTER_ITEMS: Array[Dictionary] = [
	{"elemento_id": 1, "nombre": "Tótem Tierra", "costo": 15000},
	{"elemento_id": 2, "nombre": "Tótem Fuego", "costo": 18000},
	{"elemento_id": 3, "nombre": "Tótem Agua", "costo": 22000},
	{"elemento_id": 4, "nombre": "Tótem Planta", "costo": 26000},
	{"elemento_id": 5, "nombre": "Tótem Eléctrico", "costo": 32000},
	{"elemento_id": 6, "nombre": "Tótem Hielo", "costo": 38000},
	{"elemento_id": 7, "nombre": "Tótem Metal", "costo": 48000},
	{"elemento_id": 8, "nombre": "Tótem Oscuro", "costo": 60000}
]

const TILE_ITEMS: Array[Dictionary] = [
	{"id": "piedra_real", "nombre": "Baldosa Piedra Real", "costo": 120, "color": Color(0.76, 0.78, 0.84)},
	{"id": "jardin_esmeralda", "nombre": "Baldosa Jardín Esmeralda", "costo": 180, "color": Color(0.26, 0.82, 0.44)},
	{"id": "mosaico_dorado", "nombre": "Baldosa Mosaico Dorado", "costo": 250, "color": Color(0.95, 0.82, 0.32)},
	{"id": "obsidiana_real", "nombre": "Baldosa Obsidiana Real", "costo": 300, "color": Color(0.28, 0.22, 0.38)}
]

const PACK_ITEMS: Array[Dictionary] = [
	{"nombre": "Bolsa de Oro (Demo)", "desc": "+2500 Oro", "oro": 2500, "comida": 0, "gemas": 0, "color": Color(0.95, 0.8, 0.25)},
	{"nombre": "Cosecha Real (Demo)", "desc": "+1000 Comida", "oro": 0, "comida": 1000, "gemas": 0, "color": Color(0.32, 0.85, 0.42)},
	{"nombre": "Cofre de Gemas (Demo)", "desc": "+25 Gemas", "oro": 0, "comida": 0, "gemas": 25, "color": Color(0.28, 0.82, 1.0)},
	{"nombre": "Pack Fundador Steam", "desc": "+20000 Oro, +2500 Comida, +50 Gemas", "oro": 20000, "comida": 2500, "gemas": 50, "color": Color(0.84, 0.42, 0.96)}
]

@onready var grid_habitats: GridContainer = %GridHabitats
@onready var grid_especiales: GridContainer = %GridEspeciales
@onready var grid_potenciadores: GridContainer = %GridPotenciadores
@onready var grid_suelos: GridContainer = %GridSuelos
@onready var grid_paquetes: GridContainer = %GridPaquetes
@onready var btn_cerrar: Button = %BtnCerrarTienda

var _focused_island_id: int = 1


func _ready() -> void:
	visible = false
	if btn_cerrar:
		btn_cerrar.pressed.connect(func() -> void: visible = false)


func _play_sfx(kind: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.call("play_sfx", kind)


func open_shop(_oro: int = 0, focused_island_id: int = 1) -> void:
	_focused_island_id = focused_island_id
	_refresh_all()
	visible = true
	pivot_offset = size * 0.5
	scale = Vector2(0.95, 0.95)
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)


func _refresh_all() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return
	var res: Dictionary = core.get_resources()
	var oro: int = int(res.get("oro", 0))
	var gemas: int = int(res.get("gemas", 0))

	_populate_habitats(oro)
	_populate_especiales(core, oro, gemas)
	_populate_potenciadores(core, oro)
	_populate_suelos(core, oro)
	_populate_paquetes(core)


func _clear_grid(g: GridContainer) -> void:
	for c: Node in g.get_children():
		c.queue_free()


func _populate_habitats(oro: int) -> void:
	_clear_grid(grid_habitats)
	for item: Dictionary in HABITAT_ITEMS:
		var eid: int = int(item["elemento_id"])
		var cost: int = int(item["costo"])
		var title: String = str(item["nombre"])
		var card: PanelContainer = _build_card(title, "Capacidad: 2 dragones", ELEMENT_COLORS.get(eid, Color.WHITE), "Colocar (%d Oro)" % cost, oro >= cost)
		var btn: Button = card.get_meta("btn") as Button
		btn.pressed.connect(func() -> void:
			visible = false
			habitat_purchase_requested.emit(eid, cost, title)
		)
		grid_habitats.add_child(card)


func _populate_especiales(core: Node, oro: int, gemas: int) -> void:
	_clear_grid(grid_especiales)

	# 1. Segundo Adoratorio (20 Gemas)
	var has_second: bool = bool(core.player_state.get("segundo_adoratorio", false))
	var c1: PanelContainer = _build_card("Segundo Adoratorio", "Cría simultánea extra", Color(0.84, 0.36, 0.94), "Desbloqueado" if has_second else "20 Gemas", not has_second and gemas >= 20)
	(c1.get_meta("btn") as Button).pressed.connect(func() -> void:
		var r: Dictionary = core.unlock_second_adoratorio()
		if r.get("ok", false):
			_play_sfx("coin")
		status_message.emit(str(r.get("msg", "")))
		_refresh_all()
	)
	grid_especiales.add_child(c1)

	# 2. Mina de Gemas en Isla actual (10 Gemas, 1/isla)
	var mines: Dictionary = core.player_state.get("minas_gemas", {})
	var mine_built: bool = mines.has(str(_focused_island_id))
	var c2: PanelContainer = _build_card("Mina Gemas (Isla %d)" % _focused_island_id, "1 Gema / 24h (máx 1/isla)", Color(0.24, 0.88, 1.0), "Construida" if mine_built else "10 Gemas", not mine_built and gemas >= 10)
	(c2.get_meta("btn") as Button).pressed.connect(func() -> void:
		var r: Dictionary = core.build_gem_mine_on_island(_focused_island_id)
		if r.get("ok", false):
			_play_sfx("coin")
		status_message.emit(str(r.get("msg", "")))
		_refresh_all()
	)
	grid_especiales.add_child(c2)

	# 3. Mejora Torre Nido (10 / 15 / 20 Gemas)
	var nest_cost: int = core.get_next_nest_upgrade_cost()
	var cur_slots: int = core.get_nest_max_slots()
	var c3: PanelContainer = _build_card("Mejorar Torre Nido", "Ranuras actuales: %d/4" % cur_slots, Color(0.95, 0.78, 0.34), "Máximo" if nest_cost < 0 else ("%d Gemas" % nest_cost), nest_cost > 0 and gemas >= nest_cost)
	(c3.get_meta("btn") as Button).pressed.connect(func() -> void:
		var r: Dictionary = core.upgrade_nest_tower()
		if r.get("ok", false):
			_play_sfx("coin")
		status_message.emit(str(r.get("msg", "")))
		_refresh_all()
	)
	grid_especiales.add_child(c3)

	# 4. Granja de Comida
	var c4: PanelContainer = _build_card("Granja de Comida", "Sembrar +180 Comida (2m)", Color(0.34, 0.84, 0.38), "200 Oro", oro >= 200)
	(c4.get_meta("btn") as Button).pressed.connect(func() -> void:
		var r: Dictionary = core.start_food_production(200, 180, 120)
		if r.get("ok", false):
			_play_sfx("coin")
		status_message.emit(str(r.get("msg", "")))
		_refresh_all()
	)
	grid_especiales.add_child(c4)

	# 5. Templos de Nivel (Desbloquean Nv.15 / 20 / 25 / 30)
	var next_t: Dictionary = core.get_next_level_temple()
	var cur_cap: int = core.get_current_dragon_level_cap()
	if next_t.is_empty():
		var c5_max: PanelContainer = _build_card("Templos de Nivel", "Tope máximo Nv.30 desbloqueado", Color(0.95, 0.78, 0.30), "Completado", false)
		grid_especiales.add_child(c5_max)
	else:
		var t_tier: int = int(next_t["tier"])
		var t_cost: int = int(next_t["costo_oro"])
		var t_lvl: int = int(next_t["nivel_jugador_req"])
		var t_cap: int = int(next_t["nivel_cap"])
		var can_t: bool = oro >= t_cost and core.get_player_level() >= t_lvl
		var c5: PanelContainer = _build_card(
			str(next_t["nombre"]),
			"Tope dragones: Nv.%d → Nv.%d\nRequiere Domador Nv.%d" % [cur_cap, t_cap, t_lvl],
			Color(0.95, 0.78, 0.30),
			"%d Oro" % t_cost,
			can_t
		)
		(c5.get_meta("btn") as Button).pressed.connect(func() -> void:
			var r: Dictionary = core.unlock_level_temple(t_tier)
			if r.get("ok", false):
				_play_sfx("level_up")
			status_message.emit(str(r.get("msg", "")))
			_refresh_all()
		)
		grid_especiales.add_child(c5)


func _populate_potenciadores(core: Node, oro: int) -> void:
	_clear_grid(grid_potenciadores)
	var placed: Array = core.player_state.get("potenciadores_colocados", [])
	for item: Dictionary in BOOSTER_ITEMS:
		var eid: int = int(item["elemento_id"])
		var cost: int = int(item["costo"])
		var title: String = str(item["nombre"])
		var active: bool = placed.has(eid)
		var stored: bool = core.has_method("is_booster_in_warehouse") and core.is_booster_in_warehouse(eid)
		var btn_label: String = "ACTIVO (+20%/+35%)" if active else ("EN ALMACÉN" if stored else ("%d Oro" % cost))
		var can_buy: bool = not active and not stored and oro >= cost
		var card: PanelContainer = _build_card(title, "+20% (1 elem.) • +35% (híbrido)\nExcluye Legendarios", ELEMENT_COLORS.get(eid, Color.WHITE), btn_label, can_buy)
		(card.get_meta("btn") as Button).pressed.connect(func() -> void:
			var r: Dictionary = core.buy_elemental_booster(eid, cost)
			if r.get("ok", false):
				_play_sfx("coin")
			status_message.emit(str(r.get("msg", "")))
			_refresh_all()
		)
		grid_potenciadores.add_child(card)


func _populate_suelos(core: Node, oro: int) -> void:
	_clear_grid(grid_suelos)
	for item: Dictionary in TILE_ITEMS:
		var tid: String = str(item["id"])
		var title: String = str(item["nombre"])
		var cost: int = int(item["costo"])
		var card: PanelContainer = _build_card(title, "Almacén infinito de suelos", item["color"], "%d Oro" % cost, oro >= cost)
		(card.get_meta("btn") as Button).pressed.connect(func() -> void:
			var r: Dictionary = core.buy_floor_tile(tid, title, cost)
			if r.get("ok", false):
				_play_sfx("coin")
			status_message.emit(str(r.get("msg", "")))
			_refresh_all()
		)
		grid_suelos.add_child(card)


func _populate_paquetes(core: Node) -> void:
	_clear_grid(grid_paquetes)
	for item: Dictionary in PACK_ITEMS:
		var title: String = str(item["nombre"])
		var card: PanelContainer = _build_card(title, str(item["desc"]), item["color"], "Reclamar (Demo)", true)
		(card.get_meta("btn") as Button).pressed.connect(func() -> void:
			var r: Dictionary = core.grant_demo_package(int(item["oro"]), int(item["comida"]), int(item["gemas"]), title)
			if r.get("ok", false):
				_play_sfx("coin")
			status_message.emit(str(r.get("msg", "")))
			_refresh_all()
		)
		grid_paquetes.add_child(card)


func _build_card(title: String, desc: String, badge_color: Color, btn_text: String, enabled: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(236, 152)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var badge: ColorRect = ColorRect.new()
	badge.custom_minimum_size = Vector2(0, 14)
	badge.color = badge_color
	vbox.add_child(badge)

	var l_title: Label = Label.new()
	l_title.text = title
	l_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(l_title)

	var l_desc: Label = Label.new()
	l_desc.text = desc
	l_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	l_desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(l_desc)

	var btn: Button = Button.new()
	btn.text = btn_text
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(btn)

	card.set_meta("btn", btn)
	return card
