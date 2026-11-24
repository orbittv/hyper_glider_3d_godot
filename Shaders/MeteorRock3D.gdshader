shader_type spatial;

uniform vec3 base_rock_color : source_color = vec3(0.36, 0.30, 0.27);
uniform vec3 ridge_color : source_color = vec3(0.62, 0.56, 0.52);
uniform vec3 rim_color : source_color = vec3(0.22, 0.78, 1.0);
uniform vec3 crack_color : source_color = vec3(0.18, 1.0, 0.52);
uniform float crack_intensity : hint_range(0.0, 3.0) = 0.0;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.15;
uniform float roughness_val : hint_range(0.05, 1.0) = 0.82;

varying vec3 v_local_pos;
varying float v_radial_h;

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i);
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}

void vertex() {
	v_local_pos = VERTEX;
	v_radial_h = length(VERTEX);
}

void fragment() {
	// Рельефная окраска: впадины кратеров темнее, острые хребты светлее
	float radial_h = v_radial_h;
	float detail_n = noise3(v_local_pos * 4.5);
	float ridge_t = smoothstep(0.84, 1.18, radial_h + (detail_n - 0.5) * 0.16);
	vec3 rock_col = mix(base_rock_color * 0.55, ridge_color, ridge_t);

	ALBEDO = rock_col;
	METALLIC = metallic_val;
	ROUGHNESS = roughness_val;

	// Контровой Fresnel-контур, чтобы силуэт 3D-метеорита объёмно читался на фоне тёмного космоса
	float fresnel = pow(1.0 - max(0.0, dot(NORMAL, VIEW)), 3.2);
	vec3 emis = rim_color * fresnel * 0.48;

	// Пульсирующие плазменные/магматические трещины внутри породы (для метеоритов-бомб и кристаллов)
	if (crack_intensity > 0.01) {
		float vein_a = abs(noise3(v_local_pos * 3.4) - 0.5) * 2.0;
		float vein_b = abs(noise3(v_local_pos * 6.8 + vec3(2.1)) - 0.5) * 2.0;
		float crack_mask = smoothstep(0.24, 0.02, vein_a * 0.7 + vein_b * 0.3);
		float deep_glow = smoothstep(1.02, 0.78, radial_h) * 0.65;
		float pulse = 0.78 + 0.22 * sin(TIME * 7.5 + radial_h * 6.0);
		emis += crack_color * (crack_mask * 1.85 + deep_glow) * crack_intensity * pulse;
	}

	EMISSION = emis;
}
