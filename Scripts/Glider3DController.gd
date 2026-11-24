class_name Glider3DController
extends Node3D

## 3D-контроллер космического глайдера (вид от 3-го лица сверху и сзади).
## Собирает детализированную процедурную 3D-модель перехватчика с неоновыми вставками,
## реактивными плазменными факелами (PlasmaJet3D.gdshader), куполом 3D Грави-Щита,
## крыльевыми 3D-дронами и голографическим 3D-прицелом по курсу.
## Реализует полное 3D-маневрирование по X и Y с динамическим креном (Roll), тангажем (Pitch) и рысканием (Yaw).

const BOUNDS_X: float = 7.2
const BOUNDS_Y_MIN: float = -4.2
const BOUNDS_Y_MAX: float = 3.6

const MAX_ROLL_DEG: float = 42.0
const MAX_PITCH_DEG: float = 24.0
const MAX_YAW_DEG: float = 15.0

var target_pos: Vector2 = Vector2.ZERO
var current_vel: Vector2 = Vector2.ZERO

var _hull_root: Node3D
var _shield_dome: MeshInstance3D
var _shield_shader_mat: ShaderMaterial
var _engine_light: OmniLight3D
var _muzzle_light: OmniLight3D
var _muzzle_flash_energy: float = 0.0
var _jet_left: MeshInstance3D
var _jet_right: MeshInstance3D
var _jet_mat: ShaderMaterial

var _wing_strip_left: MeshInstance3D
var _wing_strip_right: MeshInstance3D
var _wing_strip_mat: StandardMaterial3D
var _wingtip_beacon_left: Node3D
var _wingtip_beacon_right: Node3D

const BARREL_ROLL_DURATION: float = 0.48
const BARREL_ROLL_COOLDOWN: float = 1.30
var _barrel_roll_timer: float = 0.0
var _barrel_roll_cd: float = 0.0
var _barrel_roll_dir: float = 1.0

var _reticle_near: MeshInstance3D
var _reticle_far: MeshInstance3D
var _reticle_mat: StandardMaterial3D

var _drone_left: Node3D
var _drone_right: Node3D
var _drones_enabled: bool = false

var _laser_beam_mesh: MeshInstance3D
var _laser_beam_mat: StandardMaterial3D
var _laser_core_mesh: MeshInstance3D

var _time_accum: float = 0.0
var _shield_flash: float = 0.0
var _damage_invuln_timer: float = 0.0


func _ready() -> void:
	_build_glider_3d_model()
	_build_shield_dome()
	_build_wing_drones()
	_build_holo_reticle()
	_build_quantum_laser_beam()


func _build_glider_3d_model() -> void:
	_hull_root = Node3D.new()
	add_child(_hull_root)

	# Материалы корпуса глайдера
	var mat_hull := StandardMaterial3D.new()
	mat_hull.albedo_color = Color(0.14, 0.21, 0.35)
	mat_hull.metallic = 0.78
	mat_hull.roughness = 0.26

	var mat_dark_armor := StandardMaterial3D.new()
	mat_dark_armor.albedo_color = Color(0.07, 0.11, 0.20)
	mat_dark_armor.metallic = 0.85
	mat_dark_armor.roughness = 0.32

	var mat_cockpit := StandardMaterial3D.new()
	mat_cockpit.albedo_color = Color(0.15, 0.88, 1.0, 0.92)
	mat_cockpit.metallic = 0.35
	mat_cockpit.roughness = 0.10
	mat_cockpit.emission_enabled = true
	mat_cockpit.emission = Color(0.12, 0.78, 1.0)
	mat_cockpit.emission_energy_multiplier = 1.65

	_wing_strip_mat = StandardMaterial3D.new()
	_wing_strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wing_strip_mat.albedo_color = Color(0.22, 0.95, 1.0)

	# 1. Центральный фюзеляж
	var fuselage := MeshInstance3D.new()
	var fus_box := BoxMesh.new()
	fus_box.size = Vector3(0.88, 0.42, 2.35)
	fuselage.mesh = fus_box
	fuselage.material_override = mat_hull
	fuselage.position = Vector3(0.0, 0.0, -0.15)
	_hull_root.add_child(fuselage)

	# 2. Острый носовой обтекатель (-Z)
	var nose := MeshInstance3D.new()
	var nose_cyl := CylinderMesh.new()
	nose_cyl.top_radius = 0.02
	nose_cyl.bottom_radius = 0.44
	nose_cyl.height = 1.55
	nose_cyl.radial_segments = 6
	nose.mesh = nose_cyl
	nose.material_override = mat_hull
	nose.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	nose.scale = Vector3(1.0, 1.0, 0.58)
	nose.position = Vector3(0.0, -0.02, -2.05)
	_hull_root.add_child(nose)

	# 3. Светящаяся кабина пилота (Кокпит сверху)
	var cockpit := MeshInstance3D.new()
	var cock_mesh := CapsuleMesh.new()
	cock_mesh.radius = 0.25
	cock_mesh.height = 1.35
	cock_mesh.radial_segments = 12
	cock_mesh.rings = 6
	cockpit.mesh = cock_mesh
	cockpit.material_override = mat_cockpit
	cockpit.rotation_degrees = Vector3(84.0, 0.0, 0.0)
	cockpit.scale = Vector3(1.05, 1.0, 0.68)
	cockpit.position = Vector3(0.0, 0.20, -0.52)
	_hull_root.add_child(cockpit)

	# 4. Стреловидные основные крылья (левое и правое)
	var wing_box := BoxMesh.new()
	wing_box.size = Vector3(1.85, 0.11, 0.92)

	var wing_l := MeshInstance3D.new()
	wing_l.mesh = wing_box
	wing_l.material_override = mat_hull
	wing_l.position = Vector3(-1.22, -0.03, 0.15)
	wing_l.rotation_degrees = Vector3(0.0, 22.0, 6.0)
	_hull_root.add_child(wing_l)

	var wing_r := MeshInstance3D.new()
	wing_r.mesh = wing_box
	wing_r.material_override = mat_hull
	wing_r.position = Vector3(1.22, -0.03, 0.15)
	wing_r.rotation_degrees = Vector3(0.0, -22.0, -6.0)
	_hull_root.add_child(wing_r)

	# Неоновые полосы вдоль передней кромки крыльев
	var strip_box := BoxMesh.new()
	strip_box.size = Vector3(1.78, 0.05, 0.10)

	_wing_strip_left = MeshInstance3D.new()
	_wing_strip_left.mesh = strip_box
	_wing_strip_left.material_override = _wing_strip_mat
	_wing_strip_left.position = Vector3(0.0, 0.05, -0.42)
	wing_l.add_child(_wing_strip_left)

	_wing_strip_right = MeshInstance3D.new()
	_wing_strip_right.mesh = strip_box
	_wing_strip_right.material_override = _wing_strip_mat
	_wing_strip_right.position = Vector3(0.0, 0.05, -0.42)
	wing_r.add_child(_wing_strip_right)

	# Законцовки крыльев (Winglets) с неоновыми габаритными маяками для хищного 3D-силуэта
	var winglet_box := BoxMesh.new()
	winglet_box.size = Vector3(0.09, 0.46, 0.72)

	var winglet_l := MeshInstance3D.new()
	winglet_l.mesh = winglet_box
	winglet_l.material_override = mat_dark_armor
	winglet_l.position = Vector3(-0.92, 0.16, 0.06)
	winglet_l.rotation_degrees = Vector3(-12.0, 0.0, 24.0)
	wing_l.add_child(winglet_l)

	var winglet_r := MeshInstance3D.new()
	winglet_r.mesh = winglet_box
	winglet_r.material_override = mat_dark_armor
	winglet_r.position = Vector3(0.92, 0.16, 0.06)
	winglet_r.rotation_degrees = Vector3(-12.0, 0.0, -24.0)
	wing_r.add_child(winglet_r)

	var beacon_box := BoxMesh.new()
	beacon_box.size = Vector3(0.11, 0.07, 0.66)
	var beacon_l := MeshInstance3D.new()
	beacon_l.mesh = beacon_box
	beacon_l.material_override = _wing_strip_mat
	beacon_l.position = Vector3(0.0, 0.22, 0.0)
	winglet_l.add_child(beacon_l)
	_wingtip_beacon_left = beacon_l

	var beacon_r := MeshInstance3D.new()
	beacon_r.mesh = beacon_box
	beacon_r.material_override = _wing_strip_mat
	beacon_r.position = Vector3(0.0, 0.22, 0.0)
	winglet_r.add_child(beacon_r)
	_wingtip_beacon_right = beacon_r

	# 5. Наклонные хвостовые стабилизаторы (V-Tail, отлично видны сзади и сверху!)
	var fin_box := BoxMesh.new()
	fin_box.size = Vector3(0.10, 0.76, 0.88)

	var fin_l := MeshInstance3D.new()
	fin_l.mesh = fin_box
	fin_l.material_override = mat_dark_armor
	fin_l.position = Vector3(-0.56, 0.36, 0.58)
	fin_l.rotation_degrees = Vector3(-16.0, 0.0, 26.0)
	_hull_root.add_child(fin_l)

	var fin_r := MeshInstance3D.new()
	fin_r.mesh = fin_box
	fin_r.material_override = mat_dark_armor
	fin_r.position = Vector3(0.56, 0.36, 0.58)
	fin_r.rotation_degrees = Vector3(-16.0, 0.0, -26.0)
	_hull_root.add_child(fin_r)

	# Неоновые верхушки стабилизаторов
	var fin_tip_box := BoxMesh.new()
	fin_tip_box.size = Vector3(0.12, 0.08, 0.84)
	var fin_tip_l := MeshInstance3D.new()
	fin_tip_l.mesh = fin_tip_box
	fin_tip_l.material_override = _wing_strip_mat
	fin_tip_l.position = Vector3(0.0, 0.38, 0.0)
	fin_l.add_child(fin_tip_l)

	var fin_tip_r := MeshInstance3D.new()
	fin_tip_r.mesh = fin_tip_box
	fin_tip_r.material_override = _wing_strip_mat
	fin_tip_r.position = Vector3(0.0, 0.38, 0.0)
	fin_r.add_child(fin_tip_r)

	# 6. Оружейные плазменные стволы под крыльями
	var gun_cyl := CylinderMesh.new()
	gun_cyl.top_radius = 0.07
	gun_cyl.bottom_radius = 0.10
	gun_cyl.height = 1.25
	gun_cyl.radial_segments = 8

	for side: float in [-1.05, 1.05]:
		var gun := MeshInstance3D.new()
		gun.mesh = gun_cyl
		gun.material_override = mat_dark_armor
		gun.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		gun.position = Vector3(side, -0.14, -0.58)
		_hull_root.add_child(gun)

	# 7. Двойные реактивные сопла сзади (+Z) и факелы плазмы
	var nozzle_cyl := CylinderMesh.new()
	nozzle_cyl.top_radius = 0.25
	nozzle_cyl.bottom_radius = 0.20
	nozzle_cyl.height = 0.55
	nozzle_cyl.radial_segments = 12

	var burner_torus := TorusMesh.new()
	burner_torus.inner_radius = 0.12
	burner_torus.outer_radius = 0.21
	burner_torus.rings = 16
	burner_torus.ring_segments = 8
	var mat_burner := StandardMaterial3D.new()
	mat_burner.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_burner.albedo_color = Color(0.75, 0.98, 1.0)

	for side_n: float in [-0.30, 0.30]:
		var nozzle := MeshInstance3D.new()
		nozzle.mesh = nozzle_cyl
		nozzle.material_override = mat_dark_armor
		nozzle.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		nozzle.position = Vector3(side_n, 0.0, 1.08)
		_hull_root.add_child(nozzle)

		var burner_ring := MeshInstance3D.new()
		burner_ring.mesh = burner_torus
		burner_ring.material_override = mat_burner
		burner_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		burner_ring.position = Vector3(side_n, 0.0, 1.34)
		_hull_root.add_child(burner_ring)

	_jet_mat = ShaderMaterial.new()
	var jet_shader := load("res://Shaders/PlasmaJet3D.gdshader") as Shader
	_jet_mat.shader = jet_shader

	var jet_cone := CylinderMesh.new()
	jet_cone.top_radius = 0.22
	jet_cone.bottom_radius = 0.01
	jet_cone.height = 2.45
	jet_cone.radial_segments = 12
	jet_cone.cap_top = false
	jet_cone.cap_bottom = false
	jet_cone.material = _jet_mat

	_jet_left = MeshInstance3D.new()
	_jet_left.mesh = jet_cone
	_jet_left.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_jet_left.position = Vector3(-0.30, 0.0, 2.35)
	_hull_root.add_child(_jet_left)

	_jet_right = MeshInstance3D.new()
	_jet_right.mesh = jet_cone
	_jet_right.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_jet_right.position = Vector3(0.30, 0.0, 2.35)
	_hull_root.add_child(_jet_right)

	_engine_light = OmniLight3D.new()
	_engine_light.light_color = Color(0.20, 0.90, 1.0)
	_engine_light.light_energy = 2.4
	_engine_light.omni_range = 6.5
	_engine_light.position = Vector3(0.0, 0.15, 1.65)
	_hull_root.add_child(_engine_light)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(0.22, 0.95, 1.0)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 5.2
	_muzzle_light.position = Vector3(0.0, 0.12, -1.95)
	_hull_root.add_child(_muzzle_light)


func _build_shield_dome() -> void:
	_shield_dome = MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 2.15
	dome_mesh.height = 4.30
	dome_mesh.radial_segments = 22
	dome_mesh.rings = 12

	_shield_shader_mat = ShaderMaterial.new()
	_shield_shader_mat.shader = load("res://Shaders/ShieldDome3D.gdshader") as Shader
	_shield_shader_mat.set_shader_parameter("shield_color", Color(0.20, 0.92, 1.0, 0.45))
	_shield_shader_mat.set_shader_parameter("intensity", 0.22)

	_shield_dome.mesh = dome_mesh
	_shield_dome.material_override = _shield_shader_mat
	_shield_dome.scale = Vector3(1.18, 0.65, 1.25)
	_hull_root.add_child(_shield_dome)


func _build_wing_drones() -> void:
	var drone_sphere := SphereMesh.new()
	drone_sphere.radius = 0.24
	drone_sphere.height = 0.48
	drone_sphere.radial_segments = 10
	drone_sphere.rings = 6

	var drone_ring := TorusMesh.new()
	drone_ring.inner_radius = 0.30
	drone_ring.outer_radius = 0.38
	drone_ring.rings = 12
	drone_ring.ring_segments = 8

	var mat_drone := StandardMaterial3D.new()
	mat_drone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_drone.albedo_color = Color(0.28, 1.0, 0.76)

	_drone_left = Node3D.new()
	_drone_left.position = Vector3(-2.65, 0.25, -0.15)
	add_child(_drone_left)

	var dl_core := MeshInstance3D.new()
	dl_core.mesh = drone_sphere
	dl_core.material_override = mat_drone
	_drone_left.add_child(dl_core)

	var dl_ring := MeshInstance3D.new()
	dl_ring.mesh = drone_ring
	dl_ring.material_override = _wing_strip_mat
	_drone_left.add_child(dl_ring)

	_drone_right = Node3D.new()
	_drone_right.position = Vector3(2.65, 0.25, -0.15)
	add_child(_drone_right)

	var dr_core := MeshInstance3D.new()
	dr_core.mesh = drone_sphere
	dr_core.material_override = mat_drone
	_drone_right.add_child(dr_core)

	var dr_ring := MeshInstance3D.new()
	dr_ring.mesh = drone_ring
	dr_ring.material_override = _wing_strip_mat
	_drone_right.add_child(dr_ring)

	set_drones_active(false)


func _build_holo_reticle() -> void:
	_reticle_mat = StandardMaterial3D.new()
	_reticle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_reticle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reticle_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_reticle_mat.albedo_color = Color(0.22, 0.96, 1.0, 0.42)

	var ring_near_mesh := TorusMesh.new()
	ring_near_mesh.inner_radius = 0.72
	ring_near_mesh.outer_radius = 0.80
	ring_near_mesh.rings = 20
	ring_near_mesh.ring_segments = 8

	_reticle_near = MeshInstance3D.new()
	_reticle_near.mesh = ring_near_mesh
	_reticle_near.material_override = _reticle_mat
	_reticle_near.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_reticle_near.position = Vector3(0.0, 0.0, -14.0)
	_hull_root.add_child(_reticle_near)

	var ring_far_mesh := TorusMesh.new()
	ring_far_mesh.inner_radius = 1.15
	ring_far_mesh.outer_radius = 1.25
	ring_far_mesh.rings = 24
	ring_far_mesh.ring_segments = 8

	_reticle_far = MeshInstance3D.new()
	_reticle_far.mesh = ring_far_mesh
	_reticle_far.material_override = _reticle_mat
	_reticle_far.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_reticle_far.position = Vector3(0.0, 0.0, -28.0)
	_hull_root.add_child(_reticle_far)


func _build_quantum_laser_beam() -> void:
	_laser_beam_mat = StandardMaterial3D.new()
	_laser_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_laser_beam_mat.albedo_color = Color(0.22, 0.96, 1.0, 0.78)

	var outer_cyl := CylinderMesh.new()
	outer_cyl.top_radius = 0.24
	outer_cyl.bottom_radius = 0.24
	outer_cyl.height = 1.0
	outer_cyl.radial_segments = 10

	_laser_beam_mesh = MeshInstance3D.new()
	_laser_beam_mesh.mesh = outer_cyl
	_laser_beam_mesh.material_override = _laser_beam_mat
	_laser_beam_mesh.visible = false
	add_child(_laser_beam_mesh)

	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.95, 1.0, 1.0, 1.0)

	var inner_cyl := CylinderMesh.new()
	inner_cyl.top_radius = 0.09
	inner_cyl.bottom_radius = 0.09
	inner_cyl.height = 1.0
	inner_cyl.radial_segments = 8

	_laser_core_mesh = MeshInstance3D.new()
	_laser_core_mesh.mesh = inner_cyl
	_laser_core_mesh.material_override = core_mat
	_laser_beam_mesh.add_child(_laser_core_mesh)


func reset_glider() -> void:
	position = Vector3.ZERO
	target_pos = Vector2.ZERO
	current_vel = Vector2.ZERO
	if _hull_root != null:
		_hull_root.rotation = Vector3.ZERO
	_shield_flash = 0.0
	_damage_invuln_timer = 0.0
	_barrel_roll_timer = 0.0
	_barrel_roll_cd = 0.0
	hide_quantum_laser()


func trigger_barrel_roll(dir_sign: float = 1.0) -> bool:
	if _barrel_roll_timer > 0.0 or _barrel_roll_cd > 0.0:
		return false
	_barrel_roll_timer = BARREL_ROLL_DURATION
	_barrel_roll_cd = BARREL_ROLL_COOLDOWN
	_barrel_roll_dir = -1.0 if dir_sign < 0.0 else 1.0
	_shield_flash = maxf(_shield_flash, 0.72)
	move_target_by_delta(Vector2(_barrel_roll_dir * 1.45, 0.0))
	return true


func is_barrel_rolling() -> bool:
	return _barrel_roll_timer > 0.0


func set_drones_active(active: bool) -> void:
	_drones_enabled = active
	if _drone_left != null:
		_drone_left.visible = active
	if _drone_right != null:
		_drone_right.visible = active


func trigger_shield_flash(is_damage: bool = true) -> void:
	_shield_flash = 1.0
	if is_damage:
		_damage_invuln_timer = 1.15


func trigger_muzzle_flash(is_heavy: bool = false) -> void:
	_muzzle_flash_energy = 2.2 if is_heavy else 1.25
	if _muzzle_light != null:
		_muzzle_light.light_color = Color(0.25, 1.0, 0.62) if is_heavy else Color(0.20, 0.94, 1.0)
		_muzzle_light.light_energy = _muzzle_flash_energy


func is_damage_invulnerable() -> bool:
	return _damage_invuln_timer > 0.0


func move_target_by_delta(delta_xy: Vector2) -> void:
	target_pos.x = clampf(target_pos.x + delta_xy.x, -BOUNDS_X, BOUNDS_X)
	target_pos.y = clampf(target_pos.y + delta_xy.y, BOUNDS_Y_MIN, BOUNDS_Y_MAX)


func set_target_normalized(norm_xy: Vector2) -> void:
	target_pos.x = clampf(norm_xy.x * BOUNDS_X, -BOUNDS_X, BOUNDS_X)
	target_pos.y = clampf(lerpf(BOUNDS_Y_MIN, BOUNDS_Y_MAX, (norm_xy.y + 1.0) * 0.5), BOUNDS_Y_MIN, BOUNDS_Y_MAX)


func update_glider(
	delta: float,
	key_input: Vector2,
	responsiveness: float,
	is_hyper: bool,
	is_tunnel: bool,
	is_overdrive: bool,
	_shields_count: int
) -> void:
	_time_accum += delta
	if _damage_invuln_timer > 0.0:
		_damage_invuln_timer = maxf(0.0, _damage_invuln_timer - delta)
	if _shield_flash > 0.0:
		_shield_flash = maxf(0.0, _shield_flash - delta * 2.4)
	if _barrel_roll_cd > 0.0:
		_barrel_roll_cd = maxf(0.0, _barrel_roll_cd - delta)
	if _barrel_roll_timer > 0.0:
		_barrel_roll_timer = maxf(0.0, _barrel_roll_timer - delta)

	# Клавиатурное управление плавно сдвигает целевую точку в 3D-плоскости XY
	if key_input.length_squared() > 0.001:
		var key_speed: float = 13.5 * responsiveness
		target_pos.x = clampf(target_pos.x + key_input.x * key_speed * delta, -BOUNDS_X, BOUNDS_X)
		target_pos.y = clampf(target_pos.y + key_input.y * key_speed * delta, BOUNDS_Y_MIN, BOUNDS_Y_MAX)

	var prev_pos := Vector2(position.x, position.y)
	var follow_lerp: float = clampf(delta * 12.5 * responsiveness, 0.0, 1.0)
	position.x = lerpf(position.x, target_pos.x, follow_lerp)
	position.y = lerpf(position.y, target_pos.y, follow_lerp)

	if delta > 0.0001:
		current_vel = (Vector2(position.x, position.y) - prev_pos) / delta

	# Реалистичный 3D-крен (Roll), тангаж (Pitch) и рыскание (Yaw) при манёврах
	var norm_vx: float = clampf(current_vel.x / 12.0, -1.0, 1.0)
	var norm_vy: float = clampf(current_vel.y / 10.0, -1.0, 1.0)

	var desired_roll: float = deg_to_rad(-norm_vx * MAX_ROLL_DEG) + sin(_time_accum * 2.4) * 0.025
	var desired_pitch: float = deg_to_rad(norm_vy * MAX_PITCH_DEG) + cos(_time_accum * 1.9) * 0.015
	var desired_yaw: float = deg_to_rad(-norm_vx * MAX_YAW_DEG)

	if _hull_root != null:
		var rot_lerp: float = clampf(delta * 10.0, 0.0, 1.0)
		if _barrel_roll_timer > 0.0:
			var roll_t: float = 1.0 - (_barrel_roll_timer / BARREL_ROLL_DURATION)
			var eased_t: float = roll_t * roll_t * (3.0 - 2.0 * roll_t)
			_hull_root.rotation.z = desired_roll - _barrel_roll_dir * eased_t * TAU
		else:
			_hull_root.rotation.z = lerp_angle(_hull_root.rotation.z, desired_roll, rot_lerp)
		_hull_root.rotation.x = lerp_angle(_hull_root.rotation.x, desired_pitch, rot_lerp)
		_hull_root.rotation.y = lerp_angle(_hull_root.rotation.y, desired_yaw, rot_lerp)

	# Обновляем реактивную плазму из сопел глайдера
	var thrust_lvl: float = 1.85 if (is_hyper or is_tunnel) else (1.35 if is_overdrive else 1.0)
	thrust_lvl += clampf(current_vel.length() * 0.03, 0.0, 0.35)
	if _jet_mat != null:
		_jet_mat.set_shader_parameter("thrust_power", thrust_lvl)
		if is_hyper or is_tunnel:
			_jet_mat.set_shader_parameter("flame_color", Color(0.25, 1.0, 0.72, 1.0))
			_jet_mat.set_shader_parameter("tail_color", Color(0.96, 0.25, 0.92, 1.0))
		else:
			_jet_mat.set_shader_parameter("flame_color", Color(0.12, 0.86, 1.0, 1.0))
			_jet_mat.set_shader_parameter("tail_color", Color(0.55, 0.18, 0.98, 1.0))

	if _jet_left != null and _jet_right != null:
		var jet_len_scale: float = lerpf(0.95, 1.55, clampf((thrust_lvl - 1.0) * 0.9, 0.0, 1.0))
		_jet_left.scale = Vector3(1.0, jet_len_scale, 1.0)
		_jet_right.scale = Vector3(1.0, jet_len_scale, 1.0)
		_jet_left.position.z = 1.25 + 1.25 * jet_len_scale
		_jet_right.position.z = 1.25 + 1.25 * jet_len_scale

	if _engine_light != null:
		_engine_light.light_energy = 2.2 * thrust_lvl
		_engine_light.light_color = Color(0.32, 1.0, 0.82) if (is_hyper or is_tunnel) else Color(0.20, 0.90, 1.0)

	if _muzzle_flash_energy > 0.0:
		_muzzle_flash_energy = maxf(0.0, _muzzle_flash_energy - delta * 14.0)
		if _muzzle_light != null:
			_muzzle_light.light_energy = _muzzle_flash_energy

	# Цвет неоновых кромок крыльев
	if _wing_strip_mat != null:
		if is_hyper or is_tunnel:
			var hue: float = fmod(_time_accum * 0.65, 1.0)
			_wing_strip_mat.albedo_color = Color.from_hsv(hue, 0.75, 1.0)
		elif is_overdrive:
			_wing_strip_mat.albedo_color = Color(1.0, 0.85, 0.24)
		else:
			_wing_strip_mat.albedo_color = Color(0.22, 0.95, 1.0)

	# Обновляем френелевский купол 3D Грави-Щита (вспыхивает контурной волной при ударе, сборе щита или в Гипер-режиме)
	if _shield_dome != null and _shield_shader_mat != null:
		var show_dome: bool = _shield_flash > 0.01 or is_hyper or is_tunnel or _damage_invuln_timer > 0.0
		_shield_dome.visible = show_dome
		if show_dome:
			var base_int: float = 0.62 if (is_hyper or is_tunnel) else 0.25
			var total_int: float = clampf(base_int + _shield_flash * 0.95, 0.0, 1.35)
			var shield_col := Color(0.20, 0.92, 1.0, 0.52)
			if _damage_invuln_timer > 0.0:
				shield_col = Color(1.0, 0.32, 0.52, 0.65)
			elif is_hyper or is_tunnel:
				shield_col = Color(0.32, 1.0, 0.78, 0.60)
			_shield_shader_mat.set_shader_parameter("shield_color", shield_col)
			_shield_shader_mat.set_shader_parameter("intensity", total_int)

	# Анимация крыльевых 3D-дронов
	if _drones_enabled and _drone_left != null and _drone_right != null:
		var bob: float = sin(_time_accum * 4.2) * 0.22
		_drone_left.position = Vector3(-2.65, 0.25 + bob, -0.15)
		_drone_right.position = Vector3(2.65, 0.25 - bob, -0.15)
		_drone_left.rotation.y += delta * 2.6
		_drone_right.rotation.y -= delta * 2.6


func update_target_lock(has_target: bool, target_world_pos: Vector3, delta: float) -> void:
	if _reticle_far == null or _reticle_mat == null or _hull_root == null:
		return
	var lerp_t: float = clampf(delta * 10.0, 0.0, 1.0)
	if has_target:
		var local_t: Vector3 = _hull_root.to_local(target_world_pos)
		var clamped_x: float = clampf(local_t.x * 0.45, -3.5, 3.5)
		var clamped_y: float = clampf(local_t.y * 0.45, -2.5, 2.5)
		_reticle_far.position = _reticle_far.position.lerp(Vector3(clamped_x, clamped_y, -26.0), lerp_t)
		var pulse_s: float = 1.0 + 0.12 * sin(_time_accum * 14.0)
		_reticle_far.scale = Vector3.ONE * pulse_s
		_reticle_mat.albedo_color = Color(0.28, 1.0, 0.58, 0.62)
	else:
		_reticle_far.position = _reticle_far.position.lerp(Vector3(0.0, 0.0, -28.0), lerp_t)
		_reticle_far.scale = Vector3.ONE
		_reticle_mat.albedo_color = Color(0.22, 0.96, 1.0, 0.38)


func show_quantum_laser(target_world_pos: Vector3, is_overdrive: bool = false) -> void:
	if _laser_beam_mesh == null:
		return
	var start_pos: Vector3 = global_position + Vector3(0.0, 0.05, -2.2)
	var diff: Vector3 = target_world_pos - start_pos
	var dist: float = diff.length()
	if dist < 0.5:
		_laser_beam_mesh.visible = false
		return

	_laser_beam_mesh.visible = true
	if _laser_beam_mat != null:
		_laser_beam_mat.albedo_color = Color(1.0, 0.42, 0.95, 0.86) if is_overdrive else Color(0.22, 0.96, 1.0, 0.78)
	var mid_pos: Vector3 = start_pos + diff * 0.5
	_laser_beam_mesh.global_position = mid_pos

	# Ориентируем цилиндр луча вдоль вектора diff (ось Y цилиндра -> вдоль diff)
	var dir: Vector3 = diff / dist
	var up_ref: Vector3 = Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x_axis: Vector3 = up_ref.cross(dir).normalized()
	var z_axis: Vector3 = dir.cross(x_axis).normalized()
	_laser_beam_mesh.global_transform.basis = Basis(x_axis, dir * dist, z_axis)


func hide_quantum_laser() -> void:
	if _laser_beam_mesh != null:
		_laser_beam_mesh.visible = false


func get_muzzle_positions() -> Array[Vector3]:
	if _hull_root == null:
		return [global_position + Vector3(-1.0, -0.1, -1.5), global_position + Vector3(1.0, -0.1, -1.5)]
	var left_w: Vector3 = _hull_root.to_global(Vector3(-1.05, -0.14, -1.45))
	var right_w: Vector3 = _hull_root.to_global(Vector3(1.05, -0.14, -1.45))
	return [left_w, right_w]


func get_nose_muzzle_position() -> Vector3:
	if _hull_root == null:
		return global_position + Vector3(0.0, 0.0, -2.5)
	return _hull_root.to_global(Vector3(0.0, -0.02, -2.65))


func get_drone_muzzle_positions() -> Array[Vector3]:
	if not _drones_enabled or _drone_left == null or _drone_right == null:
		return []
	return [
		_drone_left.global_position + Vector3(0.0, 0.0, -0.6),
		_drone_right.global_position + Vector3(0.0, 0.0, -0.6)
	]


func get_wingtip_positions() -> Array[Vector3]:
	if _wingtip_beacon_left != null and _wingtip_beacon_right != null:
		return [
			_wingtip_beacon_left.global_position + Vector3(0.0, 0.0, 0.25),
			_wingtip_beacon_right.global_position + Vector3(0.0, 0.0, 0.25)
		]
	return [
		global_position + Vector3(-2.1, 0.1, 0.4),
		global_position + Vector3(2.1, 0.1, 0.4)
	]
