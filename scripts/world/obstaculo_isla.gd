extends Node3D

## Obstáculo temporizado en una isla (6 tipos oficiales) con estética 2.5D estilizada.
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
var _sway_time: float = 0.0
var _work_ring: MeshInstance3D = null


func _ready() -> void:
	_sway_time = float(obstacle_id.hash() % 100) * 0.1
	if area_click:
		area_click.input_event.connect(_on_area_input_event)
	_build_visual()
	_refresh_label()


func _process(delta: float) -> void:
	_sway_time += delta * 2.2
	if visual_root and obstacle_type in ["arbusto", "arbol_pequeno", "arbol_grande"]:
		visual_root.rotation.z = sin(_sway_time) * 0.035
	if limpiando:
		restante_seg = maxf(0.0, restante_seg - delta)
		if _work_ring and is_instance_valid(_work_ring):
			_work_ring.visible = true
			_work_ring.rotation.y += delta * 1.8
			var s: float = 1.0 + sin(_sway_time * 2.0) * 0.08
			_work_ring.scale = Vector3(s, 1.0, s)
		_refresh_label()
	elif _work_ring and is_instance_valid(_work_ring):
		_work_ring.visible = false


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
		label_3d.text = "⛏ %s\n%s (⚡%d Gemas)" % [
			str(spec["nombre"]),
			_format_time(int(ceil(restante_seg))),
			int(spec["gemas_acelerar"])
		]
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
			_add_sphere(Vector3(0.0, 0.28, 0.0), 0.38, Color(0.20, 0.68, 0.24))
			_add_sphere(Vector3(0.26, 0.22, 0.14), 0.27, Color(0.26, 0.76, 0.30))
			_add_sphere(Vector3(-0.22, 0.24, -0.10), 0.24, Color(0.16, 0.58, 0.22))
			_add_sphere(Vector3(0.08, 0.48, 0.16), 0.07, Color(1.0, 0.42, 0.58), 0.25)
			_add_sphere(Vector3(-0.14, 0.40, 0.18), 0.06, Color(1.0, 0.86, 0.32), 0.25)
		"arbol_pequeno":
			_add_cylinder(Vector3(0.0, 0.30, 0.0), 0.10, 0.16, 0.62, Color(0.46, 0.28, 0.16))
			_add_cylinder(Vector3(0.0, 0.76, 0.0), 0.05, 0.52, 0.72, Color(0.16, 0.60, 0.24))
			_add_cylinder(Vector3(0.0, 1.18, 0.0), 0.03, 0.38, 0.55, Color(0.24, 0.72, 0.30))
		"piedrita":
			_add_sphere(Vector3(0.0, 0.20, 0.0), 0.30, Color(0.56, 0.60, 0.66))
			_add_sphere(Vector3(0.22, 0.12, 0.14), 0.18, Color(0.48, 0.52, 0.58))
			_add_sphere(Vector3(-0.14, 0.26, -0.06), 0.12, Color(0.26, 0.66, 0.30))
		"arbol_grande":
			_add_cylinder(Vector3(0.0, 0.48, 0.0), 0.16, 0.28, 0.96, Color(0.42, 0.25, 0.14))
			_add_cylinder(Vector3(0.0, 1.15, 0.0), 0.10, 0.86, 1.05, Color(0.13, 0.52, 0.21))
			_add_cylinder(Vector3(0.0, 1.72, 0.0), 0.06, 0.66, 0.85, Color(0.19, 0.64, 0.27))
			_add_cylinder(Vector3(0.0, 2.20, 0.0), 0.03, 0.42, 0.58, Color(0.28, 0.76, 0.34))
			_add_sphere(Vector3(0.32, 1.25, 0.28), 0.08, Color(1.0, 0.78, 0.22), 0.2)
		"piedra_mediana":
			_add_sphere(Vector3(0.0, 0.34, 0.0), 0.52, Color(0.48, 0.52, 0.58))
			_add_sphere(Vector3(-0.34, 0.22, 0.18), 0.32, Color(0.42, 0.46, 0.52))
			_add_sphere(Vector3(0.30, 0.18, -0.20), 0.26, Color(0.54, 0.58, 0.64))
			_add_cylinder(Vector3(0.14, 0.54, 0.12), 0.02, 0.11, 0.28, Color(0.38, 0.86, 0.96), 0.55)
		"roca_enorme":
			_add_sphere(Vector3(0.0, 0.56, 0.0), 0.85, Color(0.38, 0.42, 0.48))
			_add_sphere(Vector3(0.48, 0.36, -0.26), 0.52, Color(0.32, 0.36, 0.42))
			_add_sphere(Vector3(-0.46, 0.30, 0.28), 0.44, Color(0.44, 0.48, 0.54))
			_add_cylinder(Vector3(-0.18, 0.95, 0.22), 0.03, 0.15, 0.45, Color(0.95, 0.72, 0.22), 0.6)
			_add_cylinder(Vector3(0.28, 0.82, -0.10), 0.02, 0.12, 0.38, Color(0.95, 0.72, 0.22), 0.6)
		_:
			_add_sphere(Vector3(0.0, 0.30, 0.0), 0.35, Color(0.4, 0.6, 0.3))

	# Anillo luminoso dorado de limpieza activa
	_work_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.78
	torus.rings = 14
	torus.ring_segments = 8
	_work_ring.mesh = torus
	_work_ring.material_override = VisualShaders.make_toon(
		Color(1.0, 0.84, 0.25),
		Color(0.5, 0.35, 0.1),
		0.5,
		0.3,
		0.2,
		Color(1.0, 0.78, 0.18),
		0.95
	)
	_work_ring.position = Vector3(0.0, 0.08, 0.0)
	_work_ring.visible = limpiando
	visual_root.add_child(_work_ring)


func _add_sphere(pos: Vector3, radius: float, color: Color, emit_strength: float = 0.0) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 1.65
	sm.radial_segments = 9
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = VisualShaders.make_toon(
		color,
		Color(0.20, 0.24, 0.36),
		0.36,
		0.86,
		0.0,
		color,
		emit_strength
	)
	mi.position = pos
	visual_root.add_child(mi)


func _add_cylinder(pos: Vector3, top_r: float, bot_r: float, h: float, color: Color, emit_strength: float = 0.0) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = 7
	mi.mesh = cm
	mi.material_override = VisualShaders.make_toon(
		color,
		Color(0.20, 0.24, 0.36),
		0.34,
		0.84,
		0.0,
		color,
		emit_strength
	)
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
