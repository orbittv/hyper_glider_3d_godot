shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_color_a : source_color = vec4(0.24, 0.94, 1.0, 1.0);
uniform vec4 rim_color_b : source_color = vec4(0.62, 0.18, 0.98, 1.0);
uniform float spin_speed : hint_range(0.5, 8.0) = 2.1;
uniform float quad_half_size = 38.0;

#include "res://Shaders/Noise3DLib.gdshaderinc"

varying vec2 v_center_uv;
varying float v_screen_radius;

void vertex() {
	vec4 center_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	v_center_uv = (center_clip.xy / max(center_clip.w, 0.0001)) * 0.5 + 0.5;
	vec4 edge_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(quad_half_size, 0.0, 0.0, 1.0);
	vec2 edge_uv = (edge_clip.xy / max(edge_clip.w, 0.0001)) * 0.5 + 0.5;
	v_screen_radius = clamp(length(edge_uv - v_center_uv), 0.04, 0.65);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r >= 0.995 || intensity <= 0.005) {
		discard;
	}

	float angle = atan(p.y, p.x);
	float t = TIME * spin_speed;
	vec2 dir2 = p / max(r, 0.0001);

	// 1. Живое гравитационное искажение самого края диска (никакой ровной "вырезанной" окружности!)
	float n1 = noise3(vec3(dir2 * 2.3 + vec2(0.0, t * 0.10), r * 3.4 - t * 0.42));
	float n2 = noise3(vec3(dir2 * 5.2 - vec2(t * 0.16, 0.0), r * 6.4 - t * 0.82));
	float swirl_ang = angle + log(max(r, 0.055)) * 2.9 - t * 0.70;
	float n_swirl = noise3(vec3(cos(swirl_ang) * 2.2, sin(swirl_ang) * 2.2, r * 4.4 - t * 0.60));

	float r_warp = r
		+ (n1 - 0.5) * 0.068
		+ (n_swirl - 0.5) * 0.038
		+ (n2 - 0.5) * 0.018;

	// 2. Реальное гравитационное линзирование пространства на краях диска (SCREEN_TEXTURE)
	vec2 screen_rel = SCREEN_UV - v_center_uv;
	float outer_fade = 1.0 - smoothstep(0.64, 0.97, r);
	float lens_zone = smoothstep(0.96, 0.38, r) * smoothstep(0.20, 0.34, r);

	// Сильный гравитационный изгиб света у кромки горизонта событий + тангенциальное закручивание Керра
	float einstein_pull = clamp(1.0 / (max(r - 0.21, 0.085) * 3.8), 0.0, 2.8) * lens_zone;
	vec2 rad_dir = normalize(screen_rel + vec2(0.00001));
	vec2 tan_dir = vec2(-rad_dir.y, rad_dir.x);

	float ripple = sin(r * 24.0 - t * 2.2 + n1 * 4.5) * 0.22 + (n_swirl - 0.5) * 0.55;
	vec2 distort_vec = (
		rad_dir * (einstein_pull * 0.30 + ripple * lens_zone * 0.065)
		+ tan_dir * (einstein_pull * 0.19 * (0.55 + n_swirl))
	) * v_screen_radius * intensity;

	// Гравитационная хроматическая дисперсия на искривлённом краю диска
	vec2 uv_g = clamp(SCREEN_UV + distort_vec, vec2(0.002), vec2(0.998));
	vec2 uv_r = clamp(SCREEN_UV + distort_vec * 1.18, vec2(0.002), vec2(0.998));
	vec2 uv_b = clamp(SCREEN_UV + distort_vec * 0.82, vec2(0.002), vec2(0.998));

	// Защита по буферу глубины (Reverse-Z в Godot 4 Mobile): не втягиваем в линзу близкий глайдер или сферы
	float d_g = texture(depth_tex, uv_g).r;
	float d_r = texture(depth_tex, uv_r).r;
	float d_b = texture(depth_tex, uv_b).r;
	float fg_guard = step(FRAGCOORD.z + 0.0004, max(d_g, max(d_r, d_b)));

	vec3 raw_bg = texture(screen_tex, SCREEN_UV).rgb;
	vec3 lensed_bg = vec3(
		texture(screen_tex, uv_r).r,
		texture(screen_tex, uv_g).g,
		texture(screen_tex, uv_b).b
	);
	vec3 space_bg = mix(lensed_bg, raw_bg, fg_guard);

	// 3. Глубокая, выразительная темнота Горизонта Событий внутри диска (как при входе в Чёрную дыру!)
	float abyss_core = 1.0 - smoothstep(0.24, 0.345, r_warp);
	float gravity_shadow = (1.0 - smoothstep(0.28, 0.60, r_warp)) * 0.76;
	float darkness = clamp(abyss_core + gravity_shadow * (1.0 - abyss_core), 0.0, 1.0);

	// Внутри центра — чистый глубокий мрак космоса с едва ощутимым дыханием по самому краю бездны
	float inner_whirl = smoothstep(0.14, 0.31, r) * (1.0 - smoothstep(0.28, 0.345, r_warp)) * n_swirl * 0.032;
	vec3 abyss_col = vec3(0.0005, 0.001, 0.003) + rim_color_b.rgb * inner_whirl;

	vec3 col = mix(space_bg, abyss_col, darkness);

	// 4. Фотонное кольцо Эйнштейна + искривлённые гравитационные дуги + втягиваемые потоки пространства
	// Все светящиеся элементы строго снаружи чёрной бездны (outside_core), чтобы центр оставался глубоко тёмным!
	float outside_core = smoothstep(0.26, 0.34, r_warp);

	float doppler = 0.62 + 0.48 * sin(angle - 0.85 + t * 0.30);
	float photon_ring = exp(-pow((r_warp - 0.345) * 32.0, 2.0)) * (0.88 + 0.45 * n2) * doppler;

	// Вторая искажённая гравитационная дуга Эйнштейна (эффект преломления света на краях диска)
	float r_echo = r + (n_swirl - 0.5) * 0.12 + sin(angle * 2.0 - t * 0.65) * 0.032;
	float einstein_arc = exp(-pow((r_echo - 0.46) * 14.0, 2.0)) * (0.38 + 0.62 * n1) * outside_core;

	// Внешняя пульсирующая гравитационная волна-рябь, уходящая в стенки туннеля
	float warp_wave = exp(-pow((r_warp - (0.60 + 0.055 * sin(t * 0.9 + angle * 2.0))) * 9.5, 2.0)) * (0.35 + 0.65 * n_swirl) * outside_core;

	// Логарифмические спирали втягиваемой материи и искривлённого пространства-времени
	float spiral_a = 0.5 + 0.5 * sin(angle * 4.0 - log(max(r, 0.08)) * 9.8 - t * 1.80 + n1 * 2.8);
	float spiral_b = 0.5 + 0.5 * cos(angle * 7.0 - log(max(r, 0.08)) * 14.0 - t * 2.40);
	float spiral_mask = smoothstep(0.30, 0.41, r_warp) * (1.0 - smoothstep(0.52, 0.92, r));
	float accretion_swirl = (pow(spiral_a, 2.4) * 0.56 + pow(spiral_b, 3.2) * 0.36) * spiral_mask;

	// Насыщенная космическая палитра без выжигающего белого пересвета
	vec3 grad_col = mix(rim_color_a.rgb, rim_color_b.rgb, clamp((r - 0.32) / 0.50, 0.0, 1.0));
	vec3 spectral = 0.52 + 0.45 * cos(angle * 2.0 - r * 7.5 + t * 0.85 + vec3(0.0, 2.0, 4.0));
	vec3 ring_col = mix(grad_col, spectral, 0.28);

	float outer_halo = exp(-pow((r - 0.45) * 4.2, 2.0)) * 0.20 * outside_core;

	col += ring_col * (accretion_swirl * 0.62 + einstein_arc * 0.48 + warp_wave * 0.32);
	col += mix(rim_color_a.rgb, vec3(0.92, 0.98, 1.0), 0.55) * photon_ring * 1.02;
	col += rim_color_b.rgb * outer_halo;

	// Полностью бесшовное слияние с окружающим пространством к краям квада (r -> 0.97)
	float effect_coverage = max(darkness, clamp(lens_zone * 0.96 + photon_ring + einstein_arc + accretion_swirl + outer_halo, 0.0, 1.0));
	float final_alpha = clamp(effect_coverage * outer_fade * intensity, 0.0, 1.0);

	ALBEDO = col;
	ALPHA = final_alpha;
}
