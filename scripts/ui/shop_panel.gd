extends PanelContainer
class_name ShopPanel

## Tienda modal con pestañas: Hábitats por elemento, Huevos y Granja de Comida.

signal habitat_purchase_requested(elemento_id: int, cost_oro: int, nombre: String)
signal egg_purchase_requested(especie_id: int, cost_oro: int)
signal farm_purchase_requested(cost_oro: int)

const ELEMENT_COLORS: Dictionary = {
	1: Color(0.66, 0.44, 0.24, 1.0),
	2: Color(0.92, 0.34, 0.18, 1.0),
	3: Color(0.22, 0.62, 0.94, 1.0),
	4: Color(0.28, 0.78, 0.36, 1.0),
	5: Color(0.95, 0.82, 0.22, 1.0),
	6: Color(0.56, 0.88, 0.98, 1.0)
}

const HABITAT_ITEMS: Array[Dictionary] = [
	{"elemento_id": 1, "nombre": "Hábitat Tierra", "costo": 250},
	{"elemento_id": 2, "nombre": "Hábitat Fuego", "costo": 350},
	{"elemento_id": 3, "nombre": "Hábitat Agua", "costo": 450},
	{"elemento_id": 4, "nombre": "Hábitat Planta", "costo": 550},
	{"elemento_id": 5, "nombre": "Hábitat Eléctrico", "costo": 750},
	{"elemento_id": 6, "nombre": "Hábitat Hielo", "costo": 900}
]

const EGG_ITEMS: Array[Dictionary] = [
	{"especie_id": 1, "nombre": "Huevo Terracota", "elemento_id": 1, "costo": 400},
	{"especie_id": 2, "nombre": "Huevo Ascua", "elemento_id": 2, "costo": 500},
	{"especie_id": 3, "nombre": "Huevo Marea", "elemento_id": 3, "costo": 650},
	{"especie_id": 4, "nombre": "Huevo Brote", "elemento_id": 4, "costo": 800}
]

@onready var grid_habitats: GridContainer = %GridHabitats
@onready var grid_huevos: GridContainer = %GridHuevos
@onready var btn_comprar_granja: Button = %BtnComprarGranja
@onready var btn_cerrar_tienda: Button = %BtnCerrarTienda

var _current_oro: int = 0


func _ready() -> void:
	visible = false
	if btn_cerrar_tienda:
		btn_cerrar_tienda.pressed.connect(func() -> void: visible = false)
	if btn_comprar_granja:
		btn_comprar_granja.pressed.connect(func() -> void:
			visible = false
			farm_purchase_requested.emit(300)
		)


func open_shop(current_oro: int) -> void:
	_current_oro = current_oro
	_populate_habitats()
	_populate_eggs()
	if btn_comprar_granja:
		btn_comprar_granja.disabled = _current_oro < 300
	visible = true


func _populate_habitats() -> void:
	for c: Node in grid_habitats.get_children():
		c.queue_free()

	for item: Dictionary in HABITAT_ITEMS:
		var elem_id: int = int(item["elemento_id"])
		var cost: int = int(item["costo"])
		var title: String = str(item["nombre"])
		var card: PanelContainer = _build_card(title, ELEMENT_COLORS.get(elem_id, Color.WHITE), "%d Oro" % cost, _current_oro >= cost)
		var btn: Button = card.get_meta("buy_btn") as Button
		btn.pressed.connect(func() -> void:
			visible = false
			habitat_purchase_requested.emit(elem_id, cost, title)
		)
		grid_habitats.add_child(card)


func _populate_eggs() -> void:
	for c: Node in grid_huevos.get_children():
		c.queue_free()

	for item: Dictionary in EGG_ITEMS:
		var sp_id: int = int(item["especie_id"])
		var elem_id: int = int(item["elemento_id"])
		var cost: int = int(item["costo"])
		var title: String = str(item["nombre"])
		var card: PanelContainer = _build_card(title, ELEMENT_COLORS.get(elem_id, Color.WHITE), "%d Oro" % cost, _current_oro >= cost)
		var btn: Button = card.get_meta("buy_btn") as Button
		btn.pressed.connect(func() -> void:
			visible = false
			egg_purchase_requested.emit(sp_id, cost)
		)
		grid_huevos.add_child(card)


func _build_card(title: String, badge_color: Color, price_text: String, can_afford: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 145)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var badge: ColorRect = ColorRect.new()
	badge.custom_minimum_size = Vector2(0, 16)
	badge.color = badge_color
	vbox.add_child(badge)

	var lbl_title: Label = Label.new()
	lbl_title.text = title
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_title)

	var btn: Button = Button.new()
	btn.text = "Comprar (%s)" % price_text
	btn.disabled = not can_afford
	btn.custom_minimum_size = Vector2(0, 42)
	vbox.add_child(btn)

	card.set_meta("buy_btn", btn)
	return card
