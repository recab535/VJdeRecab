extends Node3D

## Obstáculo temporizado en una isla (6 tipos oficiales).
## Puede limpiarse con Oro esperando su temporizador o acelerarse con Gemas.

signal obstacle_clicked(obstacle_node: Node3D)

const OBSTACLE_CATALOG: Dictionary = {
	"arbusto": {"nombre": "Arbusto", "duracion_seg": 600, "costo_oro": 150, "gemas_acelerar": 2, "exp": 20},
	"arbol_pequeno": {"nombre": "Árbol pequeño", "duracion_seg": 2700, "costo_oro": 350, "gemas_acelerar": 4, "exp": 45},
	"piedrita": {"nombre": "Piedrita", "duracion_seg": 3600, "costo_oro": 500, "gemas_acelerar": 5, "exp": 60},
	"arbol_grande": {"nombre": "Árbol grande", "duracion_seg": 10800, "costo_oro": 1200, "gemas_acelerar": 10, "exp": 120},
	"piedra_mediana": {"nombre": "Piedra mediana", "duracion_seg": 14400, "costo_oro": 1800, "gemas_acelerar": 14, "exp": 160},
	"roca_enorme": {"nombre": "Roca enorme", "duracion_seg": 28800, "costo_oro": 3200, "gemas_acelerar": 22, "exp": 260}
}

@export var obstacle_id: String = ""
@export var island_id: int = 1
@export var parcel_index: int = 0
@export var obstacle_type: String = "arbusto"

@onready var visual_root: Node3D = $VisualRoot
@onready var label_3d: Label3D = $Label3D
@onready var area_click: Area3D = $AreaClick

var limpiando: bool = false
var restante_seg: float = 600.0
var duracion_seg: int = 600


func _ready() -> void:
	if area_click:
		area_click.input_event.connect(_on_area_input_event)
	_build_visual()
	_refresh_label()


func configure(data: Dictionary) -> void:
	obstacle_id = str(data.get("id", ""))
	island_id = int(data.get("island_id", 1))
	parcel_index = int(data.get("parcela", 0))
	obstacle_type = str(data.get("tipo", "arbusto"))
	limpiando = bool(data.get("limpiando", false))
	var spec: Dictionary = OBSTACLE_CATALOG.get(obstacle_type, OBSTACLE_CATALOG["arbusto"])
	duracion_seg = int(data.get("duracion_seg", spec["duracion_seg"]))
	restante_seg = float(data.get("restante_seg", duracion_seg))
	if is_node_ready():
		_build_visual()
		_refresh_label()


func sync_state(data: Dictionary) -> void:
	if bool(data.get("limpiado", false)):
		queue_free()
		return
	limpiando = bool(data.get("limpiando", false))
	restante_seg = maxf(0.0, float(data.get("restante_seg", restante_seg)))
	_refresh_label()


func _refresh_label() -> void:
	if label_3d == null:
		return
	var spec: Dictionary = OBSTACLE_CATALOG.get(obstacle_type, OBSTACLE_CATALOG["arbusto"])
	if limpiando:
		label_3d.text = "%s\nLimpiando %s" % [str(spec["nombre"]), _format_time(int(ceil(restante_seg)))]
		label_3d.modulate = Color(1.0, 0.88, 0.35, 1.0)
	else:
		label_3d.text = str(spec["nombre"])
		label_3d.modulate = Color(0.95, 0.96, 1.0, 0.92)


func _build_visual() -> void:
	if visual_root == null:
		return
	for c: Node in visual_root.get_children():
		c.queue_free()

	match obstacle_type:
		"arbusto":
			_add_sphere(Vector3(0, 0.28, 0), 0.38, Color(0.2, 0.65, 0.24))
			_add_sphere(Vector3(0.24, 0.22, 0.12), 0.26, Color(0.24, 0.72, 0.28))
		"arbol_pequeno":
			_add_cylinder(Vector3(0, 0.28, 0), 0.1, 0.14, 0.56, Color(0.45, 0.28, 0.15))
			_add_cylinder(Vector3(0, 0.78, 0), 0.04, 0.48, 0.75, Color(0.18, 0.62, 0.26))
		"piedrita":
			_add_sphere(Vector3(0, 0.2, 0), 0.3, Color(0.55, 0.58, 0.62))
		"arbol_grande":
			_add_cylinder(Vector3(0, 0.45, 0), 0.16, 0.24, 0.9, Color(0.42, 0.25, 0.14))
			_add_cylinder(Vector3(0, 1.2, 0), 0.06, 0.78, 1.15, Color(0.14, 0.54, 0.22))
			_add_cylinder(Vector3(0, 1.75, 0), 0.04, 0.55, 0.75, Color(0.2, 0.66, 0.28))
		"piedra_mediana":
			_add_sphere(Vector3(0, 0.34, 0), 0.52, Color(0.48, 0.5, 0.56))
			_add_sphere(Vector3(-0.32, 0.22, 0.18), 0.3, Color(0.42, 0.44, 0.5))
		"roca_enorme":
			_add_sphere(Vector3(0, 0.55, 0), 0.85, Color(0.38, 0.4, 0.46))
			_add_sphere(Vector3(0.45, 0.35, -0.25), 0.5, Color(0.32, 0.34, 0.4))
		_:
			_add_sphere(Vector3(0, 0.3, 0), 0.35, Color(0.4, 0.6, 0.3))


func _add_sphere(pos: Vector3, radius: float, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 1.65
	sm.radial_segments = 7
	sm.rings = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	sm.material = mat
	mi.mesh = sm
	mi.position = pos
	visual_root.add_child(mi)


func _add_cylinder(pos: Vector3, top_r: float, bot_r: float, h: float, color: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 6
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	visual_root.add_child(mi)


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		obstacle_clicked.emit(self)


static func _format_time(sec: int) -> String:
	var h: int = sec / 3600
	var m: int = (sec % 3600) / 60
	var s: int = sec % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	return "%02d:%02d" % [m, s]
