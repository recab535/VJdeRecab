shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.14, 0.46, 0.92);
uniform vec3 sky_mid_color : source_color = vec3(0.36, 0.74, 0.98);
uniform vec3 sky_horizon_color : source_color = vec3(0.86, 0.94, 1.0);
uniform vec3 ground_horizon_color : source_color = vec3(0.56, 0.78, 0.95);
uniform vec3 ground_bottom_color : source_color = vec3(0.12, 0.24, 0.46);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.76);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.99, 0.97);
uniform vec3 cloud_shadow_color : source_color = vec3(0.74, 0.86, 0.98);
uniform float cloud_speed : hint_range(0.0, 0.1) = 0.012;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.52;
uniform float sun_size : hint_range(0.01, 0.15) = 0.045;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm_clouds(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise2d(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	vec3 col;
	if (y >= 0.0) {
		float mid_t = smoothstep(0.0, 0.32, y);
		float top_t = smoothstep(0.22, 0.85, y);
		col = mix(sky_horizon_color, sky_mid_color, mid_t);
		col = mix(col, sky_top_color, top_t);
	} else {
		float ground_t = smoothstep(0.0, 0.55, -y);
		col = mix(ground_horizon_color, ground_bottom_color, ground_t);
	}

	// Halo y disco solar estilizado
	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : normalize(vec3(0.45, 0.58, -0.68));
	float sun_dot = max(dot(dir, sun_dir), 0.0);
	float sun_disc = smoothstep(1.0 - sun_size * 0.05, 1.0 - sun_size * 0.012, sun_dot);
	float sun_halo = pow(sun_dot, 12.0) * 0.22 + pow(sun_dot, 48.0) * 0.28;
	col += sun_color * (sun_halo + sun_disc * 0.55);

	// Nubes estilizadas sobre el horizonte
	if (y > 0.02) {
		vec2 cloud_uv = dir.xz / (y + 0.22) * 1.45;
		cloud_uv += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
		float c = fbm_clouds(cloud_uv);
		float c_mask = smoothstep(1.0 - cloud_density, 1.0 - cloud_density + 0.22, c);
		float horizon_fade = smoothstep(0.02, 0.22, y) * (1.0 - smoothstep(0.65, 0.95, y) * 0.4);
		float shade = smoothstep(0.45, 0.8, c);
		vec3 final_cloud = mix(cloud_shadow_color, cloud_color, shade);
		col = mix(col, final_cloud, c_mask * horizon_fade * 0.78);
	}

	// Banda brumosa brillante en el horizonte para efecto archipiélago en las nubes
	float horizon_glow = exp(-abs(y) * 14.0) * 0.25;
	col = mix(col, sky_horizon_color, horizon_glow);

	COLOR = col;
}
