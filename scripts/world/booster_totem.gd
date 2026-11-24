extends Node3D
class_name BoosterTotem

## Tótem Potenciador Elemental 3D detallado (1..8: Tierra, Fuego, Agua, Planta,
## Eléctrico, Hielo, Metal, Oscuro) con pedestal esculpido, columna rúnica y cristal giratorio.

const ELEM_SPECS: Dictionary = {
	1: {"nombre": "Tierra", "color": Color(0.72, 0.48, 0.24)},
	2: {"nombre": "Fuego", "color": Color(0.96, 0.34, 0.16)},
	3: {"nombre": "Agua", "color": Color(0.20, 0.64, 0.96)},
	4: {"nombre": "Planta", "color": Color(0.28, 0.82, 0.36)},
	5: {"nombre": "Eléctrico", "color": Color(0.98, 0.86, 0.22)},
	6: {"nombre": "Hielo", "color": Color(0.58, 0.90, 0.98)},
	7: {"nombre": "Metal", "color": Color(0.72, 0.76, 0.84)},
	8: {"nombre": "Oscuro", "color": Color(0.54, 0.26, 0.76)}
}

var elemento_id: int = 1
var _crown_crystal: MeshInstance3D = null
var _aura_ring: MeshInstance3D = null
var _time: float = 0.0


func setup(eid: int) -> void:
	elemento_id = eid
	_build_totem()


func _build_totem() -> void:
	var spec: Dictionary = ELEM_SPECS.get(elemento_id, ELEM_SPECS[1])
	var col: Color = spec["color"]
	var stone_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.42, 0.42, 0.48), Color(0.18, 0.20, 0.30), 0.32, 0.88)
	var elem_mat: ShaderMaterial = VisualShaders.make_toon(col, Color(0.20, 0.18, 0.32), 0.65, 0.24, 0.22, col, 1.15)
	var gold_mat: ShaderMaterial = VisualShaders.make_toon(Color(0.96, 0.80, 0.28), Color(0.44, 0.28, 0.10), 0.5, 0.28, 0.45)

	# Pedestal escalonado
	var ped: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 0.42
	pm.bottom_radius = 0.52
	pm.height = 0.26
	pm.radial_segments = 8
	ped.mesh = pm
	ped.material_override = stone_mat
	ped.position = Vector3(0.0, 0.13, 0.0)
	add_child(ped)

	# Columna tallada del tótem
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var sm: CylinderMesh = CylinderMesh.new()
	sm.top_radius = 0.20
	sm.bottom_radius = 0.30
	sm.height = 1.15
	sm.radial_segments = 6
	shaft.mesh = sm
	shaft.material_override = stone_mat
	shaft.position = Vector3(0.0, 0.82, 0.0)
	add_child(shaft)

	# Banda dorada + anillo luminoso elemental en la base
	_aura_ring = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.36
	tm.outer_radius = 0.46
	tm.rings = 14
	tm.ring_segments = 6
	_aura_ring.mesh = tm
	_aura_ring.material_override = elem_mat
	_aura_ring.position = Vector3(0.0, 0.30, 0.0)
	add_child(_aura_ring)

	var cap: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.20
	cm.height = 0.16
	cm.radial_segments = 6
	cap.mesh = cm
	cap.material_override = gold_mat
	cap.position = Vector3(0.0, 1.44, 0.0)
	add_child(cap)

	# Cristal elemental flotante en la cima
	_crown_crystal = MeshInstance3D.new()
	var crm: CylinderMesh = CylinderMesh.new()
	crm.top_radius = 0.02
	crm.bottom_radius = 0.22
	crm.height = 0.56
	crm.radial_segments = 6
	_crown_crystal.mesh = crm
	_crown_crystal.material_override = elem_mat
	_crown_crystal.position = Vector3(0.0, 1.88, 0.0)
	add_child(_crown_crystal)

	var lbl: Label3D = Label3D.new()
	lbl.text = "Tótem %s\n(×2 / ×3)" % str(spec["nombre"])
	lbl.position = Vector3(0.0, 2.42, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 20
	lbl.outline_size = 5
	lbl.modulate = col.lightened(0.32)
	add_child(lbl)


func _process(delta: float) -> void:
	_time += delta * 2.4
	if _crown_crystal:
		_crown_crystal.rotation.y += delta * 1.6
		_crown_crystal.position.y = 1.88 + sin(_time) * 0.08
	if _aura_ring:
		_aura_ring.rotation.y -= delta * 0.8
