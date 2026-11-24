shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(0.32, 0.78, 0.36, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.24, 0.28, 0.44, 1.0);
uniform vec4 rim_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.38;
uniform float rim_power : hint_range(1.0, 8.0) = 3.2;
uniform float toon_steps : hint_range(2.0, 6.0) = 3.0;
uniform float toon_smoothness : hint_range(0.01, 0.3) = 0.08;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.22;
uniform float specular_shininess : hint_range(4.0, 64.0) = 24.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.75;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;
uniform float gradient_strength : hint_range(0.0, 0.5) = 0.14;
uniform float micro_variation : hint_range(0.0, 0.2) = 0.05;

varying vec3 v_local_pos;
varying vec3 v_world_pos;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float height_factor = clamp(v_local_pos.y * 0.35 + 0.5, 0.0, 1.0);
	vec3 grad_col = mix(albedo_color.rgb * (1.0 - gradient_strength), albedo_color.rgb * (1.0 + gradient_strength * 0.75), height_factor);

	vec3 cell = floor(v_world_pos * 2.5);
	float n = hash31(cell) * 2.0 - 1.0;
	vec3 final_albedo = clamp(grad_col + vec3(n * micro_variation), vec3(0.0), vec3(1.0));

	ALBEDO = final_albedo;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	EMISSION = emission_color.rgb * emission_strength;
	ALPHA = albedo_color.a;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float half_lambert = ndotl * 0.5 + 0.5;
	float atten = clamp(ATTENUATION, 0.0, 1.0);
	float lit_val = half_lambert * atten;

	float scaled = lit_val * toon_steps;
	float step_idx = floor(scaled);
	float frac = fract(scaled);
	float smooth_step = smoothstep(0.5 - toon_smoothness, 0.5 + toon_smoothness, frac);
	float toon_band = clamp((step_idx + smooth_step) / toon_steps, 0.0, 1.0);

	vec3 shadow_col = ALBEDO * shadow_tint.rgb;
	vec3 lit_col = ALBEDO * LIGHT_COLOR / PI;
	vec3 diffuse = mix(shadow_col * 0.45, lit_col, toon_band);
	DIFFUSE_LIGHT += diffuse;

	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndoth = max(dot(NORMAL, half_vec), 0.0);
	float spec_raw = pow(ndoth, specular_shininess);
	float spec_band = smoothstep(0.45, 0.55, spec_raw) * specular_strength * atten;
	SPECULAR_LIGHT += LIGHT_COLOR * spec_band;

	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);
	float rim_mask = smoothstep(0.25, 0.75, fresnel) * clamp(ndotl + 0.35, 0.0, 1.0);
	SPECULAR_LIGHT += rim_color.rgb * rim_mask * rim_strength * atten;
}
