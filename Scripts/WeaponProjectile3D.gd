class_name WeaponProjectile3D
extends Node3D

## 3D-снаряды вооружения глайдера:
## - Базовая и Тяжёлая Плазма (светящееся плазменное ядро + ореол + шлейф)
## - Скорострельные трассеры «Вулкан»
## - Самонаводящиеся 3D-Ракеты с корпусом, боеголовкой и огненным факелом

enum Kind {
	PLASMA_BASE,
	PLASMA_HEAVY,
	VULCAN_BULLET,
	HOMING_MISSILE
}

var kind: Kind = Kind.PLASMA_BASE
var velocity: Vector3 = Vector3(0.0, 0.0, -110.0)
var damage: float = 20.0
var hit_radius: float = 1.15
var splash_radius: float = 0.0
var lifetime: float = 2.4
var age: float = 0.0
var target_entity: Node3D = null

var _visual_root: Node3D
var _outer_halo: MeshInstance3D
var _trail_mesh: MeshInstance3D

# Кэш общих мешей и материалов для высокой производительности без аллокаций на каждый выстрел
static var _sphere_core_mesh: SphereMesh
static var _sphere_halo_mesh: SphereMesh
static var _bullet_mesh: BoxMesh
static var _missile_body_mesh: CylinderMesh
static var _trail_cyl_mesh: CylinderMesh

static var _mat_plasma_base_core: StandardMaterial3D
static var _mat_plasma_base_halo: StandardMaterial3D
static var _mat_plasma_heavy_core: StandardMaterial3D
static var _mat_plasma_heavy_halo: StandardMaterial3D
static var _mat_vulcan: StandardMaterial3D
static var _mat_missile_body: StandardMaterial3D
static var _mat_missile_flame: StandardMaterial3D


static func clear_static_caches() -> void:
	_sphere_core_mesh = null
	_sphere_halo_mesh = null
	_bullet_mesh = null
	_missile_body_mesh = null
	_trail_cyl_mesh = null
	_mat_plasma_base_core = null
	_mat_plasma_base_halo = null
	_mat_plasma_heavy_core = null
	_mat_plasma_heavy_halo = null
	_mat_vulcan = null
	_mat_missile_body = null
	_mat_missile_flame = null


static func _ensure_shared_resources() -> void:
	if _sphere_core_mesh != null:
		return

	_sphere_core_mesh = SphereMesh.new()
	_sphere_core_mesh.radius = 0.24
	_sphere_core_mesh.height = 0.48
	_sphere_core_mesh.radial_segments = 12
	_sphere_core_mesh.rings = 6

	_sphere_halo_mesh = SphereMesh.new()
	_sphere_halo_mesh.radius = 0.46
	_sphere_halo_mesh.height = 0.92
	_sphere_halo_mesh.radial_segments = 12
	_sphere_halo_mesh.rings = 6

	_bullet_mesh = BoxMesh.new()
	_bullet_mesh.size = Vector3(0.14, 0.14, 1.55)

	_missile_body_mesh = CylinderMesh.new()
	_missile_body_mesh.top_radius = 0.06
	_missile_body_mesh.bottom_radius = 0.16
	_missile_body_mesh.height = 1.25
	_missile_body_mesh.radial_segments = 10

	_trail_cyl_mesh = CylinderMesh.new()
	_trail_cyl_mesh.top_radius = 0.18
	_trail_cyl_mesh.bottom_radius = 0.01
	_trail_cyl_mesh.height = 2.2
	_trail_cyl_mesh.radial_segments = 8
	_trail_cyl_mesh.cap_top = false
	_trail_cyl_mesh.cap_bottom = false

	_mat_plasma_base_core = StandardMaterial3D.new()
	_mat_plasma_base_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plasma_base_core.albedo_color = Color(0.86, 0.99, 1.0, 1.0)

	_mat_plasma_base_halo = StandardMaterial3D.new()
	_mat_plasma_base_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plasma_base_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_plasma_base_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_plasma_base_halo.albedo_color = Color(0.12, 0.88, 1.0, 0.72)

	_mat_plasma_heavy_core = StandardMaterial3D.new()
	_mat_plasma_heavy_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plasma_heavy_core.albedo_color = Color(0.95, 1.0, 0.78, 1.0)

	_mat_plasma_heavy_halo = StandardMaterial3D.new()
	_mat_plasma_heavy_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_plasma_heavy_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_plasma_heavy_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_plasma_heavy_halo.albedo_color = Color(0.18, 1.0, 0.56, 0.82)

	_mat_vulcan = StandardMaterial3D.new()
	_mat_vulcan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_vulcan.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_vulcan.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_vulcan.albedo_color = Color(1.0, 0.86, 0.28, 0.96)

	_mat_missile_body = StandardMaterial3D.new()
	_mat_missile_body.albedo_color = Color(0.92, 0.95, 1.0)
	_mat_missile_body.metallic = 0.65
	_mat_missile_body.roughness = 0.28
	_mat_missile_body.emission_enabled = true
	_mat_missile_body.emission = Color(1.0, 0.34, 0.22)
	_mat_missile_body.emission_energy_multiplier = 1.4

	_mat_missile_flame = StandardMaterial3D.new()
	_mat_missile_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_missile_flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_missile_flame.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_missile_flame.albedo_color = Color(1.0, 0.52, 0.16, 0.85)


func setup_projectile(
	p_kind: Kind,
	start_pos: Vector3,
	init_vel: Vector3,
	dmg_bonus: float = 0.0,
	homing_target: Node3D = null
) -> void:
	_ensure_shared_resources()
	kind = p_kind
	position = start_pos
	velocity = init_vel
	target_entity = homing_target

	_visual_root = Node3D.new()
	add_child(_visual_root)

	match kind:
		Kind.PLASMA_BASE:
			damage = 22.0 + dmg_bonus
			hit_radius = 1.25
			splash_radius = 0.0
			lifetime = 2.1
			_build_plasma_visual(false)
		Kind.PLASMA_HEAVY:
			damage = 46.0 + dmg_bonus * 1.4
			hit_radius = 1.85
			splash_radius = 5.4
			lifetime = 2.3
			_build_plasma_visual(true)
		Kind.VULCAN_BULLET:
			damage = 15.0 + dmg_bonus * 0.5
			hit_radius = 1.05
			splash_radius = 0.0
			lifetime = 1.8
			_build_vulcan_visual()
		Kind.HOMING_MISSILE:
			damage = 78.0 + dmg_bonus * 1.8
			hit_radius = 2.1
			splash_radius = 6.8
			lifetime = 3.2
			_build_missile_visual()


func _build_plasma_visual(is_heavy: bool) -> void:
	var core := MeshInstance3D.new()
	core.mesh = _sphere_core_mesh
	core.material_override = _mat_plasma_heavy_core if is_heavy else _mat_plasma_base_core
	var scale_mult: float = 1.48 if is_heavy else 1.0
	core.scale = Vector3(scale_mult, scale_mult, scale_mult * 1.6)
	_visual_root.add_child(core)

	_outer_halo = MeshInstance3D.new()
	_outer_halo.mesh = _sphere_halo_mesh
	_outer_halo.material_override = _mat_plasma_heavy_halo if is_heavy else _mat_plasma_base_halo
	_outer_halo.scale = Vector3(scale_mult, scale_mult, scale_mult * 2.1)
	_visual_root.add_child(_outer_halo)

	_trail_mesh = MeshInstance3D.new()
	_trail_mesh.mesh = _trail_cyl_mesh
	_trail_mesh.material_override = _mat_plasma_heavy_halo if is_heavy else _mat_plasma_base_halo
	_trail_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_trail_mesh.position = Vector3(0.0, 0.0, 1.15 * scale_mult)
	_trail_mesh.scale = Vector3(scale_mult, scale_mult, scale_mult)
	_visual_root.add_child(_trail_mesh)


func _build_vulcan_visual() -> void:
	var tracer := MeshInstance3D.new()
	tracer.mesh = _bullet_mesh
	tracer.material_override = _mat_vulcan
	_visual_root.add_child(tracer)


func _build_missile_visual() -> void:
	var body := MeshInstance3D.new()
	body.mesh = _missile_body_mesh
	body.material_override = _mat_missile_body
	body.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_visual_root.add_child(body)

	_trail_mesh = MeshInstance3D.new()
	_trail_mesh.mesh = _trail_cyl_mesh
	_trail_mesh.material_override = _mat_missile_flame
	_trail_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_trail_mesh.position = Vector3(0.0, 0.0, 1.45)
	_trail_mesh.scale = Vector3(1.1, 1.1, 1.1)
	_visual_root.add_child(_trail_mesh)


func update_projectile(delta: float) -> bool:
	age += delta
	if age >= lifetime or position.z < -210.0 or position.z > 20.0:
		return false

	if kind == Kind.HOMING_MISSILE:
		if is_instance_valid(target_entity) and target_entity.is_inside_tree() and not target_entity.is_queued_for_deletion():
			var to_target: Vector3 = target_entity.global_position - global_position
			if to_target.length_squared() > 0.25:
				var desired_dir: Vector3 = to_target.normalized()
				var current_speed: float = maxf(velocity.length(), 92.0)
				var new_dir: Vector3 = velocity.normalized().lerp(desired_dir, clampf(delta * 7.5, 0.0, 1.0)).normalized()
				velocity = new_dir * minf(current_speed + delta * 42.0, 145.0)
		else:
			target_entity = null
			velocity.z -= delta * 35.0

		if velocity.length_squared() > 1.0 and _visual_root != null:
			var forward_dir: Vector3 = velocity.normalized()
			if absf(forward_dir.dot(Vector3.UP)) < 0.98:
				_visual_root.look_at(global_position + forward_dir, Vector3.UP)

	position += velocity * delta

	if _outer_halo != null:
		var pulse: float = 1.0 + 0.18 * sin(age * 28.0)
		var base_s: float = 1.48 if kind == Kind.PLASMA_HEAVY else 1.0
		_outer_halo.scale = Vector3(base_s * pulse, base_s * pulse, base_s * 2.1 * pulse)

	return true
