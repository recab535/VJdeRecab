shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 base_color : source_color = vec4(0.14, 0.62, 0.92, 0.92);
uniform vec4 deep_color : source_color = vec4(0.06, 0.30, 0.62, 0.95);
uniform vec4 foam_color : source_color = vec4(0.84, 0.96, 1.0, 1.0);
uniform vec2 flow_direction = vec2(0.18, 0.12);
uniform float flow_speed : hint_range(0.0, 3.0) = 0.65;
uniform float wave_amplitude : hint_range(0.0, 0.35) = 0.04;
uniform float wave_frequency : hint_range(0.5, 12.0) = 3.5;
uniform float uv_scale : hint_range(0.5, 16.0) = 4.0;
uniform float foam_threshold : hint_range(0.2, 0.95) = 0.68;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.25;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.18;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += amp * value_noise(p);
		p *= 2.05;
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	float t = TIME * flow_speed * 2.2;
	float w1 = sin(VERTEX.x * wave_frequency + t) * cos(VERTEX.z * wave_frequency * 0.85 + t * 0.9);
	float w2 = sin((VERTEX.x + VERTEX.z) * wave_frequency * 0.65 - t * 1.15);
	VERTEX.y += (w1 * 0.65 + w2 * 0.35) * wave_amplitude;
}

void fragment() {
	vec2 uv1 = UV * uv_scale + flow_direction * TIME * flow_speed;
	vec2 uv2 = UV * (uv_scale * 1.45) - flow_direction.yx * TIME * (flow_speed * 0.72);
	float n1 = fbm(uv1);
	float n2 = fbm(uv2);
	float combined = n1 * 0.55 + n2 * 0.45;

	vec3 col = mix(deep_color.rgb, base_color.rgb, smoothstep(0.25, 0.75, combined));
	float foam_mask = smoothstep(foam_threshold, foam_threshold + 0.14, combined);
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);

	col = mix(col, foam_color.rgb, clamp(foam_mask * 0.85 + fresnel * 0.32, 0.0, 1.0));

	ALBEDO = col;
	ROUGHNESS = roughness_val;
	METALLIC = 0.05;
	EMISSION = mix(base_color.rgb, foam_color.rgb, foam_mask) * emission_strength;
	ALPHA = base_color.a;
}
