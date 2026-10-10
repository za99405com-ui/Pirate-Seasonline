shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Ocean 2.0 — broad crossing swells, tiny ripples, broken foam, sun reflections.
// Godot 4 mobile / WebGL compatible, no screen-space texture reads or particles.
// Wave positions match get_wave_height() in scripts/world/world.gd.
uniform vec3 deep_color : source_color = vec3(0.015, 0.10, 0.17);
uniform vec3 surface_color : source_color = vec3(0.045, 0.24, 0.30);
uniform vec3 sky_reflection : source_color = vec3(0.32, 0.57, 0.70);
uniform float daylight : hint_range(0.0, 1.0) = 0.88;
uniform float sea_time = 0.0;
uniform float swell_height : hint_range(0.0, 1.0) = 1.0;

varying vec2 ocean_coord;
varying float crest;
varying float ocean_slope;
varying vec3 ocean_world_position;

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	ocean_coord = p;
	float a = dot(p, vec2(0.14, 0.09)) + sea_time * 0.62;
	float b = dot(p, vec2(-0.10, 0.19)) - sea_time * 0.47;
	float c = dot(p, vec2(0.24, -0.06)) + sea_time * 0.88;
	float d = dot(p, vec2(-0.36, -0.13)) + sea_time * 1.37;
	float h = 0.30 * (0.52 * sin(a) + 0.33 * sin(b) + 0.15 * sin(c))
			+ 0.07 * sin(d);
	VERTEX.y += h * swell_height;
	crest = h;
	float ddx = 0.30 * (
		0.52 * 0.14 * cos(a)
		- 0.33 * 0.10 * cos(b)
		+ 0.15 * 0.24 * cos(c)
	) + 0.07 * -0.36 * cos(d);
	float ddz = 0.30 * (
		0.52 * 0.09 * cos(a)
		+ 0.33 * 0.19 * cos(b)
		- 0.15 * 0.06 * cos(c)
	) + 0.07 * -0.13 * cos(d);
	NORMAL = normalize(vec3(-ddx * swell_height, 1.0, -ddz * swell_height));
	ocean_slope = length(vec2(ddx, ddz));
	ocean_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = ocean_coord;
	// Short irregular capillary ripples, domain-warped to avoid dot patterns.
	float warp = sin(p.x * 0.45 - p.y * 0.24 + sea_time * 0.28) * 0.47;
	float r1 = sin((p.x + warp) * 1.12 + p.y * 0.83 - sea_time * 1.95);
	float r2 = sin((p.y - warp) * 1.48 - p.x * 0.51 + sea_time * 1.52);
	float r3 = sin(p.x * 0.72 - p.y * 1.27 - sea_time * 1.18);
	vec2 ripples = vec2(
		1.12 * cos((p.x + warp) * 1.12 + p.y * 0.83 - sea_time * 1.95) +
		-0.51 * cos((p.y - warp) * 1.48 - p.x * 0.51 + sea_time * 1.52),
		0.83 * cos((p.x + warp) * 1.12 + p.y * 0.83 - sea_time * 1.95) +
		1.48 * cos((p.y - warp) * 1.48 - p.x * 0.51 + sea_time * 1.52)
	);
	// Perturb the already-correct large-swell normal in view space.
	vec3 micro_normal = (VIEW_MATRIX * vec4(vec3(ripples.x, 0.0, ripples.y), 0.0)).xyz;
	NORMAL = normalize(NORMAL - micro_normal * 0.085);

	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = 0.026 + 0.974 * pow(1.0 - ndotv, 5.0);
	float rolling = clamp(0.5 + crest * 0.75 + (r1 + r2 + r3) * 0.017, 0.0, 1.0);
	vec3 sea = mix(deep_color, surface_color, rolling);
	float sky_mix = clamp(fresnel * 0.53, 0.0, 0.62);
	sea = mix(sea, sky_reflection, sky_mix);
	// Sparse pale foam on breaking crests, not tiled white spots.
	float foam_mask = smoothstep(0.24, 0.35, crest)
		* smoothstep(0.12, 0.25, ocean_slope + 0.02 * r2);
	float foam_breakup = smoothstep(-0.35, 0.42, r1 * 0.46 + r2 * 0.36 + r3 * 0.18);
	sea = mix(sea, vec3(0.60, 0.78, 0.80), foam_mask * foam_breakup * 0.33);
	// In distance sea gets a light blue atmospheric wash, softening the horizon.
	float dist = distance(CAMERA_POSITION_WORLD, ocean_world_position);
	float haze = smoothstep(130.0, 440.0, dist) * 0.43;
	sea = mix(sea, vec3(0.29, 0.48, 0.57), haze);
	ALBEDO = sea * mix(0.19, 1.03, daylight);
	ROUGHNESS = clamp(0.19 + 0.055 * r1 + 0.035 * r2, 0.12, 0.34);
	SPECULAR = 0.83;
	METALLIC = 0.0;
}
