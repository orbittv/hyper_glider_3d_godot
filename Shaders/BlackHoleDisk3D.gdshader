shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 inner_color : source_color = vec4(0.35, 0.98, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(0.88, 0.18, 0.96, 1.0);
uniform float spin_speed : hint_range(0.5, 10.0) = 3.2;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float r = length(centered);
	float angle = atan(centered.y, centered.x);

	// Мягкое кольцо аккреционного диска вокруг горизонта событий
	float inner_edge = smoothstep(0.27, 0.35, r);
	float outer_edge = 1.0 - smoothstep(0.52, 0.96, r);
	float disk_mask = inner_edge * outer_edge;

	// Спиральные вихри затягиваемой материи
	float swirl_a = sin(angle * 5.0 - log(max(r, 0.05)) * 11.0 - TIME * spin_speed * 2.4);
	float swirl_b = cos(angle * 9.0 - r * 18.0 + TIME * spin_speed * 1.8);
	float bands = 0.55 + 0.45 * (swirl_a * 0.6 + swirl_b * 0.4);

	// Острое сияющее фотонное кольцо Эйнштейна на границе горизонта событий + мягкая корона
	float photon_ring = exp(-pow((r - 0.335) * 24.0, 2.0)) * 2.6;
	float outer_corona = exp(-pow((r - 0.42) * 5.5, 2.0)) * 0.45;

	vec3 rainbow_tint = 0.55 + 0.45 * cos(angle * 2.0 - r * 8.0 + TIME * 2.5 + vec3(0.0, 2.1, 4.2));
	vec3 disk_col = mix(inner_color.rgb, outer_color.rgb, clamp((r - 0.28) / 0.62, 0.0, 1.0));
	disk_col = mix(disk_col, rainbow_tint, 0.42);

	vec3 final_col = disk_col * (bands * 1.45 + outer_corona) + vec3(0.94, 0.99, 1.0) * photon_ring;
	float alpha = clamp(disk_mask * (0.42 + bands * 0.55) + photon_ring * 0.88 + outer_corona * inner_edge, 0.0, 1.0);

	ALBEDO = final_col;
	ALPHA = alpha * smoothstep(1.0, 0.86, r);
}
