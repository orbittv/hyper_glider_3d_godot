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

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
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
	float n101 = hash31(i + vec3(1.0, 0.0, 0.0) + vec3(0.0, 0.0, 1.0));
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

// Мягкий слой круглых звёзд с радиальным гауссовым ореолом внутри 3D-ячейки (без квадратных краёв!)
vec3 soft_star_layer(vec3 dir, float grid_scale, float density_threshold, float sharpness, float time_val) {
	vec3 p = dir * grid_scale;
	vec3 cell = floor(p);
	vec3 rnd = hash33(cell);
	if (rnd.x < density_threshold) {
		return vec3(0.0);
	}
	// Случайное смещение центра звезды строго внутри ячейки [0.24 .. 0.76], чтобы ореол не обрезался границей ячейки
	vec3 star_center = vec3(0.24) + fract(rnd * vec3(13.7, 29.3, 47.1)) * 0.52;
	vec3 diff = fract(p) - star_center;
	float dist = length(diff);

	// Мягкое круглое ядро + плавная корона с полным затуханием к краям ячейки
	float edge_guard = 1.0 - smoothstep(0.16, 0.24, dist);
	float core = exp(-dist * dist * sharpness);
	float halo = exp(-dist * dist * (sharpness * 0.22)) * 0.32;

	float twinkle = 0.68 + 0.32 * sin(time_val * (2.2 + rnd.y * 5.0) + rnd.z * 62.8);
	float brightness_var = smoothstep(density_threshold, 1.0, rnd.x);

	vec3 cold_tint = vec3(0.72, 0.90, 1.0);
	vec3 warm_tint = vec3(1.0, 0.88, 0.68);
	vec3 violet_tint = vec3(0.88, 0.70, 1.0);
	vec3 tint = mix(cold_tint, warm_tint, rnd.y);
	tint = mix(tint, violet_tint, smoothstep(0.75, 1.0, rnd.z) * 0.55);

	return tint * (core + halo) * edge_guard * (0.45 + brightness_var * 1.15) * twinkle;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float t = TIME * 0.06 + time_offset;

	// Тёмная глубокая космическая пустота
	vec3 col = vec3(0.003, 0.007, 0.020);

	// Мягкие облака далёких туманностей и диагональная лента Млечного Пути
	vec3 neb_p = dir * 3.1 + vec3(0.0, 0.0, t * 0.32);
	float n1 = fbm(neb_p);
	float n2 = fbm(neb_p * 1.9 - vec3(t * 0.20, -t * 0.14, 0.0));

	float cloud_a = smoothstep(0.46, 0.88, n1);
	float cloud_b = smoothstep(0.50, 0.90, n2);

	float galactic_plane = exp(-pow((dir.x * 0.58 + dir.y * 0.81) * 3.4 + (n1 - 0.5) * 0.9, 2.0));
	col += nebula_color_a * (cloud_a * 0.22 + galactic_plane * 0.11);
	col += nebula_color_b * (cloud_b * 0.20 + galactic_plane * n2 * 0.10);

	// Компактное далёкое свечение галактического ядра впереди по курсу (-Z)
	float forward_alignment = max(0.0, -dir.z);
	float core_glow = pow(forward_alignment, 28.0) * (0.15 + 0.26 * warp_factor);
	col += core_color * core_glow;

	// Рендерим мягкие круглые звёзды только на экранном фоне (!AT_CUBEMAP_PASS), избегая пикселизации кубмапы
	if (!AT_CUBEMAP_PASS) {
		// Слой 1: россыпь мягкой мелкой звёздной пыли
		col += soft_star_layer(dir, 96.0, 0.86, 175.0, TIME) * 0.68;
		// Слой 2: более крупные яркие звёзды с мягким гауссовым ореолом
		col += soft_star_layer(dir + vec3(0.37, 0.19, 0.53), 46.0, 0.92, 115.0, TIME) * 1.15;
	}

	// Мягкое глубокое свечение туманности при гиперпрыжке / гипер-туннеле (без резких лучей)
	if (warp_factor > 0.01) {
		float angle = atan(dir.y, dir.x);
		float soft_aurora = 0.5 + 0.5 * sin(angle * 3.0 + TIME * 1.4 + dir.z * 4.0);
		vec3 warp_col = mix(nebula_color_a, core_color, soft_aurora);
		col += warp_col * warp_factor * 0.14;
	}

	COLOR = col * brightness;
}
