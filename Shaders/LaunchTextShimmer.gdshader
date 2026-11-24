shader_type canvas_item;

// Перелив букв слева направо синхронно с диагональным лучом кнопки (раз в 2.4 сек с паузой)
uniform float box_width = 456.0;
uniform float cycle_period = 2.4;
uniform float sweep_duration = 1.05;

varying float v_norm_x;

void vertex() {
	v_norm_x = clamp(VERTEX.x / max(box_width, 1.0), 0.0, 1.0);
	float cycle_t = mod(TIME, cycle_period);
	if (cycle_t < sweep_duration) {
		float phase = cycle_t / sweep_duration;
		float center_x = mix(0.10, 0.90, phase);
		float wave = smoothstep(0.14, 0.0, abs(v_norm_x - center_x)) * sin(phase * 3.14159265);
		VERTEX.y -= wave * 1.35;
	}
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 col = tex * COLOR;

	float cycle_t = mod(TIME, cycle_period);
	float wave = 0.0;
	if (cycle_t < sweep_duration) {
		float phase = cycle_t / sweep_duration;
		float center_x = mix(0.10, 0.90, phase);
		float dist = abs(v_norm_x - center_x);
		wave = smoothstep(0.15, 0.0, dist) * sin(phase * 3.14159265);
	}

	float is_fill = step(0.35, max(COLOR.r, max(COLOR.g, COLOR.b)));
	if (is_fill > 0.5) {
		vec3 base_tint = mix(vec3(0.92, 1.0, 0.98), vec3(0.98, 1.0, 1.0), v_norm_x);
		vec3 shimmer_tint = vec3(1.0, 0.98, 0.82);
		col.rgb = mix(base_tint, shimmer_tint, wave * 0.90) + vec3(0.22, 0.38, 0.35) * wave;
	} else {
		col.rgb = mix(col.rgb, vec3(0.08, 0.68, 0.62), wave * 0.72);
	}

	COLOR = col;
}
