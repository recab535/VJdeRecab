extends Node3D
class_name IslandAmbient

## Añade levitación suave a la isla, decoración low-poly (árboles/rocas) y nubes ambientales.

@export var bob_amplitude: float = 0.14
@export var bob_speed: float = 1.15
@export var spawn_trees: bool = true
@export var spawn_clouds: bool = true

var _base_y: float = 0.0
var _time: float = 0.0
var _clouds: Array[Node3D] = []


func _ready() -> void:
	_base_y = position.y
	if spawn_trees:
		_build_lowpoly_props()
	if spawn_clouds:
		_build_ambient_clouds()


func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * bob_speed) * bob_amplitude

	for cloud: Node3D in _clouds:
		cloud.position.x += delta * 0.45
		if cloud.position.x > 22.0:
			cloud.position.x = -22.0


func _build_lowpoly_props() -> void:
	var decor: Node3D = Node3D.new()
	decor.name = "DecoracionLowPoly"
	add_child(decor)

	var tree_positions: Array[Vector3] = [
		Vector3(-4.1, 0.6, 1.4),
		Vector3(3.9, 0.6, 1.7),
		Vector3(-3.6, 0.6, -2.6),
		Vector3(4.0, 0.6, -2.2)
	]
	for pos: Vector3 in tree_positions:
		decor.add_child(_create_lowpoly_tree(pos))

	var rock_positions: Array[Vector3] = [
		Vector3(-4.5, 0.65, -0.3),
		Vector3(4.4, 0.65, 0.2),
		Vector3(0.4, 0.65, -4.1)
	]
	for pos: Vector3 in rock_positions:
		decor.add_child(_create_lowpoly_rock(pos))


func _create_lowpoly_tree(pos: Vector3) -> Node3D:
	var tree: Node3D = Node3D.new()
	tree.position = pos

	var trunk: MeshInstance3D = MeshInstance3D.new()
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.1
	trunk_mesh.bottom_radius = 0.14
	trunk_mesh.height = 0.55
	trunk_mesh.radial_segments = 6
	var trunk_mat: StandardMaterial3D = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.46, 0.28, 0.16, 1.0)
	trunk_mesh.material = trunk_mat
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.27
	tree.add_child(trunk)

	var leaves: MeshInstance3D = MeshInstance3D.new()
	var leaves_mesh: CylinderMesh = CylinderMesh.new()
	leaves_mesh.top_radius = 0.05
	leaves_mesh.bottom_radius = 0.52
	leaves_mesh.height = 0.95
	leaves_mesh.radial_segments = 6
	var leaves_mat: StandardMaterial3D = StandardMaterial3D.new()
	leaves_mat.albedo_color = Color(0.18, 0.62, 0.26, 1.0)
	leaves_mesh.material = leaves_mat
	leaves.mesh = leaves_mesh
	leaves.position.y = 0.85
	tree.add_child(leaves)

	return tree


func _create_lowpoly_rock(pos: Vector3) -> MeshInstance3D:
	var rock: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.34
	mesh.height = 0.45
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.54, 0.58, 1.0)
	mat.roughness = 0.95
	mesh.material = mat
	rock.mesh = mesh
	rock.position = pos
	return rock


func _build_ambient_clouds() -> void:
	var cloud_mat: StandardMaterial3D = StandardMaterial3D.new()
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.72)
	cloud_mat.roughness = 1.0

	var offsets: Array[Vector3] = [
		Vector3(-12, 4.5, -10),
		Vector3(6, 5.2, -13),
		Vector3(-4, 3.8, -16),
		Vector3(14, 4.0, -8)
	]
	for pos: Vector3 in offsets:
		var cloud: Node3D = Node3D.new()
		cloud.position = pos
		for i: int in range(3):
			var puff: MeshInstance3D = MeshInstance3D.new()
			var sm: SphereMesh = SphereMesh.new()
			sm.radius = 1.1 if i == 1 else 0.75
			sm.height = 1.0 if i == 1 else 0.75
			sm.radial_segments = 8
			sm.rings = 4
			sm.material = cloud_mat
			puff.mesh = sm
			puff.position = Vector3((i - 1) * 0.85, 0.15 if i == 1 else 0.0, 0.0)
			cloud.add_child(puff)
		add_child(cloud)
		_clouds.append(cloud)
