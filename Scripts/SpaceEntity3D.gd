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
	BLACK_HOLE_PORTAL
}

var kind: Kind = Kind.METEOR_ROCK
var radius: float = 1.6
var max_hp: float = 40.0
var hp: float = 40.0
var score_value: int = 50
var velocity: Vector3 = Vector3(0.0, 0.0, 42.0)
var rot_speed: Vector3 = Vector3(1.0, 1.4, 0.7)
var grazed: bool = false
var age: float = 0.0

var _visual_root: Node3D
var _rock_mesh_inst: MeshInstance3D
var _plasma_core_inst: MeshInstance3D
var _ring_inst: MeshInstance3D
var _hit_flash_timer: float = 0.0
var _base_rock_mat: StandardMaterial3D

# Статический кэш процедурно сгенерированных 3D-скал и материалов
static var _rock_meshes: Array[ArrayMesh] = []
static var _mat_rock_brown: StandardMaterial3D
static var _mat_rock_slate: StandardMaterial3D
static var _mat_rock_crystal: StandardMaterial3D
static var _mat_hit_flash: StandardMaterial3D
static var _mat_plasma_green_core: StandardMaterial3D
static var _mat_plasma_gold_core: StandardMaterial3D
static var _mat_black_hole_void: StandardMaterial3D
static var _mat_black_hole_disk: ShaderMaterial

static var _orb_sphere_mesh: SphereMesh
static var _orb_ring_mesh: TorusMesh
static var _bh_void_mesh: SphereMesh
static var _bh_disk_mesh: QuadMesh


static func clear_static_caches() -> void:
	_rock_meshes.clear()
	_mat_rock_brown = null
	_mat_rock_slate = null
	_mat_rock_crystal = null
	_mat_hit_flash = null
	_mat_plasma_green_core = null
	_mat_plasma_gold_core = null
	_mat_black_hole_void = null
	_mat_black_hole_disk = null
	_orb_sphere_mesh = null
	_orb_ring_mesh = null
	_bh_void_mesh = null
	_bh_disk_mesh = null


static func _ensure_shared_assets() -> void:
	if not _rock_meshes.is_empty():
		return

	# Генерируем 8 уникальных гранёных 3D-мешей метеоритов с кратерами и хребтами
	for i: int in range(8):
		_rock_meshes.append(_generate_procedural_asteroid_mesh(101 + i * 73))

	_mat_rock_brown = StandardMaterial3D.new()
	_mat_rock_brown.albedo_color = Color(0.42, 0.34, 0.29)
	_mat_rock_brown.roughness = 0.86
	_mat_rock_brown.metallic = 0.12

	_mat_rock_slate = StandardMaterial3D.new()
	_mat_rock_slate.albedo_color = Color(0.32, 0.37, 0.46)
	_mat_rock_slate.roughness = 0.78
	_mat_rock_slate.metallic = 0.25

	_mat_rock_crystal = StandardMaterial3D.new()
	_mat_rock_crystal.albedo_color = Color(0.24, 0.72, 0.96)
	_mat_rock_crystal.roughness = 0.22
	_mat_rock_crystal.metallic = 0.75
	_mat_rock_crystal.emission_enabled = true
	_mat_rock_crystal.emission = Color(0.12, 0.55, 0.88)
	_mat_rock_crystal.emission_energy_multiplier = 0.95

	_mat_hit_flash = StandardMaterial3D.new()
	_mat_hit_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_hit_flash.albedo_color = Color(1.0, 0.95, 0.88)

	_mat_plasma_green_core = StandardMaterial3D.new()
	_mat_plasma_green_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plasma_green_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_plasma_green_core.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_plasma_green_core.albedo_color = Color(0.18, 1.0, 0.52, 0.86)

	_mat_plasma_gold_core = StandardMaterial3D.new()
	_mat_plasma_gold_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plasma_gold_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_plasma_gold_core.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_plasma_gold_core.albedo_color = Color(1.0, 0.68, 0.14, 0.88)

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
		_:
			radius = 1.15
			velocity = Vector3(0.0, 0.0, forward_vel_z * 0.88)
			score_value = 90
			_build_orb_visual()


func _build_meteor_visual(variant_type: int) -> void:
	_rock_mesh_inst = MeshInstance3D.new()
	_rock_mesh_inst.mesh = _rock_meshes[randi() % _rock_meshes.size()]
	_rock_mesh_inst.scale = Vector3.ONE * radius

	if variant_type == 3:
		_base_rock_mat = _mat_rock_crystal
	elif randi() % 2 == 0:
		_base_rock_mat = _mat_rock_brown
	else:
		_base_rock_mat = _mat_rock_slate

	_rock_mesh_inst.material_override = _base_rock_mat
	_visual_root.add_child(_rock_mesh_inst)

	# Если это нестабильный плазменный метеорит-бомба, добавляем светящееся ядро и плазменное кольцо
	if variant_type == 1 or variant_type == 2:
		var core_mat: StandardMaterial3D = _mat_plasma_green_core if variant_type == 1 else _mat_plasma_gold_core
		_plasma_core_inst = MeshInstance3D.new()
		_plasma_core_inst.mesh = _orb_sphere_mesh
		_plasma_core_inst.material_override = core_mat
		_plasma_core_inst.scale = Vector3.ONE * (radius * 2.15)
		_visual_root.add_child(_plasma_core_inst)

		_ring_inst = MeshInstance3D.new()
		_ring_inst.mesh = _orb_ring_mesh
		_ring_inst.material_override = core_mat
		_ring_inst.scale = Vector3.ONE * (radius * 1.65)
		_visual_root.add_child(_ring_inst)


func _build_orb_visual() -> void:
	var col_core: Color = Color(0.20, 0.94, 1.0, 0.95)
	match kind:
		Kind.ORB_ENERGY:
			col_core = Color(0.20, 0.92, 1.0, 0.95)
		Kind.ORB_HYPER_CORE:
			col_core = Color(0.95, 0.25, 1.0, 0.98)
		Kind.ORB_SHIELD:
			col_core = Color(0.20, 1.0, 0.65, 0.98)
		Kind.ORB_WEAPON_PLASMA:
			col_core = Color(0.28, 1.0, 0.45, 0.98)
		Kind.ORB_WEAPON_VULCAN:
			col_core = Color(1.0, 0.84, 0.22, 0.98)
		Kind.ORB_WEAPON_LASER:
			col_core = Color(0.25, 0.96, 1.0, 0.98)
		Kind.ORB_WEAPON_MISSILE:
			col_core = Color(1.0, 0.36, 0.28, 0.98)

	var mat_orb := StandardMaterial3D.new()
	mat_orb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_orb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_orb.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat_orb.albedo_color = col_core

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


func is_meteor() -> bool:
	return (
		kind == Kind.METEOR_ROCK
		or kind == Kind.METEOR_PLASMA_GREEN
		or kind == Kind.METEOR_PLASMA_GOLD
		or kind == Kind.METEOR_CRYSTAL
	)


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
	)


func apply_damage(amount: float) -> bool:
	if not is_meteor():
		return false
	hp -= amount
	_hit_flash_timer = 0.07
	if _rock_mesh_inst != null and _mat_hit_flash != null:
		_rock_mesh_inst.material_override = _mat_hit_flash
	return hp <= 0.0


func update_entity(delta: float, speed_mult: float, glider_pos: Vector3, magnet_radius: float) -> bool:
	age += delta

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0 and _rock_mesh_inst != null and _base_rock_mat != null:
			_rock_mesh_inst.material_override = _base_rock_mat

	# Магнитное притяжение сфер и бонусов к 3D-глайдеру
	if is_pickup_orb():
		var to_glider: Vector3 = glider_pos - global_position
		var dist: float = to_glider.length()
		if dist < magnet_radius and dist > 0.05:
			var pull_strength: float = lerpf(36.0, 12.0, clampf(dist / magnet_radius, 0.0, 1.0))
			position += to_glider.normalized() * pull_strength * delta

	# Притяжение самого глайдера или визуальное вращение для Чёрной дыры
	if kind == Kind.BLACK_HOLE_PORTAL:
		position.z += velocity.z * speed_mult * delta
		if _ring_inst != null:
			_ring_inst.rotation.z -= delta * 1.8
		return position.z < 18.0

	position.x += velocity.x * delta
	position.y += velocity.y * delta
	position.z += velocity.z * speed_mult * delta

	# Мягкое отражение от границ коридора полёта по X и Y
	if absf(position.x) > 9.5:
		position.x = clampf(position.x, -9.5, 9.5)
		velocity.x = -velocity.x
	if position.y < -6.5 or position.y > 7.5:
		position.y = clampf(position.y, -6.5, 7.5)
		velocity.y = -velocity.y

	if _visual_root != null:
		if is_meteor():
			_visual_root.rotation += rot_speed * delta
		elif is_pickup_orb():
			_visual_root.rotation.y += delta * 2.4
			if _ring_inst != null:
				_ring_inst.rotation.x += delta * 3.1

	if _plasma_core_inst != null and is_plasma_bomb():
		var pulse: float = 1.0 + 0.14 * sin(age * 9.5)
		_plasma_core_inst.scale = Vector3.ONE * (radius * 2.15 * pulse)

	return position.z < 18.0
