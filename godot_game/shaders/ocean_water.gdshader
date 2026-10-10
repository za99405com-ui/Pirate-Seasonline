shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Smooth stylised-realistic sea for Godot 4 mobile browsers.
// Large crossing swells + very soft broken highlights: avoid repeating dots.
uniform vec3 deep_color : source_color = vec3(0.016, 0.155, 0.255);
uniform vec3 light_color : source_color = vec3(0.048, 0.295, 0.385);
uniform float daylight : hint_range(0.0, 1.0) = 0.86;
uniform float wave_height : hint_range(0.0, 0.5) = 0.30;
uniform float sea_time = 0.0;
varying float wave_crest;
varying vec2 sea_uv;

void vertex(){
  vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
  sea_uv = p;
  float a = sin(dot(p, vec2(0.14, 0.09)) + sea_time * 0.62);
  float b = sin(dot(p, vec2(-0.10, 0.19)) - sea_time * 0.47);
  float c = sin(dot(p, vec2(0.24, -0.06)) + sea_time * 0.88);
  wave_crest = 0.52*a + 0.33*b + 0.15*c;
  VERTEX.y += wave_crest * wave_height;
  float dx = (0.52*0.14*cos(dot(p,vec2(0.14,0.09))+sea_time*0.62)
    + 0.33*(-0.10)*cos(dot(p,vec2(-0.10,0.19))-sea_time*0.47)
    + 0.15*0.24*cos(dot(p,vec2(0.24,-0.06))+sea_time*0.88))*wave_height;
  float dz = (0.52*0.09*cos(dot(p,vec2(0.14,0.09))+sea_time*0.62)
    + 0.33*0.19*cos(dot(p,vec2(-0.10,0.19))-sea_time*0.47)
    - 0.15*0.06*cos(dot(p,vec2(0.24,-0.06))+sea_time*0.88))*wave_height;
  NORMAL = normalize(vec3(-dx,1.0,-dz));
}

void fragment(){
  // Mild wave streaks, not bright repeating circular patches.
  float flow = sin(sea_uv.x*0.36 + sea_uv.y*0.19 + sea_time*0.7
      + sin(sea_uv.y*0.11 - sea_time*0.26)*0.9);
  float flow2 = sin(sea_uv.x*(-0.21) + sea_uv.y*0.27 - sea_time*0.42);
  float shimmer = smoothstep(0.74,1.50,flow*0.67+flow2*0.33);
  float tint = clamp(0.50 + wave_crest*0.16 + flow*0.022, 0.1,0.9);
  float crest_foam = smoothstep(0.73, 0.99, wave_crest) * (0.07 + 0.05 * flow2);
  float view_fresnel = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
  vec3 col = mix(deep_color,light_color,tint);
  col *= mix(0.19,1.0,daylight);
  ALBEDO = col + vec3(0.023,0.037,0.042)*shimmer*daylight
              + vec3(0.035,0.055,0.060)*view_fresnel*daylight
              + vec3(0.28,0.38,0.42)*crest_foam*daylight;
  ROUGHNESS=0.34;
  SPECULAR=0.42;
  METALLIC=0.01;
}
