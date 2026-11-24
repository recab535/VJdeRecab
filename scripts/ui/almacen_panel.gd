extends Control

## Panel UI del Almacén:
## - Estructuras: 5 espacios iniciales (ampliables con Gemas), permite guardar/colocar Tótems.
## - Baldosas de Suelo: almacenamiento infinito de diseños comprados con Oro.

signal status_message(msg: String)
signal place_tile_requested(tile_id: String, tile_color: Color)

const TILE_COLORS: Dictionary = {
	"piedra_real": Color(0.76, 0.78, 0.84, 1.0),
	"mosaico_dorado": Color(0.95, 0.82, 0.32, 1.0),
	"jardin_esmeralda": Color(0.26, 0.82, 0.44, 1.0),
	"obsidiana_real": Color(0.28, 0.22, 0.38, 1.0)
}

@onready var lbl_capacidad: Label = %LblAlmCapacidad
@onready var btn_ampliar: Button = %BtnAmpliarAlm
@onready var btn_cerrar: Button = %BtnCerrarAlm
@onready var list_estructuras: VBoxContainer = %ListAlmEstructuras
@onready var list_activos: VBoxContainer = %ListTotemsActivos
@onready var list_baldosas: VBoxContainer = %ListAlmBaldosas


func _ready() -> void:
	visible = false
	if btn_cerrar:
		btn_cerrar.pressed.connect(func() -> void: visible = false)
	if btn_ampliar:
		btn_ampliar.pressed.connect(_on_expand_pressed)


func open_almacen() -> void:
	refresh()
	visible = true
	scale = Vector2(0.95, 0.95)
	modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.12)


func refresh() -> void:
	for c: Node in list_estructuras.get_children():
		c.queue_free()
	for c: Node in list_activos.get_children():
		c.queue_free()
	for c: Node in list_baldosas.get_children():
		c.queue_free()

	var core: Node = get_node_or_null("/root/GameCore")
	if core == null:
		return

	var alm: Dictionary = core.player_state.get("almacen", {"capacidad_estructuras": 5, "estructuras": [], "baldosas": {}})
	var cap: int = int(alm.get("capacidad_estructuras", 5))
	var ests: Array = alm.get("estructuras", [])
	lbl_capacidad.text = "Estructuras guardadas: %d / %d  |  Suelos: ∞" % [ests.size(), cap]

	if ests.is_empty():
		var l: Label = Label.new()
		l.text = "No tienes estructuras guardadas en el Almacén."
		list_estructuras.add_child(l)
	else:
		for i: int in range(ests.size()):
			var item: Dictionary = ests[i]
			var row: HBoxContainer = HBoxContainer.new()
			var lbl: Label = Label.new()
			lbl.text = str(item.get("nombre", "Estructura"))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var btn: Button = Button.new()
			btn.text = "Colocar en Isla"
			var idx: int = i
			btn.pressed.connect(func() -> void:
				var r: Dictionary = core.deploy_structure_from_warehouse(idx)
				status_message.emit(str(r.get("msg", "")))
				refresh()
			)
			row.add_child(lbl)
			row.add_child(btn)
			list_estructuras.add_child(row)

	var placed: Array = core.player_state.get("potenciadores_colocados", [])
	if placed.is_empty():
		var l2: Label = Label.new()
		l2.text = "Sin Tótems Potenciadores activos en islas."
		list_activos.add_child(l2)
	else:
		for raw_id: Variant in placed:
			var eid: int = int(raw_id)
			var ename: String = str(core.get_element(eid).get("nombre", "Elem %d" % eid))
			var row: HBoxContainer = HBoxContainer.new()
			var lbl: Label = Label.new()
			lbl.text = "Tótem %s (ACTIVO ×2 / ×3)" % ename
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var btn: Button = Button.new()
			btn.text = "Guardar (desactiva bono)"
			btn.pressed.connect(func() -> void:
				var r: Dictionary = core.store_booster_in_warehouse(eid)
				status_message.emit(str(r.get("msg", "")))
				refresh()
			)
			row.add_child(lbl)
			row.add_child(btn)
			list_activos.add_child(row)

	var baldosas: Dictionary = alm.get("baldosas", {})
	if baldosas.is_empty():
		var l3: Label = Label.new()
		l3.text = "No has comprado diseños de suelo aún (visita Tienda -> Decoración de Suelo)."
		list_baldosas.add_child(l3)
	else:
		for tid: Variant in baldosas.keys():
			var key: String = str(tid)
			var qty: int = int(baldosas[key])
			var row: HBoxContainer = HBoxContainer.new()
			var lbl: Label = Label.new()
			lbl.text = "%s — Cantidad: %d (∞ capacidad)" % [key.replace("_", " ").capitalize(), qty]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var btn: Button = Button.new()
			btn.text = "Decorar Isla"
			btn.pressed.connect(func() -> void:
				place_tile_requested.emit(key, TILE_COLORS.get(key, Color(0.8, 0.8, 0.8)))
				status_message.emit("Baldosa '%s' colocada en la isla actual." % key.replace("_", " ").capitalize())
			)
			row.add_child(lbl)
			row.add_child(btn)
			list_baldosas.add_child(row)


func _on_expand_pressed() -> void:
	var core: Node = get_node_or_null("/root/GameCore")
	if core:
		var r: Dictionary = core.expand_warehouse_slots(15)
		status_message.emit(str(r.get("msg", "")))
		refresh()
