class_name SpaceEntity3D
extends Node3D

## 3D-объекты глубокого космоса, летящие навстречу глайдеру:
## - Процедурные 3D-метеориты (каменные, кристаллические, нестабильные зелёные и золотые плазменные метеориты-бомбы)
## - Энергетические 3D-сферы, капсулы Грави-Щита и 4 вида спецоружия
## - Гигантская 3D Чёрная дыра с горизонтом событий, фотонным гало и аккреционным диском (BlackHoleDisk3D.gdshader)

enum Kind {
	METEOR_ROCK,
	METEOR_PLASMA_GREEN,
	METEOR_PLASMA_GOLD,
	METEOR_CRYSTAL,
	ORB_ENERGY,
	ORB_HYPER_CORE,
	ORB_SHIELD,
	ORB_WEAPON_PLASMA,
	ORB_WEAPON_VULCAN,
	ORB_WEAPON_LASER,
	ORB_WEAPON_MISSILE,
	ORB_QUANTUM_CRYSTAL,
	BLACK_HOLE_PORTAL,
	ENEMY_INTERCEPTOR,
	ENEMY_BOSS_3D
}

var kind: Kind = Kind.METEOR_ROCK
var radius: float = 1.6
var max_hp: float = 40.0
var hp: float = 40.0
var score_value: int = 50
var crystal_value: int = 1
var velocity: Vector3 = Vector3(0.0, 0.0, 42.0)
var rot_speed: Vector3 = Vector3(1.0, 1.4, 0.7)
var grazed: bool = false
var is_destroyed: bool = false
var age: float = 0.0
var boss_title: String = ""
var boss_enraged: bool = false
var fire_cooldown: float = 1.4
var fire_interval: float = 1.6
var spawn_origin_xy: Vector2 = Vector2.ZERO
var attack_counter: int = 0

var _visual_root: Node3D
var _rock_mesh_inst: MeshInstance3D
var _plasma_core_inst: MeshInstance3D
var _ring_inst: MeshInstance3D
var _hit_flash_timer: float = 0.0
var _base_rock_mat: Material

# Статический кэш процедурно сгенерированных 3D-скал и материалов
static var _rock_meshes: Array[ArrayMesh] = []
static var _mat_rock_brown: ShaderMaterial
static var _mat_rock_slate: ShaderMaterial
static var _mat_rock_crystal: ShaderMaterial
static var _mat_rock_bomb_green: ShaderMaterial
static var _mat_rock_bomb_gold: ShaderMaterial
static var _mat_hit_flash: StandardMaterial3D
static var _mat_plasma_green_core: StandardMaterial3D
static var _mat_plasma_gold_core: StandardMaterial3D
static var _mat_black_hole_void: StandardMaterial3D
static var _mat_black_hole_disk: ShaderMaterial
static var _mat_enemy_hull: StandardMaterial3D
static var _mat_enemy_neon: StandardMaterial3D
static var _mat_boss_core: StandardMaterial3D
static var _mat_quantum_crystal: StandardMaterial3D
static var _mat_quantum_crystal_halo: StandardMaterial3D
static var _orb_materials: Dictionary = {}

static var _orb_sphere_mesh: SphereMesh
static var _orb_ring_mesh: TorusMesh
static var _crystal_octa_mesh: ArrayMesh
static var _bh_void_mesh: SphereMesh
static var _bh_disk_mesh: QuadMesh
static var _enemy_body_mesh: BoxMesh
static var _enemy_wing_mesh: BoxMesh

const WEAPON_ORB_KINDS: Array[Kind] = [
	Kind.ORB_WEAPON_PLASMA,
	Kind.ORB_WEAPON_VULCAN,
	Kind.ORB_WEAPON_LASER,
	Kind.ORB_WEAPON_MISSILE
]


static func pick_random_weapon_orb_kind() -> Kind:
	return WEAPON_ORB_KINDS[randi() % WEAPON_ORB_KINDS.size()]


static func clear_static_caches() -> void:
	_rock_meshes.clear()
	_orb_materials.clear()
	_mat_rock_brown = null
	_mat_rock_slate = null
	_mat_rock_crystal = null
	_mat_rock_bomb_green = null
	_mat_rock_bomb_gold = null
	_mat_hit_flash = null
	_mat_plasma_green_core = null
	_mat_plasma_gold_core = null
	_mat_black_hole_void = null
	_mat_black_hole_disk = null
	_mat_enemy_hull = null
	_mat_enemy_neon = null
	_mat_boss_core = null
	_mat_quantum_crystal = null
	_mat_quantum_crystal_halo = null
	_orb_sphere_mesh = null
	_orb_ring_mesh = null
	_crystal_octa_mesh = null
	_bh_void_mesh = null
	_bh_disk_mesh = null
	_enemy_body_mesh = null
	_enemy_wing_mesh = null


static func _ensure_shared_assets() -> void:
	if not _rock_meshes.is_empty():
		return

	# Генерируем 8 уникальных гранёных 3D-мешей метеоритов с кратерами и хребтами
	for i: int in range(8):
		_rock_meshes.append(_generate_procedural_asteroid_mesh(101 + i * 73))

	var rock_shader := load("res://Shaders/MeteorRock3D.gdshader") as Shader

	_mat_rock_brown = ShaderMaterial.new()
	_mat_rock_brown.shader = rock_shader
	_mat_rock_brown.set_shader_parameter("base_rock_color", Color(0.32, 0.25, 0.22))
	_mat_rock_brown.set_shader_parameter("ridge_color", Color(0.64, 0.54, 0.48))
	_mat_rock_brown.set_shader_parameter("rim_color", Color(0.28, 0.80, 1.0))
	_mat_rock_brown.set_shader_parameter("crack_intensity", 0.0)
	_mat_rock_brown.set_shader_parameter("metallic_val", 0.14)
	_mat_rock_brown.set_shader_parameter("roughness_val", 0.84)

	_mat_rock_slate = ShaderMaterial.new()
	_mat_rock_slate.shader = rock_shader
	_mat_rock_slate.set_shader_parameter("base_rock_color", Color(0.22, 0.27, 0.36))
	_mat_rock_slate.set_shader_parameter("ridge_color", Color(0.52, 0.60, 0.74))
	_mat_rock_slate.set_shader_parameter("rim_color", Color(0.38, 0.86, 1.0))
	_mat_rock_slate.set_shader_parameter("crack_intensity", 0.0)
	_mat_rock_slate.set_shader_parameter("metallic_val", 0.34)
	_mat_rock_slate.set_shader_parameter("roughness_val", 0.68)

	_mat_rock_crystal = ShaderMaterial.new()
	_mat_rock_crystal.shader = rock_shader
	_mat_rock_crystal.set_shader_parameter("base_rock_color", Color(0.14, 0.45, 0.72))
	_mat_rock_crystal.set_shader_parameter("ridge_color", Color(0.52, 0.94, 1.0))
	_mat_rock_crystal.set_shader_parameter("rim_color", Color(0.65, 0.45, 1.0))
	_mat_rock_crystal.set_shader_parameter("crack_color", Color(0.24, 0.96, 1.0))
	_mat_rock_crystal.set_shader_parameter("crack_intensity", 0.95)
	_mat_rock_crystal.set_shader_parameter("metallic_val", 0.78)
	_mat_rock_crystal.set_shader_parameter("roughness_val", 0.22)

	_mat_rock_bomb_green = ShaderMaterial.new()
	_mat_rock_bomb_green.shader = rock_shader
	_mat_rock_bomb_green.set_shader_parameter("base_rock_color", Color(0.14, 0.24, 0.18))
	_mat_rock_bomb_green.set_shader_parameter("ridge_color", Color(0.38, 0.54, 0.44))
	_mat_rock_bomb_green.set_shader_parameter("rim_color", Color(0.22, 1.0, 0.56))
	_mat_rock_bomb_green.set_shader_parameter("crack_color", Color(0.18, 1.0, 0.48))
	_mat_rock_bomb_green.set_shader_parameter("crack_intensity", 1.75)
	_mat_rock_bomb_green.set_shader_parameter("metallic_val", 0.22)
	_mat_rock_bomb_green.set_shader_parameter("roughness_val", 0.65)

	_mat_rock_bomb_gold = ShaderMaterial.new()
	_mat_rock_bomb_gold.shader = rock_shader
	_mat_rock_bomb_gold.set_shader_parameter("base_rock_color", Color(0.28, 0.18, 0.12))
	_mat_rock_bomb_gold.set_shader_parameter("ridge_color", Color(0.62, 0.44, 0.30))
	_mat_rock_bomb_gold.set_shader_parameter("rim_color", Color(1.0, 0.72, 0.18))
	_mat_rock_bomb_gold.set_shader_parameter("crack_color", Color(1.0, 0.62, 0.12))
	_mat_rock_bomb_gold.set_shader_parameter("crack_intensity", 1.95)
	_mat_rock_bomb_gold.set_shader_parameter("metallic_val", 0.26)
	_mat_rock_bomb_gold.set_shader_parameter("roughness_val", 0.62)

	_mat_hit_flash = StandardMaterial3D.new()
	_mat_hit_flash.albedo_color = Color(0.78, 0.90, 1.0)
	_mat_hit_flash.roughness = 0.32
	_mat_hit_flash.metallic = 0.45
	_mat_hit_flash.emission_enabled = true
	_mat_hit_flash.emission = Color(0.42, 0.82, 1.0)
	_mat_hit_flash.emission_energy_multiplier = 1.15

	_mat_plasma_green_core = StandardMaterial3D.new()
	_mat_plasma_green_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plasma_green_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_plasma_green_core.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_plasma_green_core.albedo_color = Color(0.18, 1.0, 0.52, 0.72)

	_mat_plasma_gold_core = StandardMaterial3D.new()
	_mat_plasma_gold_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plasma_gold_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_plasma_gold_core.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_plasma_gold_core.albedo_color = Color(1.0, 0.68, 0.14, 0.76)

	_mat_black_hole_void = StandardMaterial3D.new()
	_mat_black_hole_void.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_black_hole_void.albedo_color = Color(0.0, 0.0, 0.0, 1.0)

	_mat_black_hole_disk = ShaderMaterial.new()
	var bh_shader := load("res://Shaders/BlackHoleDisk3D.gdshader") as Shader
	_mat_black_hole_disk.shader = bh_shader

	_orb_sphere_mesh = SphereMesh.new()
	_orb_sphere_mesh.radius = 0.52
	_orb_sphere_mesh.height = 1.04
	_orb_sphere_mesh.radial_segments = 14
	_orb_sphere_mesh.rings = 8

	_orb_ring_mesh = TorusMesh.new()
	_orb_ring_mesh.inner_radius = 0.72
	_orb_ring_mesh.outer_radius = 0.84
	_orb_ring_mesh.rings = 18
	_orb_ring_mesh.ring_segments = 8

	_bh_void_mesh = SphereMesh.new()
	_bh_void_mesh.radius = 2.65
	_bh_void_mesh.height = 5.30
	_bh_void_mesh.radial_segments = 24
	_bh_void_mesh.rings = 14

	_bh_disk_mesh = QuadMesh.new()
	_bh_disk_mesh.size = Vector2(15.5, 15.5)

	_enemy_body_mesh = BoxMesh.new()
	_enemy_body_mesh.size = Vector3(1.1, 0.45, 2.2)

	_enemy_wing_mesh = BoxMesh.new()
	_enemy_wing_mesh.size = Vector3(3.1, 0.12, 0.95)

	_mat_enemy_hull = StandardMaterial3D.new()
	_mat_enemy_hull.albedo_color = Color(0.18, 0.08, 0.16)
	_mat_enemy_hull.metallic = 0.82
	_mat_enemy_hull.roughness = 0.25

	_mat_enemy_neon = StandardMaterial3D.new()
	_mat_enemy_neon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_enemy_neon.albedo_color = Color(1.0, 0.22, 0.45)

	_mat_boss_core = StandardMaterial3D.new()
	_mat_boss_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_boss_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_boss_core.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_boss_core.albedo_color = Color(1.0, 0.26, 0.52, 0.90)

	_crystal_octa_mesh = _generate_octahedron_crystal_mesh()

	_mat_quantum_crystal = StandardMaterial3D.new()
	_mat_quantum_crystal.albedo_color = Color(0.24, 0.94, 1.0, 0.95)
	_mat_quantum_crystal.metallic = 0.75
	_mat_quantum_crystal.roughness = 0.14
	_mat_quantum_crystal.emission_enabled = true
	_mat_quantum_crystal.emission = Color(0.32, 0.88, 1.0)
	_mat_quantum_crystal.emission_energy_multiplier = 1.65

	_mat_quantum_crystal_halo = StandardMaterial3D.new()
	_mat_quantum_crystal_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_quantum_crystal_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_quantum_crystal_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_quantum_crystal_halo.albedo_color = Color(0.55, 0.42, 1.0, 0.82)

	var orb_colors: Dictionary = {
		Kind.ORB_ENERGY: Color(0.20, 0.92, 1.0, 0.95),
		Kind.ORB_HYPER_CORE: Color(0.95, 0.25, 1.0, 0.98),
		Kind.ORB_SHIELD: Color(0.20, 1.0, 0.65, 0.98),
		Kind.ORB_WEAPON_PLASMA: Color(0.28, 1.0, 0.45, 0.98),
		Kind.ORB_WEAPON_VULCAN: Color(1.0, 0.84, 0.22, 0.98),
		Kind.ORB_WEAPON_LASER: Color(0.25, 0.96, 1.0, 0.98),
		Kind.ORB_WEAPON_MISSILE: Color(1.0, 0.36, 0.28, 0.98),
		Kind.ORB_QUANTUM_CRYSTAL: Color(0.36, 0.96, 1.0, 0.98)
	}
	_orb_materials.clear()
	for k: Kind in orb_colors.keys():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = orb_colors[k]
		_orb_materials[k] = m


static func _generate_octahedron_crystal_mesh() -> ArrayMesh:
	var top := Vector3(0.0, 0.88, 0.0)
	var bot := Vector3(0.0, -0.88, 0.0)
	var ring: Array[Vector3] = [
		Vector3(0.56, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.56),
		Vector3(-0.56, 0.0, 0.0),
		Vector3(0.0, 0.0, -0.56)
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(4):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		var n_top: Vector3 = (b - top).cross(a - top).normalized()
		st.set_normal(n_top)
		st.add_vertex(top)
		st.set_normal(n_top)
		st.add_vertex(a)
		st.set_normal(n_top)
		st.add_vertex(b)

		var n_bot: Vector3 = (a - bot).cross(b - bot).normalized()
		st.set_normal(n_bot)
		st.add_vertex(bot)
		st.set_normal(n_bot)
		st.add_vertex(b)
		st.set_normal(n_bot)
		st.add_vertex(a)
	return st.commit()


static func _generate_procedural_asteroid_mesh(seed_val: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.95
	noise.fractal_octaves = 3

	var crater_noise := FastNoiseLite.new()
	crater_noise.seed = seed_val + 999
	crater_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	crater_noise.frequency = 1.25

	var lat_steps: int = 9
	var lon_steps: int = 14

	# Предвычисляем деформированную сетку вершин на единичной сфере
	var grid: Array = []
	for lat_i: int in range(lat_steps + 1):
		var v: float = float(lat_i) / float(lat_steps)
		var phi: float = v * PI
		var sin_phi: float = sin(phi)
		var cos_phi: float = cos(phi)

		var row: PackedVector3Array = PackedVector3Array()
		row.resize(lon_steps)
		for lon_i: int in range(lon_steps):
			var u: float = float(lon_i) / float(lon_steps)
			var theta: float = u * TAU
			var dir := Vector3(sin_phi * cos(theta), cos_phi, sin_phi * sin(theta))
			if lat_i == 0:
				dir = Vector3.UP
			elif lat_i == lat_steps:
				dir = Vector3.DOWN

			var n1: float = noise.get_noise_3dv(dir * 1.45)
			var n2: float = crater_noise.get_noise_3dv(dir * 1.35)
			var disp: float = 1.0 + n1 * 0.28 - maxf(0.0, n2 + 0.25) * 0.22
			# Лёгкая асимметрия формы валуна
			var stretch := Vector3(1.08, 0.88, 1.02)
			row[lon_i] = dir * disp * stretch
		grid.append(row)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for lat_i: int in range(lat_steps):
		var row_curr: PackedVector3Array = grid[lat_i]
		var row_next: PackedVector3Array = grid[lat_i + 1]
		for lon_i: int in range(lon_steps):
			var next_lon: int = (lon_i + 1) % lon_steps
			var p00: Vector3 = row_curr[lon_i]
			var p10: Vector3 = row_curr[next_lon]
			var p01: Vector3 = row_next[lon_i]
			var p11: Vector3 = row_next[next_lon]

			if lat_i > 0:
				var n_a: Vector3 = (p01 - p00).cross(p10 - p00).normalized()
				st.set_normal(n_a)
				st.add_vertex(p00)
				st.set_normal(n_a)
				st.add_vertex(p10)
				st.set_normal(n_a)
				st.add_vertex(p01)

			if lat_i < lat_steps - 1:
				var n_b: Vector3 = (p01 - p10).cross(p11 - p10).normalized()
				st.set_normal(n_b)
				st.add_vertex(p10)
				st.set_normal(n_b)
				st.add_vertex(p11)
				st.set_normal(n_b)
				st.add_vertex(p01)

	return st.commit()


static func get_shared_rock_mesh(idx: int) -> ArrayMesh:
	_ensure_shared_assets()
	return _rock_meshes[posmod(idx, _rock_meshes.size())]


func setup_entity(
	p_kind: Kind,
	start_pos: Vector3,
	forward_vel_z: float,
	scale_radius: float = 1.6,
	wave_num: int = 1
) -> void:
	_ensure_shared_assets()
	kind = p_kind
	position = start_pos
	radius = scale_radius
	velocity = Vector3(randf_range(-1.2, 1.2), randf_range(-0.9, 0.9), forward_vel_z)
	rot_speed = Vector3(
		randf_range(-1.8, 1.8),
		randf_range(-2.2, 2.2),
		randf_range(-1.5, 1.5)
	)

	_visual_root = Node3D.new()
	add_child(_visual_root)

	var hp_wave_mult: float = 1.0 + float(maxi(0, wave_num - 1)) * 0.14

	match kind:
		Kind.METEOR_ROCK:
			max_hp = (22.0 + radius * 18.0) * hp_wave_mult
			hp = max_hp
			score_value = int(round(35.0 + radius * 25.0))
			_build_meteor_visual(0)
		Kind.METEOR_PLASMA_GREEN:
			max_hp = (32.0 + radius * 20.0) * hp_wave_mult
			hp = max_hp
			score_value = 140
			_build_meteor_visual(1)
		Kind.METEOR_PLASMA_GOLD:
			max_hp = (45.0 + radius * 24.0) * hp_wave_mult
			hp = max_hp
			score_value = 210
			_build_meteor_visual(2)
		Kind.METEOR_CRYSTAL:
			max_hp = (38.0 + radius * 22.0) * hp_wave_mult
			hp = max_hp
			score_value = 180
			_build_meteor_visual(3)
		Kind.BLACK_HOLE_PORTAL:
			radius = 4.6
			velocity = Vector3(0.0, 0.0, forward_vel_z * 0.78)
			score_value = 500
			_build_black_hole_visual()
		Kind.ENEMY_INTERCEPTOR:
			radius = 1.65
			max_hp = 52.0 * hp_wave_mult
			hp = max_hp
			score_value = 190
			spawn_origin_xy = Vector2(start_pos.x, start_pos.y)
			velocity = Vector3(0.0, 0.0, forward_vel_z * 0.76)
			fire_interval = maxf(0.95, 1.75 - float(wave_num) * 0.06)
			fire_cooldown = randf_range(0.55, 1.15)
			_build_interceptor_visual()
		Kind.ENEMY_BOSS_3D:
			radius = 3.85
			max_hp = (460.0 + float(wave_num) * 110.0)
			hp = max_hp
			score_value = 1200
			boss_title = "ДРЕДНОУТ «ЯДРО ОМЕГА-3D»" if (wave_num % 6 == 0) else "КРЕЙСЕР «ТИТАН-3D»"
			spawn_origin_xy = Vector2(0.0, 1.2)
			velocity = Vector3(0.0, 0.0, forward_vel_z * 0.85)
			fire_interval = 1.45
			fire_cooldown = 1.2
			_build_boss_3d_visual()
		Kind.ORB_QUANTUM_CRYSTAL:
			radius = 1.0
			velocity = Vector3(randf_range(-2.2, 2.2), randf_range(-1.6, 1.6), forward_vel_z * 0.9)
			score_value = 60
			_build_quantum_crystal_visual()
		_:
			radius = 1.15
			velocity = Vector3(0.0, 0.0, forward_vel_z * 0.88)
			score_value = 90
			_build_orb_visual()


func _build_meteor_visual(variant_type: int) -> void:
	_rock_mesh_inst = MeshInstance3D.new()
	_rock_mesh_inst.mesh = _rock_meshes[randi() % _rock_meshes.size()]
	_rock_mesh_inst.scale = Vector3.ONE * radius

	if variant_type == 1:
		_base_rock_mat = _mat_rock_bomb_green
	elif variant_type == 2:
		_base_rock_mat = _mat_rock_bomb_gold
	elif variant_type == 3:
		_base_rock_mat = _mat_rock_crystal
	elif randi() % 2 == 0:
		_base_rock_mat = _mat_rock_brown
	else:
		_base_rock_mat = _mat_rock_slate

	_rock_mesh_inst.material_override = _base_rock_mat
	_visual_root.add_child(_rock_mesh_inst)

	# Если это нестабильный плазменный метеорит-бомба, добавляем орбитальное плазменное кольцо вокруг раскалённой породы
	if variant_type == 1 or variant_type == 2:
		var core_mat: StandardMaterial3D = _mat_plasma_green_core if variant_type == 1 else _mat_plasma_gold_core
		_ring_inst = MeshInstance3D.new()
		_ring_inst.mesh = _orb_ring_mesh
		_ring_inst.material_override = core_mat
		_ring_inst.rotation_degrees = Vector3(68.0, 18.0, 0.0)
		_ring_inst.scale = Vector3.ONE * (radius * 1.52)
		_visual_root.add_child(_ring_inst)


func _build_orb_visual() -> void:
	var mat_orb: StandardMaterial3D = _orb_materials.get(kind, _orb_materials.get(Kind.ORB_ENERGY)) as StandardMaterial3D

	_plasma_core_inst = MeshInstance3D.new()
	_plasma_core_inst.mesh = _orb_sphere_mesh
	_plasma_core_inst.material_override = mat_orb
	_plasma_core_inst.scale = Vector3.ONE * 1.15
	_visual_root.add_child(_plasma_core_inst)

	_ring_inst = MeshInstance3D.new()
	_ring_inst.mesh = _orb_ring_mesh
	_ring_inst.material_override = mat_orb
	_ring_inst.rotation_degrees = Vector3(68.0, 0.0, 0.0)
	_ring_inst.scale = Vector3.ONE * 1.25
	_visual_root.add_child(_ring_inst)


func _build_quantum_crystal_visual() -> void:
	_plasma_core_inst = MeshInstance3D.new()
	_plasma_core_inst.mesh = _crystal_octa_mesh
	_plasma_core_inst.material_override = _mat_quantum_crystal
	_plasma_core_inst.scale = Vector3.ONE * 0.95
	_visual_root.add_child(_plasma_core_inst)

	var halo := MeshInstance3D.new()
	halo.mesh = _orb_sphere_mesh
	halo.material_override = _mat_quantum_crystal_halo
	halo.scale = Vector3.ONE * 1.05
	_visual_root.add_child(halo)


func _build_black_hole_visual() -> void:
	# 1. Чёрная сфера Горизонта Событий
	var void_sphere := MeshInstance3D.new()
	void_sphere.mesh = _bh_void_mesh
	void_sphere.material_override = _mat_black_hole_void
	_visual_root.add_child(void_sphere)

	# 2. Наклонённый вращающийся Аккреционный Диск
	var disk_a := MeshInstance3D.new()
	disk_a.mesh = _bh_disk_mesh
	disk_a.material_override = _mat_black_hole_disk
	disk_a.rotation_degrees = Vector3(72.0, 14.0, 0.0)
	_visual_root.add_child(disk_a)

	# 3. Фотонное кольцо гравитационного линзирования (обращённое к камере)
	_ring_inst = MeshInstance3D.new()
	_ring_inst.mesh = _bh_disk_mesh
	_ring_inst.material_override = _mat_black_hole_disk
	_ring_inst.scale = Vector3(0.84, 0.84, 0.84)
	_visual_root.add_child(_ring_inst)


func _build_interceptor_visual() -> void:
	_base_rock_mat = _mat_enemy_hull
	_rock_mesh_inst = MeshInstance3D.new()
	_rock_mesh_inst.mesh = _enemy_body_mesh
	_rock_mesh_inst.material_override = _mat_enemy_hull
	_visual_root.add_child(_rock_mesh_inst)

	var wings := MeshInstance3D.new()
	wings.mesh = _enemy_wing_mesh
	wings.material_override = _mat_enemy_hull
	wings.position = Vector3(0.0, 0.0, -0.2)
	_visual_root.add_child(wings)

	var neon_bar := MeshInstance3D.new()
	neon_bar.mesh = _enemy_wing_mesh
	neon_bar.material_override = _mat_enemy_neon
	neon_bar.scale = Vector3(0.96, 0.45, 0.22)
	neon_bar.position = Vector3(0.0, 0.05, 0.32)
	_visual_root.add_child(neon_bar)

	_plasma_core_inst = MeshInstance3D.new()
	_plasma_core_inst.mesh = _orb_sphere_mesh
	_plasma_core_inst.material_override = _mat_boss_core
	_plasma_core_inst.scale = Vector3.ONE * 0.85
	_plasma_core_inst.position = Vector3(0.0, 0.14, 0.25)
	_visual_root.add_child(_plasma_core_inst)


func _build_boss_3d_visual() -> void:
	_base_rock_mat = _mat_enemy_hull
	_rock_mesh_inst = MeshInstance3D.new()
	_rock_mesh_inst.mesh = _enemy_body_mesh
	_rock_mesh_inst.material_override = _mat_enemy_hull
	_rock_mesh_inst.scale = Vector3(3.2, 2.4, 2.6)
	_visual_root.add_child(_rock_mesh_inst)

	var boss_wings := MeshInstance3D.new()
	boss_wings.mesh = _enemy_wing_mesh
	boss_wings.material_override = _mat_enemy_hull
	boss_wings.scale = Vector3(2.5, 2.2, 2.2)
	_visual_root.add_child(boss_wings)

	_plasma_core_inst = MeshInstance3D.new()
	_plasma_core_inst.mesh = _orb_sphere_mesh
	_plasma_core_inst.material_override = _mat_boss_core
	_plasma_core_inst.scale = Vector3.ONE * 2.8
	_visual_root.add_child(_plasma_core_inst)

	_ring_inst = MeshInstance3D.new()
	_ring_inst.mesh = _orb_ring_mesh
	_ring_inst.material_override = _mat_enemy_neon
	_ring_inst.scale = Vector3.ONE * 4.2
	_visual_root.add_child(_ring_inst)


func is_meteor() -> bool:
	return (
		kind == Kind.METEOR_ROCK
		or kind == Kind.METEOR_PLASMA_GREEN
		or kind == Kind.METEOR_PLASMA_GOLD
		or kind == Kind.METEOR_CRYSTAL
	)


func is_enemy_ship() -> bool:
	return kind == Kind.ENEMY_INTERCEPTOR or kind == Kind.ENEMY_BOSS_3D


func is_hostile() -> bool:
	return is_meteor() or is_enemy_ship()


func is_plasma_bomb() -> bool:
	return kind == Kind.METEOR_PLASMA_GREEN or kind == Kind.METEOR_PLASMA_GOLD


func is_pickup_orb() -> bool:
	return (
		kind == Kind.ORB_ENERGY
		or kind == Kind.ORB_HYPER_CORE
		or kind == Kind.ORB_SHIELD
		or kind == Kind.ORB_WEAPON_PLASMA
		or kind == Kind.ORB_WEAPON_VULCAN
		or kind == Kind.ORB_WEAPON_LASER
		or kind == Kind.ORB_WEAPON_MISSILE
		or kind == Kind.ORB_QUANTUM_CRYSTAL
	)


func apply_damage(amount: float) -> bool:
	if is_destroyed or not is_hostile():
		return false
	hp -= amount
	_hit_flash_timer = 0.07
	if _rock_mesh_inst != null and _mat_hit_flash != null:
		_rock_mesh_inst.material_override = _mat_hit_flash
	if kind == Kind.ENEMY_BOSS_3D and not boss_enraged and hp > 0.0 and hp <= max_hp * 0.45:
		boss_enraged = true
		fire_interval = 0.92
	if hp <= 0.0:
		is_destroyed = true
		return true
	return false


func update_entity(delta: float, speed_mult: float, glider_pos: Vector3, magnet_radius: float) -> bool:
	age += delta

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0 and _rock_mesh_inst != null and _base_rock_mat != null:
			_rock_mesh_inst.material_override = _base_rock_mat

	# Магнитное притяжение сфер и бонусов к 3D-глайдеру (у Квантовых Кристаллов увеличенный радиус захвата)
	if is_pickup_orb():
		if kind == Kind.ORB_QUANTUM_CRYSTAL:
			velocity.x = move_toward(velocity.x, 0.0, 8.5 * delta)
			velocity.y = move_toward(velocity.y, 0.0, 8.5 * delta)
		var eff_magnet: float = magnet_radius * (1.28 if kind == Kind.ORB_QUANTUM_CRYSTAL else 1.0)
		var to_glider: Vector3 = glider_pos - global_position
		var dist: float = to_glider.length()
		if dist < eff_magnet and dist > 0.05:
			var pull_strength: float = lerpf(38.0, 14.0, clampf(dist / eff_magnet, 0.0, 1.0))
			position += to_glider.normalized() * pull_strength * delta

	# Притяжение самого глайдера или визуальное вращение для Чёрной дыры
	if kind == Kind.BLACK_HOLE_PORTAL:
		position.z += velocity.z * speed_mult * delta
		if _ring_inst != null:
			_ring_inst.rotation.z -= delta * 1.8
		return position.z < 18.0

	# Поведение тяжёлого 3D Босса-Дредноута (выходит на боевую дистанцию z = -34 и маневрирует по восьмёрке)
	if kind == Kind.ENEMY_BOSS_3D:
		if position.z < -34.0:
			position.z = minf(-34.0, position.z + velocity.z * speed_mult * delta)
		var spd: float = 1.65 if boss_enraged else 1.05
		position.x = sin(age * spd) * 4.8
		position.y = 1.1 + sin(age * spd * 1.7) * 2.2
		if _ring_inst != null:
			_ring_inst.rotation.z += delta * (3.8 if boss_enraged else 1.9)
			_ring_inst.rotation.x = sin(age * 2.0) * 0.55
		if _visual_root != null:
			_visual_root.rotation.z = -cos(age * spd) * 0.18
		return true

	# Поведение 3D Катера-Перехватчика (маневрирует по синусоиде навстречу глайдеру)
	if kind == Kind.ENEMY_INTERCEPTOR:
		position.z += velocity.z * speed_mult * delta
		position.x = clampf(spawn_origin_xy.x + sin(age * 2.8 + spawn_origin_xy.y) * 2.8, -7.2, 7.2)
		position.y = clampf(spawn_origin_xy.y + cos(age * 2.1) * 1.4, -4.2, 4.8)
		if _visual_root != null:
			_visual_root.rotation.z = -cos(age * 2.8 + spawn_origin_xy.y) * 0.35
		return position.z < 18.0

	position.x += velocity.x * delta
	position.y += velocity.y * delta
	position.z += velocity.z * speed_mult * delta

	# Мягкое отражение от границ коридора полёта по X и Y (бонусы и кристаллы строго в пределах досягаемости глайдера!)
	var max_x: float = 6.8 if is_pickup_orb() else 8.8
	var min_y: float = -3.9 if is_pickup_orb() else -5.5
	var max_y: float = 3.5 if is_pickup_orb() else 6.0
	if absf(position.x) > max_x:
		position.x = clampf(position.x, -max_x, max_x)
		velocity.x = -velocity.x * (0.5 if is_pickup_orb() else 1.0)
	if position.y < min_y or position.y > max_y:
		position.y = clampf(position.y, min_y, max_y)
		velocity.y = -velocity.y * (0.5 if is_pickup_orb() else 1.0)

	if _visual_root != null:
		if is_meteor():
			_visual_root.rotation += rot_speed * delta
		elif is_pickup_orb():
			_visual_root.rotation.y += delta * (4.2 if kind == Kind.ORB_QUANTUM_CRYSTAL else 2.4)
			if _ring_inst != null:
				_ring_inst.rotation.x += delta * 3.1

	if _plasma_core_inst != null and is_plasma_bomb():
		var pulse: float = 1.0 + 0.14 * sin(age * 9.5)
		_plasma_core_inst.scale = Vector3.ONE * (radius * 2.15 * pulse)

	return position.z < 18.0
