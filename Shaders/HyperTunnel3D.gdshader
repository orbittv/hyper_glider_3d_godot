shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never;

uniform float tunnel_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float scroll_speed : hint_range(0.5, 10.0) = 2.2;
uniform vec4 primary_color : source_color = vec4(0.08, 0.58, 0.86, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.42, 0.14, 0.76, 1.0);
uniform float rainbow_mode : hint_range(0.0, 1.0) = 0.65;
uniform float tunnel_half_length = 105.0;

varying float v_depth_t;
varying vec2 v_radial_dir;

void vertex() {
	// В локальном CylinderMesh Y идёт от +half_len (у камеры) до -half_len (дальний конец туннеля).
	// Используем геометрический depth_t [0..1] вместо UV.y, т.к. у CylinderMesh боковая UV.y = [0..0.5]!
	float depth_t = clamp((tunnel_half_length - VERTEX.y) / (tunnel_half_length * 2.0), 0.0, 1.0);
	v_depth_t = depth_t;
	v_radial_dir = normalize(VERTEX.xz + vec2(0.00001));
	float v_ang = atan(v_radial_dir.y, v_radial_dir.x);

	// Плавная гравитационная воронка: в глубине туннель органично сужается и слегка дышит гравитационными волнами
	float funnel = smoothstep(0.38, 1.0, depth_t);
	float radial_scale = mix(1.0, 0.56, funnel * funnel);
	float grav_wave = sin(depth_t * 15.0 - TIME * 3.4 + v_ang * 3.0) * 0.048 * funnel;
	VERTEX.xz *= (radial_scale + grav_wave);
}

void fragment() {
	// Спиральная гравитационная закрутка потоков по мере приближения к сингулярности в конце туннеля
	float grav_twist = pow(v_depth_t, 2.1) * 3.4;
	float angle = atan(v_radial_dir.y, v_radial_dir.x) + grav_twist;
	float z_coord = v_depth_t * 14.0 - TIME * scroll_speed * 2.2;

	// Мягкие широкие волны туманности (aurora-потоки) без резких концентрических колец и стробоскопа
	float ribbon_a = 0.5 + 0.5 * sin(angle * 3.0 + z_coord * 0.72 - TIME * 1.6);
	float ribbon_b = 0.5 + 0.5 * cos(angle * 4.0 - z_coord * 0.58 + TIME * 1.3);
	float gentle_wave = 0.5 + 0.5 * sin(z_coord * 0.92 - TIME * 2.4 + sin(angle * 2.0) * 1.25);

	float nebula_flow = smoothstep(0.26, 0.88, ribbon_a) * 0.38
		+ smoothstep(0.34, 0.92, ribbon_b) * 0.30
		+ smoothstep(0.44, 0.95, gentle_wave) * 0.20;

	// Плавное бархатное затухание у камеры (0..0.18) И полное бесшовное растворение в глубине (0.64..0.98)
	// Гарантированно убирает любую видимую "вырезанную окружность" дальнего среза цилиндра!
	float near_fade = smoothstep(0.0, 0.18, v_depth_t);
	float far_fade = smoothstep(0.98, 0.62, v_depth_t);
	float edge_fade = near_fade * far_fade;

	vec3 base_col = mix(primary_color.rgb, secondary_color.rgb, 0.5 + 0.5 * sin(z_coord * 0.25 + angle));
	// Приглушённая глубокая космическая палитра (индиго, бирюза, аметист) без выжигающего белого
	vec3 aurora_col = vec3(0.22, 0.36, 0.62) + vec3(0.18, 0.32, 0.34) * cos(z_coord * 0.32 + angle - TIME * 1.4 + vec3(0.0, 1.8, 3.6));
	vec3 final_col = mix(base_col, aurora_col, rainbow_mode * 0.65);

	// Деликатные продольные потоки энергии, закручивающиеся в чёрную дыру
	float soft_stream = pow(max(0.0, cos(angle * 6.0 + sin(z_coord * 0.48) * 1.45)), 6.0) * 0.28;
	final_col += vec3(0.25, 0.80, 0.98) * soft_stream;

	// Глубинное затемнение ближе к горизонту событий
	float depth_shade = mix(1.0, 0.72, smoothstep(0.45, 0.92, v_depth_t));

	float alpha = clamp(nebula_flow * edge_fade * tunnel_intensity * 0.46, 0.0, 0.32);
	ALBEDO = final_col * 0.85 * depth_shade;
	ALPHA = alpha;
}
