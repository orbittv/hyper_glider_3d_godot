shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 inner_color : source_color = vec4(0.35, 0.98, 1.0, 1.0);
uniform vec4 outer_color : source_color = vec4(0.88, 0.18, 0.96, 1.0);
uniform float spin_speed : hint_range(0.5, 10.0) = 3.2;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float r = length(centered);
	float angle = atan(centered.y, centered.x);

	// Кольцо аккреционного диска вокруг горизонта событий
	float inner_edge = smoothstep(0.26, 0.36, r);
	float outer_edge = 1.0 - smoothstep(0.58, 0.98, r);
	float disk_mask = inner_edge * outer_edge;

	// Спиральные вихри затягиваемой материи
	float swirl_a = sin(angle * 5.0 - log(max(r, 0.05)) * 11.0 - TIME * spin_speed * 2.4);
	float swirl_b = cos(angle * 9.0 - r * 18.0 + TIME * spin_speed * 1.8);
	float bands = 0.55 + 0.45 * (swirl_a * 0.6 + swirl_b * 0.4);

	// Яркое фотонное кольцо на границе горизонта событий
	float photon_ring = exp(-pow((r - 0.33) * 18.0, 2.0)) * 2.2;

	vec3 rainbow_tint = 0.55 + 0.45 * cos(angle * 2.0 - r * 8.0 + TIME * 2.5 + vec3(0.0, 2.1, 4.2));
	vec3 disk_col = mix(inner_color.rgb, outer_color.rgb, clamp((r - 0.28) / 0.65, 0.0, 1.0));
	disk_col = mix(disk_col, rainbow_tint, 0.42);

	vec3 final_col = disk_col * (bands * 1.45) + vec3(0.92, 0.99, 1.0) * photon_ring;
	float alpha = clamp(disk_mask * (0.45 + bands * 0.55) + photon_ring * 0.85, 0.0, 1.0);

	ALBEDO = final_col;
	ALPHA = alpha * smoothstep(1.0, 0.88, r);
}
