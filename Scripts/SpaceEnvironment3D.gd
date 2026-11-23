class_name SpaceEnvironment3D
extends Node3D

## 3D-окружение космоса: WorldEnvironment с процедурным шейдером туманностей и далёких звёзд,
## 3D-поток мелькающих мимо глайдера звёзд (MultiMeshInstance3D с растяжением в варп-линии)
## и огромный цилиндрический 3D Гипер-туннель (HyperTunnel3D.gdshader) для пролёта сквозь Чёрную дыру.

const STAR_COUNT: int = 340
const STAR_MIN_Z: float = -185.0
const STAR_MAX_Z: float = 16.0
const STAR_SPREAD_X: float = 34.0
const STAR_SPREAD_Y: float = 34.0

var _world_env: WorldEnvironment
var _sky_mat: ShaderMaterial
var _sun_light: DirectionalLight3D
var _rim_light: DirectionalLight3D

var _star_multimesh_inst: MultiMeshInstance3D
var _star_multimesh: MultiMesh
var _star_positions: PackedVector3Array = PackedVector3Array()
var _star_Colors: PackedColorArray = PackedColorArray()
var _star_scales: PackedFloat32Array = PackedFloat32Array()

var _hyper_tunnel_mesh_inst: MeshInstance3D
var _hyper_tunnel_mat: ShaderMaterial
var _tunnel_rings_root: Node3D
var _tunnel_ring_nodes: Array[MeshInstance3D] = []

var _current_brightness: float = 0.85
var _tunnel_blend: float = 0.0
var _hyper_blend: float = 0.0
var _sector_index: int = 0

# Цветовые темы секторов глубокого космоса
const SECTOR_PALETTES: Array[Dictionary] = [
	{
		"name": "СЕКТОР I: КВАНТОВАЯ БЕЗДНА",
		"neb_a": Color(0.03, 0.24, 0.52),
		"neb_b": Color(0.34, 0.05, 0.48),
		"core": Color(0.18, 0.82, 1.0)
	},
	{
		"name": "СЕКТОР II: ИЗУМРУДНЫЙ ПОЯС",
		"neb_a": Color(0.02, 0.42, 0.34),
		"neb_b": Color(0.08, 0.22, 0.56),
		"core": Color(0.22, 1.0, 0.72)
	},
	{
		"name": "СЕКТОР III: БАГРОВЫЙ КВАЗАР",
		"neb_a": Color(0.48, 0.06, 0.24),
		"neb_b": Color(0.24, 0.04, 0.48),
		"core": Color(1.0, 0.35, 0.58)
	},
	{
		"name": "СЕКТОР IV: ЗОЛОТАЯ СВЕРХНОВАЯ",
		"neb_a": Color(0.46, 0.26, 0.04),
		"neb_b": Color(0.44, 0.08, 0.36),
		"core": Color(1.0, 0.78, 0.24)
	}
]


func _ready() -> void:
	_setup_world_environment()
	_setup_lighting()
	_setup_3d_starfield()
	_setup_hyper_tunnel()


func _setup_world_environment() -> void:
	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	_sky_mat = ShaderMaterial.new()
	var sky_shader := load("res://Shaders/SpaceSky.gdshader") as Shader
	_sky_mat.shader = sky_shader
	sky.sky_material = _sky_mat
	env.sky = sky

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.24, 0.40)
	env.ambient_light_energy = 1.05

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0

	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.92
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	_world_env.environment = env
	add_child(_world_env)
	set_sector_palette(0)


func _setup_lighting() -> void:
	_sun_light = DirectionalLight3D.new()
	_sun_light.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	_sun_light.light_color = Color(0.92, 0.96, 1.0)
	_sun_light.light_energy = 1.45
	_sun_light.shadow_enabled = false
	add_child(_sun_light)

	_rim_light = DirectionalLight3D.new()
	_rim_light.rotation_degrees = Vector3(24.0, 145.0, 0.0)
	_rim_light.light_color = Color(0.28, 0.78, 1.0)
	_rim_light.light_energy = 0.75
	_rim_light.shadow_enabled = false
	add_child(_rim_light)


func _setup_3d_starfield() -> void:
	_star_multimesh_inst = MultiMeshInstance3D.new()
	_star_multimesh = MultiMesh.new()
	_star_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_star_multimesh.use_colors = true

	var box := BoxMesh.new()
	box.size = Vector3(0.11, 0.11, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	box.material = mat

	_star_multimesh.mesh = box
	_star_multimesh.instance_count = STAR_COUNT
	_star_multimesh_inst.multimesh = _star_multimesh
	add_child(_star_multimesh_inst)

	_star_positions.resize(STAR_COUNT)
	_star_Colors.resize(STAR_COUNT)
	_star_scales.resize(STAR_COUNT)

	for i: int in range(STAR_COUNT):
		_star_positions[i] = _random_star_position(randf_range(STAR_MIN_Z, STAR_MAX_Z))
		_star_scales[i] = randf_range(0.65, 1.85)
		var tint_choice: float = randf()
		var c: Color
		if tint_choice < 0.55:
			c = Color(0.75, 0.94, 1.0, randf_range(0.55, 0.95))
		elif tint_choice < 0.82:
			c = Color(1.0, 0.92, 0.76, randf_range(0.55, 0.95))
		else:
			c = Color(0.88, 0.65, 1.0, randf_range(0.55, 0.95))
		_star_Colors[i] = c
		_star_multimesh.set_instance_color(i, c)


func _random_star_position(z_val: float) -> Vector3:
	var x: float = randf_range(-STAR_SPREAD_X, STAR_SPREAD_X)
	var y: float = randf_range(-STAR_SPREAD_Y, STAR_SPREAD_Y)
	# Оставляем центральный коридор чуть менее забитым близкими звёздами, чтобы не слепить прицел
	if absf(x) < 3.2 and absf(y) < 3.2:
		x += signf(x if x != 0.0 else 1.0) * 4.0
	return Vector3(x, y, z_val)


func _setup_hyper_tunnel() -> void:
	_hyper_tunnel_mesh_inst = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 15.5
	cyl.bottom_radius = 15.5
	cyl.height = 210.0
	cyl.radial_segments = 36
	cyl.rings = 16
	cyl.cap_top = false
	cyl.cap_bottom = false

	_hyper_tunnel_mat = ShaderMaterial.new()
	var tunnel_shader := load("res://Shaders/HyperTunnel3D.gdshader") as Shader
	_hyper_tunnel_mat.shader = tunnel_shader
	_hyper_tunnel_mat.set_shader_parameter("tunnel_intensity", 0.0)
	cyl.material = _hyper_tunnel_mat

	_hyper_tunnel_mesh_inst.mesh = cyl
	# Поворачиваем цилиндр вдоль оси Z (полёт сквозь туннель)
	_hyper_tunnel_mesh_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_hyper_tunnel_mesh_inst.position = Vector3(0.0, 0.0, -82.0)
	_hyper_tunnel_mesh_inst.visible = false
	add_child(_hyper_tunnel_mesh_inst)

	# Дополнительные 3D неоновые портальные кольца внутри Гипер-туннеля
	_tunnel_rings_root = Node3D.new()
	_tunnel_rings_root.visible = false
	add_child(_tunnel_rings_root)

	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 12.2
	torus_mesh.outer_radius = 13.0
	torus_mesh.rings = 28
	torus_mesh.ring_segments = 12

	for i: int in range(10):
		var ring_inst := MeshInstance3D.new()
		ring_inst.mesh = torus_mesh
		var r_mat := StandardMaterial3D.new()
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var hue: float = fmod(float(i) * 0.12, 1.0)
		r_mat.albedo_color = Color.from_hsv(hue, 0.78, 1.0, 0.65)
		ring_inst.material_override = r_mat
		ring_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		ring_inst.position = Vector3(0.0, 0.0, -18.0 - float(i) * 18.0)
		_tunnel_rings_root.add_child(ring_inst)
		_tunnel_ring_nodes.append(ring_inst)


func set_brightness(val: float) -> void:
	_current_brightness = clampf(val, 0.30, 1.40)
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("brightness", _current_brightness)


func set_sector_palette(sector_idx: int) -> void:
	_sector_index = posmod(sector_idx, SECTOR_PALETTES.size())
	var pal: Dictionary = SECTOR_PALETTES[_sector_index]
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("nebula_color_a", pal["neb_a"])
		_sky_mat.set_shader_parameter("nebula_color_b", pal["neb_b"])
		_sky_mat.set_shader_parameter("core_color", pal["core"])
	if _rim_light != null:
		_rim_light.light_color = pal["core"]


func get_current_sector_name() -> String:
	var pal: Dictionary = SECTOR_PALETTES[posmod(_sector_index, SECTOR_PALETTES.size())]
	return String(pal["name"])


func update_environment(delta: float, forward_speed: float, is_hyper: bool, is_tunnel: bool) -> void:
	var target_tunnel: float = 1.0 if is_tunnel else (0.35 if is_hyper else 0.0)
	_tunnel_blend = move_toward(_tunnel_blend, target_tunnel, delta * 2.2)

	var target_hyper: float = 1.0 if (is_hyper or is_tunnel) else 0.0
	_hyper_blend = move_toward(_hyper_blend, target_hyper, delta * 2.5)

	if _sky_mat != null:
		_sky_mat.set_shader_parameter("warp_factor", _hyper_blend)

	if _hyper_tunnel_mesh_inst != null and _hyper_tunnel_mat != null:
		_hyper_tunnel_mesh_inst.visible = _tunnel_blend > 0.01
		_hyper_tunnel_mat.set_shader_parameter("tunnel_intensity", _tunnel_blend)
		_hyper_tunnel_mat.set_shader_parameter("rainbow_mode", 1.0 if is_tunnel else 0.35)
		_hyper_tunnel_mat.set_shader_parameter("scroll_speed", 5.2 if is_tunnel else 3.2)

	if _tunnel_rings_root != null:
		_tunnel_rings_root.visible = is_tunnel or _tunnel_blend > 0.45
		if _tunnel_rings_root.visible:
			var ring_speed: float = forward_speed * 1.45
			for i: int in range(_tunnel_ring_nodes.size()):
				var rn: MeshInstance3D = _tunnel_ring_nodes[i]
				rn.position.z += ring_speed * delta
				rn.rotation.y += delta * (1.2 if i % 2 == 0 else -1.2)
				if rn.position.z > 14.0:
					rn.position.z -= 180.0

	# Обновляем 3D-поток мелькающих звёзд
	var star_speed: float = forward_speed * (2.2 if is_tunnel else (1.75 if is_hyper else 1.15))
	var streak_len: float = lerpf(1.2, 8.5, _hyper_blend) + clampf((forward_speed - 38.0) * 0.08, 0.0, 4.0)

	for i: int in range(STAR_COUNT):
		var pos: Vector3 = _star_positions[i]
		pos.z += star_speed * delta
		if pos.z > STAR_MAX_Z:
			pos = _random_star_position(STAR_MIN_Z - randf_range(0.0, 20.0))
		_star_positions[i] = pos

		var s: float = _star_scales[i]
		var basis := Basis.from_scale(Vector3(s, s, s * streak_len))
		_star_multimesh.set_instance_transform(i, Transform3D(basis, pos))
