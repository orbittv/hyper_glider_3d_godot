shader_type sky;

uniform vec3 nebula_color_a : source_color = vec3(0.03, 0.22, 0.48);
uniform vec3 nebula_color_b : source_color = vec3(0.32, 0.05, 0.46);
uniform vec3 core_color : source_color = vec3(0.18, 0.78, 1.0);
uniform float brightness : hint_range(0.1, 2.0) = 0.85;
uniform float warp_factor : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p = p * 2.04 + vec3(1.7, 9.2, 4.3);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float t = TIME * 0.06 + time_offset;

	// Тёмная глубокая космическая пустота
	vec3 col = vec3(0.004, 0.008, 0.022);

	// Мягкие облака далёких туманностей
	vec3 neb_p = dir * 3.2 + vec3(0.0, 0.0, t * 0.35);
	float n1 = fbm(neb_p);
	float n2 = fbm(neb_p * 1.9 - vec3(t * 0.22, -t * 0.14, 0.0));

	float cloud_a = smoothstep(0.48, 0.88, n1);
	float cloud_b = smoothstep(0.52, 0.90, n2);

	col += nebula_color_a * cloud_a * 0.22;
	col += nebula_color_b * cloud_b * 0.20;

	// Компактное далёкое свечение галактического ядра строго в центре горизонта (-Z)
	float forward_alignment = max(0.0, -dir.z);
	float core_glow = pow(forward_alignment, 32.0) * (0.14 + 0.25 * warp_factor);
	col += core_color * core_glow;

	// Далёкие мерцающие звёзды на небесной сфере
	vec3 star_grid = floor(dir * 240.0);
	float star_rnd = hash31(star_grid);
	if (star_rnd > 0.991) {
		float twinkle = 0.55 + 0.45 * sin(TIME * (3.0 + fract(star_rnd * 91.7) * 7.0) + star_rnd * 100.0);
		float star_intensity = smoothstep(0.991, 1.0, star_rnd) * 95.0 * twinkle;
		vec3 star_tint = mix(vec3(0.75, 0.92, 1.0), vec3(1.0, 0.88, 0.65), fract(star_rnd * 37.3));
		col += star_tint * star_intensity * 0.55;
	}

	// Радужно-неоновые сполохи при гиперпрыжке / гипер-туннеле
	if (warp_factor > 0.01) {
		float angle = atan(dir.y, dir.x);
		float streaks = pow(max(0.0, sin(angle * 10.0 + TIME * 4.0 + dir.z * 14.0)), 6.0);
		vec3 warp_col = 0.5 + 0.5 * cos(TIME * 2.5 + dir.xyx * 3.0 + vec3(0.0, 2.0, 4.0));
		col += warp_col * streaks * warp_factor * 0.32;
	}

	COLOR = col * brightness;
}
