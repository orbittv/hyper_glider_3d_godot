shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never;

uniform float tunnel_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float scroll_speed : hint_range(0.5, 10.0) = 3.5;
uniform vec4 primary_color : source_color = vec4(0.15, 0.92, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.95, 0.22, 0.88, 1.0);
uniform float rainbow_mode : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// UV.x — вокруг окружности цилиндра [0..1], UV.y — вдоль длины туннеля [0..1]
	float angle = UV.x * 6.2831853;
	float z_coord = UV.y * 26.0 + TIME * scroll_speed * 4.0;

	// Спиральные энергетические полосы гипер-туннеля
	float spiral_a = sin(angle * 6.0 + z_coord * 1.4 - TIME * 5.0);
	float spiral_b = cos(angle * 10.0 - z_coord * 2.1 + TIME * 7.5);
	float rings = sin(z_coord * 3.2 - TIME * 12.0);

	float energy_grid = smoothstep(0.55, 0.98, spiral_a * 0.5 + 0.5) * 0.65
		+ smoothstep(0.68, 0.99, spiral_b * 0.5 + 0.5) * 0.55
		+ smoothstep(0.76, 0.995, rings * 0.5 + 0.5) * 0.85;

	// Плавное затухание у ближнего и дальнего краёв цилиндра
	float edge_fade = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.72, UV.y);

	vec3 base_col = mix(primary_color.rgb, secondary_color.rgb, 0.5 + 0.5 * sin(z_coord * 0.35 + angle));
	vec3 rainbow_col = 0.55 + 0.45 * cos(z_coord * 0.45 + angle * 2.0 - TIME * 3.5 + vec3(0.0, 2.1, 4.2));
	vec3 final_col = mix(base_col, rainbow_col, rainbow_mode);

	// Яркие продольные варп-молнии
	float lightning = pow(max(0.0, cos(angle * 16.0 + sin(z_coord * 0.8) * 2.5)), 12.0);
	final_col += vec3(0.85, 0.98, 1.0) * lightning * 1.3;

	float alpha = clamp(energy_grid * edge_fade * tunnel_intensity, 0.0, 0.92);
	ALBEDO = final_col * (1.35 + lightning);
	ALPHA = alpha;
}
