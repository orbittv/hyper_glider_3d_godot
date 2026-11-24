shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never;

uniform float tunnel_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float scroll_speed : hint_range(0.5, 10.0) = 2.2;
uniform vec4 primary_color : source_color = vec4(0.08, 0.58, 0.86, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.42, 0.14, 0.76, 1.0);
uniform float rainbow_mode : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	// UV.x — вокруг окружности цилиндра [0..1], UV.y — вдоль длины туннеля [0..1]
	float angle = UV.x * 6.2831853;
	float z_coord = UV.y * 12.0 + TIME * scroll_speed * 2.2;

	// Мягкие широкие волны туманности (aurora-потоки) без резких концентрических колец и стробоскопа
	float ribbon_a = 0.5 + 0.5 * sin(angle * 3.0 + z_coord * 0.75 - TIME * 1.8);
	float ribbon_b = 0.5 + 0.5 * cos(angle * 4.0 - z_coord * 0.55 + TIME * 1.4);
	float gentle_wave = 0.5 + 0.5 * sin(z_coord * 0.9 - TIME * 2.6 + sin(angle * 2.0) * 1.2);

	float nebula_flow = smoothstep(0.28, 0.88, ribbon_a) * 0.36
		+ smoothstep(0.35, 0.92, ribbon_b) * 0.30
		+ smoothstep(0.45, 0.95, gentle_wave) * 0.18;

	// Плавное бархатное затухание в глубине туннеля и возле камеры
	float edge_fade = smoothstep(0.0, 0.26, UV.y) * smoothstep(1.0, 0.58, UV.y);

	vec3 base_col = mix(primary_color.rgb, secondary_color.rgb, 0.5 + 0.5 * sin(z_coord * 0.25 + angle));
	// Приглушённая глубокая космическая палитра (индиго, бирюза, аметист) без выжигающего белого
	vec3 aurora_col = vec3(0.24, 0.38, 0.62) + vec3(0.18, 0.32, 0.34) * cos(z_coord * 0.32 + angle - TIME * 1.5 + vec3(0.0, 1.8, 3.6));
	vec3 final_col = mix(base_col, aurora_col, rainbow_mode * 0.65);

	// Деликатные мягкие продольные потоки энергии
	float soft_stream = pow(max(0.0, cos(angle * 6.0 + sin(z_coord * 0.45) * 1.4)), 6.0) * 0.25;
	final_col += vec3(0.25, 0.78, 0.95) * soft_stream;

	float alpha = clamp(nebula_flow * edge_fade * tunnel_intensity * 0.46, 0.0, 0.32);
	ALBEDO = final_col * 0.85;
	ALPHA = alpha;
}
