shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Economical water for Godot 4 Mobile/WebGL: three coherent long waves +
// inexpensive high-frequency glints. No costly screen refraction.
uniform vec3 deep_color : source_color = vec3(0.018, 0.15, 0.265);
uniform vec3 light_color : source_color = vec3(0.035, 0.36, 0.45);
uniform float daylight : hint_range(0.0, 1.0) = 0.86;
uniform float wave_height : hint_range(0.0, 0.4) = 0.20;
varying float wave_crest;
varying vec2 sea_uv;

void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	sea_uv = p;
	float wave_a = sin(p.x * 0.27 + TIME * 0.86) * 0.50;
	float wave_b = cos(p.y * 0.31 - TIME * 0.73 + p.x * 0.08) * 0.32;
	float wave_c = sin((p.x + p.y) * 0.16 + TIME * 0.52) * 0.18;
	wave_crest = wave_a + wave_b + wave_c;
	VERTEX.y += wave_crest * wave_height;
	float grad_x = (0.50 * 0.27 * cos(p.x * 0.27 + TIME * 0.86)
		+ 0.32 * 0.08 * -sin(p.y * 0.31 - TIME * 0.73 + p.x * 0.08)
		+ 0.18 * 0.16 * cos((p.x + p.y) * 0.16 + TIME * 0.52)) * wave_height;
	float grad_z = (-0.32 * 0.31 * sin(p.y * 0.31 - TIME * 0.73 + p.x * 0.08)
		+ 0.18 * 0.16 * cos((p.x + p.y) * 0.16 + TIME * 0.52)) * wave_height;
	NORMAL = normalize(vec3(-grad_x, 1.0, -grad_z));
}

void fragment() {
	float ripple_a = sin(sea_uv.x * 1.35 + sea_uv.y * 0.52 + TIME * 1.1);
	float ripple_b = sin(sea_uv.y * 1.66 - sea_uv.x * 0.34 - TIME * 1.4);
	float highlights = smoothstep(0.82, 1.75, ripple_a + ripple_b);
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	float depth_tint = clamp(0.49 + wave_crest * 0.15 + ripple_a * 0.045, 0.08, 0.82);
	vec3 ocean_tint = mix(deep_color, light_color, depth_tint);
	ocean_tint *= mix(0.18, 1.04, daylight);
	ALBEDO = ocean_tint + vec3(0.10, 0.15, 0.17) * fresnel * daylight
		+ vec3(0.12, 0.15, 0.15) * highlights * 0.22 * daylight;
	METALLIC = 0.02;
	ROUGHNESS = 0.31;
	SPECULAR = 0.76;
}
