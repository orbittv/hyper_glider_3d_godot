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
var _tunnel_ring_mats: Array[StandardMaterial3D] = []
var _tunnel_ring_base_colors: Array[Color] = []

var _tunnel_singularity_root: Node3D
var _tunnel_singularity_mesh_inst: MeshInstance3D
var _tunnel_singularity_mat: ShaderMaterial
var _tunnel_accretion_disk_inst: MeshInstance3D
var _tunnel_accretion_mat: ShaderMaterial
var _tunnel_void_sphere_inst: MeshInstance3D

var _planets_root: Node3D
var _giant_planet: Node3D
var _giant_planet_mat: ShaderMaterial
var _giant_ring_mat: StandardMaterial3D
var _moon_planet: Node3D
var _moon_planet_mat: ShaderMaterial

var _current_brightness: float = 0.85
var _tunnel_blend: float = 0.0
var _singularity_blend: float = 0.0
var _hyper_blend: float = 0.0
var _sector_index: int = 0
var _warmup_active: bool = false

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
	_setup_distant_planets()
	_setup_hyper_tunnel()
	set_sector_palette(0)


func _setup_world_environment() -> void:
	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
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

	var star_mesh: ArrayMesh = _build_soft_star_mesh()
	_star_multimesh.mesh = star_mesh
	_star_multimesh.instance_count = STAR_COUNT
	_star_multimesh_inst.multimesh = _star_multimesh
	add_child(_star_multimesh_inst)

	_star_positions.resize(STAR_COUNT)
	_star_Colors.resize(STAR_COUNT)
	_star_scales.resize(STAR_COUNT)

	for i: int in range(STAR_COUNT):
		_star_positions[i] = _random_star_position(randf_range(STAR_MIN_Z, STAR_MAX_Z))
		_star_scales[i] = randf_range(0.65, 1.75)
		var tint_choice: float = randf()
		var c: Color
		if tint_choice < 0.55:
			c = Color(0.72, 0.93, 1.0, randf_range(0.50, 0.92))
		elif tint_choice < 0.82:
			c = Color(1.0, 0.90, 0.72, randf_range(0.50, 0.92))
		else:
			c = Color(0.86, 0.65, 1.0, randf_range(0.50, 0.92))
		_star_Colors[i] = c
		_star_multimesh.set_instance_color(i, c)


func _build_soft_star_mesh() -> ArrayMesh:
	# 3 взаимно перпендикулярных квада с мягким радиальным затуханием (StarStreak3D.gdshader):
	# - фронтальный диск XY (всегда круглое мягкое ядро без растяжения по Z),
	# - два продольных луча XZ и YZ (плавно вытягиваются в кометный хвост на гиперскорости)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var r_disc: float = 0.24
	_add_star_quad(
		st,
		Vector3(-r_disc, -r_disc, 0.0),
		Vector3(r_disc, -r_disc, 0.0),
		Vector3(r_disc, r_disc, 0.0),
		Vector3(-r_disc, r_disc, 0.0)
	)

	var r_beam: float = 0.16
	var half_len: float = 0.55
	_add_star_quad(
		st,
		Vector3(-r_beam, 0.0, -half_len),
		Vector3(r_beam, 0.0, -half_len),
		Vector3(r_beam, 0.0, half_len),
		Vector3(-r_beam, 0.0, half_len)
	)
	_add_star_quad(
		st,
		Vector3(0.0, -r_beam, -half_len),
		Vector3(0.0, r_beam, -half_len),
		Vector3(0.0, r_beam, half_len),
		Vector3(0.0, -r_beam, half_len)
	)

	var mesh: ArrayMesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Shaders/StarStreak3D.gdshader") as Shader
	mesh.surface_set_material(0, mat)
	return mesh


func _add_star_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p1)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)

	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(p3)


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
	cyl.radial_segments = 48
	cyl.rings = 32
	cyl.cap_top = false
	cyl.cap_bottom = false

	_hyper_tunnel_mat = ShaderMaterial.new()
	var tunnel_shader := load("res://Shaders/HyperTunnel3D.gdshader") as Shader
	_hyper_tunnel_mat.shader = tunnel_shader
	_hyper_tunnel_mat.render_priority = -2
	_hyper_tunnel_mat.set_shader_parameter("tunnel_intensity", 0.0)
	_hyper_tunnel_mat.set_shader_parameter("tunnel_half_length", 105.0)
	cyl.material = _hyper_tunnel_mat

	_hyper_tunnel_mesh_inst.mesh = cyl
	# Поворачиваем цилиндр вдоль оси Z (полёт сквозь туннель)
	_hyper_tunnel_mesh_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_hyper_tunnel_mesh_inst.position = Vector3(0.0, 0.0, -82.0)
	_hyper_tunnel_mesh_inst.visible = false
	add_child(_hyper_tunnel_mesh_inst)

	# Глубинная сингулярность в конце 3D Гипер-туннеля: бездонная темнота внутри + гравитационное искривление пространства
	_tunnel_singularity_root = Node3D.new()
	_tunnel_singularity_root.position = Vector3(0.0, 0.0, -172.0)
	_tunnel_singularity_root.visible = false
	add_child(_tunnel_singularity_root)

	_tunnel_singularity_mesh_inst = MeshInstance3D.new()
	var sing_quad := QuadMesh.new()
	sing_quad.size = Vector2(76.0, 76.0)
	_tunnel_singularity_mat = ShaderMaterial.new()
	_tunnel_singularity_mat.shader = load("res://Shaders/TunnelSingularity3D.gdshader") as Shader
	_tunnel_singularity_mat.render_priority = -4
	_tunnel_singularity_mat.set_shader_parameter("intensity", 0.0)
	_tunnel_singularity_mat.set_shader_parameter("quad_half_size", 38.0)
	_tunnel_singularity_mesh_inst.mesh = sing_quad
	_tunnel_singularity_mesh_inst.material_override = _tunnel_singularity_mat
	_tunnel_singularity_root.add_child(_tunnel_singularity_mesh_inst)

	# Внутренняя абсолютно чёрная 3D-сфера горизонта событий (спрятана внутри мягкой темноты шейдера,
	# но физически перекрывает заднюю дугу наклонённого аккреционного диска, как у настоящей Чёрной дыры!)
	_tunnel_void_sphere_inst = MeshInstance3D.new()
	var void_sp := SphereMesh.new()
	void_sp.radius = 9.0
	void_sp.height = 18.0
	void_sp.radial_segments = 24
	void_sp.rings = 12
	var void_mat := StandardMaterial3D.new()
	void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	_tunnel_void_sphere_inst.mesh = void_sp
	_tunnel_void_sphere_inst.material_override = void_mat
	_tunnel_void_sphere_inst.visible = false
	_tunnel_singularity_root.add_child(_tunnel_void_sphere_inst)

	# Деликатный наклонённый 3D-аккреционный диск вокруг далёкой сингулярности (перекликается с входной Чёрной дырой)
	_tunnel_accretion_disk_inst = MeshInstance3D.new()
	var acc_quad := QuadMesh.new()
	acc_quad.size = Vector2(76.0, 76.0)
	_tunnel_accretion_mat = ShaderMaterial.new()
	_tunnel_accretion_mat.shader = load("res://Shaders/BlackHoleDisk3D.gdshader") as Shader
	_tunnel_accretion_mat.render_priority = -3
	_tunnel_accretion_mat.set_shader_parameter("spin_speed", 2.0)
	_tunnel_accretion_mat.set_shader_parameter("opacity", 0.0)
	_tunnel_accretion_disk_inst.mesh = acc_quad
	_tunnel_accretion_disk_inst.material_override = _tunnel_accretion_mat
	_tunnel_accretion_disk_inst.rotation_degrees = Vector3(76.0, 11.0, -8.0)
	_tunnel_singularity_root.add_child(_tunnel_accretion_disk_inst)

	# 5 очень тонких и мягких ориентирных колец внутри Гипер-туннеля (без нагрузки на глаза)
	_tunnel_rings_root = Node3D.new()
	_tunnel_rings_root.visible = false
	add_child(_tunnel_rings_root)

	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = 13.75
	torus_mesh.outer_radius = 13.98
	torus_mesh.rings = 32
	torus_mesh.ring_segments = 10

	for i: int in range(5):
		var ring_inst := MeshInstance3D.new()
		ring_inst.mesh = torus_mesh
		var r_mat := StandardMaterial3D.new()
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		r_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		r_mat.render_priority = -1
		var hue: float = fmod(0.52 + float(i) * 0.08, 1.0)
		var base_col := Color.from_hsv(hue, 0.65, 0.85, 0.16)
		r_mat.albedo_color = base_col
		ring_inst.material_override = r_mat
		ring_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		ring_inst.position = Vector3(0.0, 0.0, -24.0 - float(i) * 34.0)
		_tunnel_rings_root.add_child(ring_inst)
		_tunnel_ring_nodes.append(ring_inst)
		_tunnel_ring_mats.append(r_mat)
		_tunnel_ring_base_colors.append(base_col)


func _setup_distant_planets() -> void:
	_planets_root = Node3D.new()
	add_child(_planets_root)

	var planet_shader := load("res://Shaders/Planet3D.gdshader") as Shader

	# 1. Далёкий Газовый Гигант с кольцами на левом-верхнем горизонте
	_giant_planet = Node3D.new()
	_giant_planet.position = Vector3(-34.0, 14.5, -135.0)
	_planets_root.add_child(_giant_planet)

	var giant_sphere := SphereMesh.new()
	giant_sphere.radius = 9.5
	giant_sphere.height = 19.0
	giant_sphere.radial_segments = 28
	giant_sphere.rings = 16

	_giant_planet_mat = ShaderMaterial.new()
	_giant_planet_mat.shader = planet_shader
	var giant_mesh_inst := MeshInstance3D.new()
	giant_mesh_inst.mesh = giant_sphere
	giant_mesh_inst.material_override = _giant_planet_mat
	_giant_planet.add_child(giant_mesh_inst)

	# Наклонённое планетарное кольцо вокруг Газового Гиганта
	var p_ring_mesh := TorusMesh.new()
	p_ring_mesh.inner_radius = 12.8
	p_ring_mesh.outer_radius = 17.6
	p_ring_mesh.rings = 32
	p_ring_mesh.ring_segments = 8

	_giant_ring_mat = StandardMaterial3D.new()
	_giant_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_giant_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_giant_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_giant_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_giant_ring_mat.albedo_color = Color(0.24, 0.78, 1.0, 0.24)

	var p_ring_inst := MeshInstance3D.new()
	p_ring_inst.mesh = p_ring_mesh
	p_ring_inst.material_override = _giant_ring_mat
	p_ring_inst.rotation_degrees = Vector3(68.0, 24.0, -18.0)
	p_ring_inst.scale = Vector3(1.0, 0.08, 1.0)
	_giant_planet.add_child(p_ring_inst)

	# 2. Вторая далёкая экзопланета-спутник на правом фланге
	_moon_planet = Node3D.new()
	_moon_planet.position = Vector3(36.0, -9.5, -165.0)
	_planets_root.add_child(_moon_planet)

	var moon_sphere := SphereMesh.new()
	moon_sphere.radius = 5.2
	moon_sphere.height = 10.4
	moon_sphere.radial_segments = 22
	moon_sphere.rings = 12

	_moon_planet_mat = ShaderMaterial.new()
	_moon_planet_mat.shader = planet_shader
	var moon_mesh_inst := MeshInstance3D.new()
	moon_mesh_inst.mesh = moon_sphere
	moon_mesh_inst.material_override = _moon_planet_mat
	_moon_planet.add_child(moon_mesh_inst)


func set_brightness(val: float) -> void:
	_current_brightness = clampf(val, 0.30, 1.40)
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("brightness", _current_brightness)


func set_high_quality_mode(enabled: bool) -> void:
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.glow_enabled = enabled
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.msaa_3d = Viewport.MSAA_2X if enabled else Viewport.MSAA_DISABLED


func set_sector_palette(sector_idx: int) -> void:
	_sector_index = posmod(sector_idx, SECTOR_PALETTES.size())
	var pal: Dictionary = SECTOR_PALETTES[_sector_index]
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("nebula_color_a", pal["neb_a"])
		_sky_mat.set_shader_parameter("nebula_color_b", pal["neb_b"])
		_sky_mat.set_shader_parameter("core_color", pal["core"])
	if _rim_light != null:
		_rim_light.light_color = pal["core"]
	if _giant_planet_mat != null:
		_giant_planet_mat.set_shader_parameter("band_color_a", Color(pal["neb_a"]).lightened(0.18))
		_giant_planet_mat.set_shader_parameter("band_color_b", Color(pal["neb_b"]).lightened(0.12))
		_giant_planet_mat.set_shader_parameter("atmo_color", pal["core"])
	if _giant_ring_mat != null:
		var rc: Color = pal["core"]
		_giant_ring_mat.albedo_color = Color(rc.r, rc.g, rc.b, 0.22)
	if _moon_planet_mat != null:
		_moon_planet_mat.set_shader_parameter("band_color_a", Color(pal["neb_b"]).lightened(0.20))
		_moon_planet_mat.set_shader_parameter("band_color_b", Color(pal["neb_a"]).darkened(0.15))
		_moon_planet_mat.set_shader_parameter("atmo_color", Color(pal["core"]).lightened(0.15))
	if _hyper_tunnel_mat != null:
		_hyper_tunnel_mat.set_shader_parameter("primary_color", Color(pal["core"]).darkened(0.18))
		_hyper_tunnel_mat.set_shader_parameter("secondary_color", Color(pal["neb_b"]).lightened(0.22))
	if _tunnel_singularity_mat != null:
		_tunnel_singularity_mat.set_shader_parameter("rim_color_a", Color(pal["core"]))
		_tunnel_singularity_mat.set_shader_parameter("rim_color_b", Color(pal["neb_b"]).lightened(0.32))
	if _tunnel_accretion_mat != null:
		_tunnel_accretion_mat.set_shader_parameter("inner_color", Color(pal["core"]))
		_tunnel_accretion_mat.set_shader_parameter("outer_color", Color(pal["neb_b"]).lightened(0.38))


func set_tunnel_warmup(active: bool) -> void:
	_warmup_active = active
	if active:
		if _hyper_tunnel_mesh_inst != null and _hyper_tunnel_mat != null:
			_hyper_tunnel_mesh_inst.visible = true
			_hyper_tunnel_mat.set_shader_parameter("tunnel_intensity", 0.02)
		if _tunnel_singularity_root != null and _tunnel_singularity_mat != null:
			_tunnel_singularity_root.visible = true
			_tunnel_singularity_mat.set_shader_parameter("intensity", 0.02)
			if _tunnel_accretion_mat != null:
				_tunnel_accretion_mat.set_shader_parameter("opacity", 0.02)
	else:
		if _hyper_tunnel_mesh_inst != null and _tunnel_blend <= 0.01:
			_hyper_tunnel_mesh_inst.visible = false
		if _tunnel_singularity_root != null and _singularity_blend <= 0.01:
			_tunnel_singularity_root.visible = false


func get_current_sector_name() -> String:
	var pal: Dictionary = SECTOR_PALETTES[posmod(_sector_index, SECTOR_PALETTES.size())]
	return String(pal["name"])


func update_environment(delta: float, forward_speed: float, is_hyper: bool, is_tunnel: bool) -> void:
	var target_tunnel: float = 1.0 if is_tunnel else (0.35 if is_hyper else 0.0)
	_tunnel_blend = move_toward(_tunnel_blend, target_tunnel, delta * 2.2)

	var target_singularity: float = 1.0 if is_tunnel else 0.0
	_singularity_blend = move_toward(_singularity_blend, target_singularity, delta * 2.0)

	var target_hyper: float = 1.0 if (is_hyper or is_tunnel) else 0.0
	_hyper_blend = move_toward(_hyper_blend, target_hyper, delta * 2.5)

	if _sky_mat != null:
		_sky_mat.set_shader_parameter("warp_factor", _hyper_blend)
		_sky_mat.set_shader_parameter("tunnel_factor", _singularity_blend)

	if _hyper_tunnel_mesh_inst != null and _hyper_tunnel_mat != null and not _warmup_active:
		_hyper_tunnel_mesh_inst.visible = _tunnel_blend > 0.01
		_hyper_tunnel_mat.set_shader_parameter("tunnel_intensity", _tunnel_blend)
		_hyper_tunnel_mat.set_shader_parameter("rainbow_mode", 0.65 if is_tunnel else 0.25)
		_hyper_tunnel_mat.set_shader_parameter("scroll_speed", 2.4 if is_tunnel else 1.8)

	if _tunnel_singularity_root != null and _tunnel_singularity_mat != null and not _warmup_active:
		var show_sing: bool = _singularity_blend > 0.01
		_tunnel_singularity_root.visible = show_sing
		if show_sing:
			_tunnel_singularity_mat.set_shader_parameter("intensity", _singularity_blend)
			if _tunnel_void_sphere_inst != null:
				var sp_scale: float = smoothstep(0.22, 0.96, _singularity_blend)
				_tunnel_void_sphere_inst.visible = sp_scale > 0.02
				_tunnel_void_sphere_inst.scale = Vector3.ONE * maxf(0.05, sp_scale)
			if _tunnel_accretion_mat != null:
				_tunnel_accretion_mat.set_shader_parameter("opacity", _singularity_blend * 0.24)
			if _tunnel_accretion_disk_inst != null:
				_tunnel_accretion_disk_inst.rotation.z += delta * 0.24

	if _tunnel_rings_root != null:
		_tunnel_rings_root.visible = is_tunnel or _tunnel_blend > 0.45
		if _tunnel_rings_root.visible:
			var ring_speed: float = forward_speed * 0.95
			for i: int in range(_tunnel_ring_nodes.size()):
				var rn: MeshInstance3D = _tunnel_ring_nodes[i]
				rn.position.z += ring_speed * delta
				if rn.position.z > 14.0:
					rn.position.z -= 170.0
				# Согласуем радиус и прозрачность колец с гравитационной воронкой туннеля (строго перпендикулярно оси Z)
				var depth_t: float = clampf((23.0 - rn.position.z) / 210.0, 0.0, 1.0)
				var funnel: float = smoothstep(0.38, 1.0, depth_t)
				var r_scale: float = lerpf(1.0, 0.56, funnel * funnel)
				rn.scale = Vector3(r_scale, 1.0, r_scale)
				var far_fade: float = clampf((rn.position.z + 168.0) / 48.0, 0.0, 1.0)
				var near_fade: float = clampf((14.0 - rn.position.z) / 18.0, 0.0, 1.0)
				var base_c: Color = _tunnel_ring_base_colors[i]
				_tunnel_ring_mats[i].albedo_color = Color(base_c.r, base_c.g, base_c.b, base_c.a * far_fade * near_fade * _tunnel_blend)

	# Медленный величественный параллакс далёких 3D-планет на горизонте
	if _planets_root != null:
		_planets_root.visible = not is_tunnel
		if _giant_planet != null:
			_giant_planet.position.z += forward_speed * 0.14 * delta
			_giant_planet.rotation.y += delta * 0.06
			if _giant_planet.position.z > 28.0:
				_giant_planet.position = Vector3(randf_range(-38.0, -28.0), randf_range(10.0, 18.0), -185.0)
		if _moon_planet != null:
			_moon_planet.position.z += forward_speed * 0.19 * delta
			_moon_planet.rotation.y -= delta * 0.09
			if _moon_planet.position.z > 28.0:
				_moon_planet.position = Vector3(randf_range(28.0, 40.0), randf_range(-13.0, -6.0), -195.0)

	# Обновляем 3D-поток мелькающих звёзд (в Гипер-туннеле умеренное растяжение без ослепляющих полос)
	var star_speed: float = forward_speed * (1.65 if is_tunnel else (1.55 if is_hyper else 1.15))
	var streak_len: float = lerpf(1.2, 3.8 if is_tunnel else 6.0, _hyper_blend) + clampf((forward_speed - 38.0) * 0.05, 0.0, 2.5)

	for i: int in range(STAR_COUNT):
		var pos: Vector3 = _star_positions[i]
		pos.z += star_speed * delta
		if pos.z > STAR_MAX_Z:
			pos = _random_star_position(STAR_MIN_Z - randf_range(0.0, 20.0))
		_star_positions[i] = pos

		var s: float = _star_scales[i]
		var star_basis := Basis.from_scale(Vector3(s, s, s * streak_len))
		_star_multimesh.set_instance_transform(i, Transform3D(star_basis, pos))
