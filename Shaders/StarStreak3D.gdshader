shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

varying float v_world_z;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_z = world_pos.z;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float r = sqrt(r2);

	// Полное затухание к границам квада (r >= 1.0 -> 0.0), никаких квадратных краёв!
	float soft_core = exp(-r2 * 10.5) * smoothstep(1.0, 0.25, r);
	float soft_halo = pow(max(0.0, 1.0 - r), 2.5) * 0.46;

	// Плавное проявление звёзд из тёмной бездны космоса и мягкое угасание возле камеры
	float far_fade = smoothstep(-185.0, -95.0, v_world_z);
	float near_fade = 1.0 - smoothstep(6.0, 16.0, v_world_z);

	float intensity = (soft_core * 1.55 + soft_halo) * far_fade * near_fade;
	ALBEDO = mix(COLOR.rgb, vec3(1.0), soft_core * 0.72) * 1.35;
	ALPHA = clamp(intensity * COLOR.a, 0.0, 1.0);
}
