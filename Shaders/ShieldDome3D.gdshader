shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 shield_color : source_color = vec4(0.20, 0.92, 1.0, 0.45);
uniform float intensity : hint_range(0.0, 1.5) = 0.35;

void fragment() {
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.6);
	float scan_wave = 0.65 + 0.35 * sin(UV.y * 28.0 - TIME * 9.0 + sin(UV.x * 18.0) * 1.5);
	float grid_band = smoothstep(0.65, 0.98, abs(sin(UV.y * 22.0 + UV.x * 22.0)));

	float mask = (fresnel * 1.25 + grid_band * 0.14) * scan_wave;
	ALBEDO = shield_color.rgb * (1.25 + fresnel * 0.6);
	ALPHA = clamp(mask * shield_color.a * intensity, 0.0, 0.82);
}
