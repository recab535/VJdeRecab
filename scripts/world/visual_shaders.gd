class_name VisualShaders
extends RefCounted

## Fábrica centralizada de materiales 2.5D estilizados (toon + agua/lava/energía).

const TOON_SHADER: Shader = preload("res://assets/shaders/toon_stylized.gdshader")
const FLOW_SHADER: Shader = preload("res://assets/shaders/water_lava_flow.gdshader")


static func make_toon(
	albedo: Color,
	shadow_tint: Color = Color(0.24, 0.28, 0.44, 1.0),
	rim_strength: float = 0.36,
	roughness: float = 0.72,
	metallic: float = 0.0,
	emission: Color = Color(0.0, 0.0, 0.0, 1.0),
	emission_strength: float = 0.0,
	toon_steps: float = 3.0
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo_color", albedo)
	mat.set_shader_parameter("shadow_tint", shadow_tint)
	mat.set_shader_parameter("rim_strength", rim_strength)
	mat.set_shader_parameter("roughness_val", roughness)
	mat.set_shader_parameter("metallic_val", metallic)
	mat.set_shader_parameter("emission_color", emission)
	mat.set_shader_parameter("emission_strength", emission_strength)
	mat.set_shader_parameter("toon_steps", toon_steps)
	return mat


static func make_water(
	base_col: Color = Color(0.14, 0.64, 0.94, 0.92),
	deep_col: Color = Color(0.05, 0.30, 0.64, 0.96),
	foam_col: Color = Color(0.86, 0.97, 1.0, 1.0),
	speed: float = 0.65,
	amp: float = 0.04
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLOW_SHADER
	mat.set_shader_parameter("base_color", base_col)
	mat.set_shader_parameter("deep_color", deep_col)
	mat.set_shader_parameter("foam_color", foam_col)
	mat.set_shader_parameter("flow_speed", speed)
	mat.set_shader_parameter("wave_amplitude", amp)
	mat.set_shader_parameter("emission_strength", 0.22)
	mat.set_shader_parameter("roughness_val", 0.16)
	return mat


static func make_lava(
	base_col: Color = Color(0.98, 0.34, 0.08, 1.0),
	deep_col: Color = Color(0.42, 0.07, 0.04, 1.0),
	foam_col: Color = Color(1.0, 0.88, 0.32, 1.0),
	speed: float = 0.42
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLOW_SHADER
	mat.set_shader_parameter("base_color", base_col)
	mat.set_shader_parameter("deep_color", deep_col)
	mat.set_shader_parameter("foam_color", foam_col)
	mat.set_shader_parameter("flow_speed", speed)
	mat.set_shader_parameter("wave_amplitude", 0.035)
	mat.set_shader_parameter("foam_threshold", 0.62)
	mat.set_shader_parameter("emission_strength", 1.35)
	mat.set_shader_parameter("roughness_val", 0.32)
	return mat


static func make_astral_flow() -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLOW_SHADER
	mat.set_shader_parameter("base_color", Color(0.48, 0.28, 0.94, 0.92))
	mat.set_shader_parameter("deep_color", Color(0.16, 0.08, 0.38, 0.96))
	mat.set_shader_parameter("foam_color", Color(0.92, 0.78, 1.0, 1.0))
	mat.set_shader_parameter("flow_speed", 0.55)
	mat.set_shader_parameter("wave_amplitude", 0.045)
	mat.set_shader_parameter("foam_threshold", 0.64)
	mat.set_shader_parameter("emission_strength", 1.1)
	mat.set_shader_parameter("roughness_val", 0.22)
	return mat
