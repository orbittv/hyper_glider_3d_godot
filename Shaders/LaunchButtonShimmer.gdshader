shader_type canvas_item;

// Насыщенный неоновый градиент (бирюзово-изумрудный -> яркий циан)
// + диагональный световой луч раз в 2.4 сек с паузой + мягкое дыхание свечения рамки.
uniform vec2 rect_size = vec2(456.0, 64.0);
uniform float corner_radius = 14.0;
uniform float cycle_period = 2.4;
uniform float sweep_duration = 1.05;
uniform vec4 col_emerald : source_color = vec4(0.02, 0.54, 0.44, 0.98);
uniform vec4 col_turquoise : source_color = vec4(0.03, 0.68, 0.72, 0.98);
uniform vec4 col_cyan : source_color = vec4(0.06, 0.78, 0.96, 0.98);

float rounded_box_sdf(vec2 p, vec2 b, float r) {
	vec2 d = abs(p) - b + vec2(r);
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 p = UV * rect_size - half_size;
	float sdf = rounded_box_sdf(p, half_size, corner_radius);

	// Антиалиасинг скруглённых углов
	float mask = 1.0 - smoothstep(-1.2, 0.5, sdf);

	// 1. Базовый насыщенный градиент: бирюзово-изумрудный -> лазурный -> яркий циан
	float grad_t = clamp(UV.x * 0.85 + (1.0 - UV.y) * 0.15, 0.0, 1.0);
	vec3 base_col = mix(col_emerald.rgb, col_turquoise.rgb, smoothstep(0.0, 0.55, grad_t));
	base_col = mix(base_col, col_cyan.rgb, smoothstep(0.45, 1.0, grad_t));

	// Верхний стеклянный блик и объёмная глубина снизу
	float top_sheen = smoothstep(0.48, 0.0, UV.y) * 0.18;
	float bot_shade = smoothstep(0.55, 1.0, UV.y) * 0.14;
	base_col += vec3(0.35, 0.95, 0.90) * top_sheen;
	base_col *= (1.0 - bot_shade);

	// 2. Едва заметное «дыхание» внутреннего неонового контура
	float breath = 0.5 + 0.5 * sin(TIME * 2.2);
	float inner_rim = smoothstep(-9.0, 0.0, sdf);
	vec3 rim_glow = mix(vec3(0.20, 0.95, 0.82), vec3(0.55, 1.0, 1.0), UV.x);
	base_col += rim_glow * inner_rim * (0.20 + 0.14 * breath);

	// 3. Эффектный диагональный световой луч раз в 2.4 сек с паузой (чтобы не мельтешил)
	float cycle_t = mod(TIME, cycle_period);
	if (cycle_t < sweep_duration) {
		float phase = cycle_t / sweep_duration;
		// Луч пробегает по диагонали слева направо
		float beam_pos = mix(-0.35, 1.45, phase);
		float diag_coord = UV.x + (UV.y - 0.5) * 0.36;
		float dist = abs(diag_coord - beam_pos);

		float core_beam = smoothstep(0.075, 0.0, dist);
		float wide_halo = smoothstep(0.22, 0.0, dist);
		// Плавное затухание на входе и выходе луча
		float env = sin(phase * 3.14159265);
		vec3 beam_col = mix(vec3(0.45, 1.0, 0.94), vec3(0.95, 1.0, 1.0), core_beam);
		base_col += beam_col * (core_beam * 0.42 + wide_halo * 0.18) * env;
	}

	COLOR = vec4(base_col, mask * 0.98);
}
