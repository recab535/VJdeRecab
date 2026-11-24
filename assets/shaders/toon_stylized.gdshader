shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(0.32, 0.78, 0.36, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.28, 0.34, 0.48, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.08;
uniform float rim_power : hint_range(1.0, 8.0) = 4.0;
uniform float toon_steps : hint_range(2.0, 6.0) = 4.0;
uniform float toon_smoothness : hint_range(0.02, 0.45) = 0.22;
uniform float specular_strength : hint_range(0.0, 0.5) = 0.02;
uniform float specular_shininess : hint_range(4.0, 64.0) = 18.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.90;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 3.0) = 0.0;
uniform float gradient_strength : hint_range(0.0, 0.4) = 0.10;
uniform float micro_variation : hint_range(0.0, 0.15) = 0.045;

varying vec3 v_local_pos;
varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float smooth_noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float height_factor = clamp(v_local_pos.y * 0.28 + 0.5, 0.0, 1.0);
	vec3 grad_col = mix(albedo_color.rgb * (1.0 - gradient_strength), albedo_color.rgb * (1.0 + gradient_strength * 0.55), height_factor);

	// Ruido orgánico continuo (sin cuadrícula ni bloques repetitivos)
	float n1 = smooth_noise2d(v_world_pos.xz * 0.35 + v_world_pos.xy * 0.15);
	float n2 = smooth_noise2d(v_world_pos.xz * 0.95 + vec2(11.3, 7.1));
	float organic = ((n1 * 0.65 + n2 * 0.35) * 2.0 - 1.0);
	vec3 final_albedo = clamp(grad_col + vec3(organic * micro_variation), vec3(0.0), vec3(1.0));

	ALBEDO = final_albedo;
	ROUGHNESS = roughness_val;
	METALLIC = metallic_val;
	EMISSION = emission_color.rgb * emission_strength;
	ALPHA = albedo_color.a;
}

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float half_lambert = ndotl * 0.45 + 0.55;
	float atten = clamp(ATTENUATION, 0.0, 1.0);
	float lit_val = clamp(half_lambert * (0.45 + 0.55 * atten), 0.0, 1.0);

	float scaled = lit_val * toon_steps;
	float step_idx = floor(scaled);
	float frac = fract(scaled);
	float smooth_step = smoothstep(0.5 - toon_smoothness, 0.5 + toon_smoothness, frac);
	float toon_band = clamp((step_idx + smooth_step) / toon_steps, 0.0, 1.0);

	vec3 shadow_col = ALBEDO * shadow_tint.rgb;
	vec3 lit_col = ALBEDO * LIGHT_COLOR * 0.30;
	vec3 diffuse = mix(shadow_col * 0.24, lit_col, toon_band);
	DIFFUSE_LIGHT += diffuse;

	// Especular muy suave y acotado para evitar fogonazos blancos al rotar 360°
	vec3 half_vec = normalize(LIGHT + VIEW);
	float ndoth = max(dot(NORMAL, half_vec), 0.0);
	float spec_raw = pow(ndoth, specular_shininess) * (1.0 - roughness_val * 0.85);
	float flat_damp = 1.0 - smoothstep(0.75, 0.96, abs(NORMAL.y));
	float spec_band = spec_raw * specular_strength * atten * (0.25 + 0.75 * flat_damp);
	SPECULAR_LIGHT += LIGHT_COLOR * min(spec_band, 0.06);

	// Rim cálido muy sutil solo en siluetas verticales
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), rim_power);
	float rim_mask = smoothstep(0.45, 0.88, fresnel) * flat_damp * clamp(ndotl + 0.2, 0.0, 1.0);
	SPECULAR_LIGHT += rim_color.rgb * rim_mask * rim_strength * atten * 0.35;
}
