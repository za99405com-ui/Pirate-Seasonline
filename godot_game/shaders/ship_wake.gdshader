shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// Ribbon wake that rides on the SAME 4 ocean waves. No particle cost.
uniform float sea_time = 0.0;
uniform float ship_speed_ratio : hint_range(0.0, 1.0) = 0.0;
varying vec2 wake_uv;

void vertex(){
	wake_uv = UV;
	vec2 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
	float a = dot(p, vec2(0.14,0.09)) + sea_time*0.62;
	float b = dot(p, vec2(-0.10,0.19)) - sea_time*0.47;
	float c = dot(p, vec2(0.24,-0.06)) + sea_time*0.88;
	float d = dot(p, vec2(-0.36,-0.13)) + sea_time*1.37;
	float h = 0.30*(0.52*sin(a)+0.33*sin(b)+0.15*sin(c))+0.07*sin(d);
	VERTEX.y += h;
}

void fragment(){
	vec2 uv = wake_uv;
	float aft = uv.y;
	float dist_from_centre = abs(uv.x - 0.5);
	// Two widening, feathered ripples behind the stern.
	float line_width = 0.10 + aft*0.31;
	float arm = exp(-pow((dist_from_centre-line_width)/0.06,2.0));
	float churn = exp(-pow(dist_from_centre/(0.06+aft*0.16),2.0));
	float breaking = 0.6+0.4*sin(uv.y*36.0 - sea_time*4.2 + sin(uv.x*35.0)*1.5);
	float missing = 0.4+0.6*sin(uv.x*67.0+uv.y*47.0+sin(uv.y*29.0)*2.0);
	float fade = smoothstep(0.02,0.22,aft)*(1.0-smoothstep(0.72,1.0,aft));
	float strength = (0.31*arm + 0.27*churn)*breaking*missing*fade;
	ALBEDO = vec3(0.73,0.89,0.89);
	ALPHA = clamp(strength*ship_speed_ratio*1.7,0.0,0.42);
}
