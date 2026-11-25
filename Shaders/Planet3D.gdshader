shader_type spatial;
render_mode unshaded;

uniform vec3 band_color_a : source_color = vec3(0.10, 0.34, 0.58);
uniform vec3 band_color_b : source_color = vec3(0.28, 0.14, 0.48);
uniform vec3 atmo_color : source_color = vec3(0.28, 0.85, 1.0);
uniform vec3 sun_dir = vec3(-0.55, 0.48, 0.68);

varying vec3 v_local_pos;
varying vec3 v_world_normal;

#include "res://Shaders/Noise3DLib.gdshaderinc"

void vertex() {
	v_local_pos = normalize(VERTEX);
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Полосатая атмосфера газового гиганта с турбулентными вихрями
	float storm = noise3(v_local_pos * 3.8 + vec3(TIME * 0.03, 0.0, 0.0));
	float bands = 0.5 + 0.5 * sin(v_local_pos.y * 15.0 + storm * 3.2);
	vec3 surface_col = mix(band_color_a, band_color_b, bands);
	surface_col = mix(surface_col, atmo_color * 0.75, smoothstep(0.65, 0.95, storm) * 0.35);

	// Мягкий терминатор освещения (серп планеты на фоне тёмного космоса)
	vec3 l_dir = normalize(sun_dir);
	float ndotl = smoothstep(-0.22, 0.78, dot(v_world_normal, l_dir));
	vec3 lit_col = surface_col * (0.04 + ndotl * 0.92);

	// Атмосферное Fresnel-сияние по освещённому лимбу планеты
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 3.2);
	float limb_light = smoothstep(-0.35, 0.55, dot(v_world_normal, l_dir));
	lit_col += atmo_color * fresnel * (0.22 + limb_light * 0.95);

	ALBEDO = lit_col;
}
