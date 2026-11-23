shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 core_color : source_color = vec4(0.88, 0.99, 1.0, 1.0);
uniform vec4 flame_color : source_color = vec4(0.12, 0.86, 1.0, 1.0);
uniform vec4 tail_color : source_color = vec4(0.55, 0.18, 0.98, 1.0);
uniform float thrust_power : hint_range(0.4, 2.5) = 1.0;

void fragment() {
	// В CylinderMesh боковая поверхность использует UV.y в диапазоне [0.0 .. 0.5] от top_radius (сопло) к bottom_radius (хвост факела)
	float along = clamp(UV.y * 2.0, 0.0, 1.0);
	float flicker = 0.88 + 0.12 * sin(TIME * 48.0 + along * 16.0);
	float length_fade = pow(1.0 - along, 1.25);

	vec3 col = mix(core_color.rgb, flame_color.rgb, smoothstep(0.0, 0.42, along));
	col = mix(col, tail_color.rgb, smoothstep(0.40, 0.95, along));

	ALBEDO = col * (1.45 * thrust_power * flicker);
	ALPHA = clamp(length_fade * thrust_power * 0.92, 0.0, 0.95);
}
