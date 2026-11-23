class_name FxManager3D
extends Node3D

## Менеджер 3D-спецэффектов без утечек памяти и лишних аллокаций материалов:
## - 3D-разлёт каменных осколков с кэшированными материалами (0 аллокаций StandardMaterial3D на осколках)
## - Тонкие плазменные ударные кольца (TorusMesh) и компактные искры с лимитом MAX_ACTIVE_EFFECTS

const MAX_ACTIVE_EFFECTS: int = 72

var _effects: Array[Dictionary] = []

static var _sphere_mesh: SphereMesh
static var _ring_mesh: TorusMesh
static var _arc_cyl_mesh: CylinderMesh
static var _shard_materials: Array[StandardMaterial3D] = []


static func clear_static_caches() -> void:
	_sphere_mesh = null
	_ring_mesh = null
	_arc_cyl_mesh = null
	_shard_materials.clear()


func _exit_tree() -> void:
	_effects.clear()


static func _ensure_meshes() -> void:
	if _sphere_mesh != null:
		return
	_sphere_mesh = SphereMesh.new()
	_sphere_mesh.radius = 0.45
	_sphere_mesh.height = 0.90
	_sphere_mesh.radial_segments = 10
	_sphere_mesh.rings = 6

	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.92
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 20
	_ring_mesh.ring_segments = 8

	_arc_cyl_mesh = CylinderMesh.new()
	_arc_cyl_mesh.top_radius = 0.08
	_arc_cyl_mesh.bottom_radius = 0.08
	_arc_cyl_mesh.height = 1.0
	_arc_cyl_mesh.radial_segments = 6

	_shard_materials.clear()
	var shard_tints: Array[Color] = [
		Color(0.32, 0.88, 1.0),
		Color(0.22, 1.0, 0.55),
		Color(1.0, 0.72, 0.18),
		Color(1.0, 0.35, 0.48)
	]
	for tint: Color in shard_tints:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = tint.lerp(Color(0.38, 0.34, 0.32), 0.60)
		sm.emission_enabled = true
		sm.emission = tint * 0.65
		_shard_materials.append(sm)


static func _pick_shard_material(col: Color) -> StandardMaterial3D:
	if _shard_materials.is_empty():
		return null
	if col.g > 0.85 and col.r < 0.45 and col.b < 0.70:
		return _shard_materials[1] # Зелёная плазма
	if col.r > 0.85 and col.g > 0.55:
		return _shard_materials[2] # Золотая плазма
	if col.r > 0.85 and col.g < 0.50:
		return _shard_materials[3] # Багровый взрыв
	return _shard_materials[0] # Квантовый циан


func _trim_excess_effects() -> void:
	while _effects.size() >= MAX_ACTIVE_EFFECTS:
		var oldest: Dictionary = _effects[0]
		var node := oldest.get("node") as Node3D
		if is_instance_valid(node):
			node.queue_free()
		_effects.remove_at(0)


func clear_all() -> void:
	for fx: Dictionary in _effects:
		var node := fx.get("node") as Node3D
		if is_instance_valid(node):
			node.queue_free()
	_effects.clear()


func spawn_meteor_explosion(world_pos: Vector3, base_radius: float, glow_col: Color, is_bomb: bool = false) -> void:
	_ensure_meshes()
	_trim_excess_effects()

	# 1. Компактная яркая вспышка в центре взрыва
	var flash_inst := MeshInstance3D.new()
	flash_inst.mesh = _sphere_mesh
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(glow_col.r, glow_col.g, glow_col.b, 0.72)
	flash_inst.material_override = flash_mat
	flash_inst.position = world_pos
	var start_s: float = base_radius * 0.35
	flash_inst.scale = Vector3.ONE * start_s
	add_child(flash_inst)

	_effects.append({
		"type": "sphere_expand",
		"node": flash_inst,
		"mat": flash_mat,
		"color": glow_col,
		"age": 0.0,
		"duration": 0.22 if is_bomb else 0.16,
		"start_scale": start_s,
		"end_scale": base_radius * (1.15 if is_bomb else 0.75)
	})

	# 2. Тонкое ударное 3D-кольцо
	var ring_inst := MeshInstance3D.new()
	ring_inst.mesh = _ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.albedo_color = Color(glow_col.r, glow_col.g, glow_col.b, 0.65)
	ring_inst.material_override = ring_mat
	ring_inst.position = world_pos
	ring_inst.rotation_degrees = Vector3(randf_range(65.0, 115.0), randf_range(-25.0, 25.0), 0.0)
	ring_inst.scale = Vector3.ONE * (base_radius * 0.4)
	add_child(ring_inst)

	_effects.append({
		"type": "sphere_expand",
		"node": ring_inst,
		"mat": ring_mat,
		"color": glow_col,
		"age": 0.0,
		"duration": 0.32 if is_bomb else 0.22,
		"start_scale": base_radius * 0.4,
		"end_scale": base_radius * (2.1 if is_bomb else 1.35)
	})

	# 3. Разлетающиеся в 3D каменные осколки метеорита (используют общий кэшированный материал!)
	var shared_shard_mat: StandardMaterial3D = _pick_shard_material(glow_col)
	var shard_count: int = 8 if is_bomb else 5
	for i: int in range(shard_count):
		_trim_excess_effects()
		var shard := MeshInstance3D.new()
		shard.mesh = SpaceEntity3D.get_shared_rock_mesh(i)
		shard.material_override = shared_shard_mat
		shard.position = world_pos
		var shard_s: float = clampf(base_radius * randf_range(0.18, 0.34), 0.16, 0.68)
		shard.scale = Vector3.ONE * shard_s
		add_child(shard)

		var dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-0.6, 0.9)
		).normalized()
		var speed: float = randf_range(14.0, 30.0)

		_effects.append({
			"type": "debris",
			"node": shard,
			"vel": dir * speed,
			"rot": Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
			"age": 0.0,
			"duration": randf_range(0.42, 0.68),
			"start_scale": shard_s
		})


func spawn_hit_spark(world_pos: Vector3, col: Color) -> void:
	_ensure_meshes()
	_trim_excess_effects()
	var spark := MeshInstance3D.new()
	spark.mesh = _sphere_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = col
	spark.material_override = mat
	spark.position = world_pos
	spark.scale = Vector3.ONE * 0.22
	add_child(spark)

	_effects.append({
		"type": "sphere_expand",
		"node": spark,
		"mat": mat,
		"color": col,
		"age": 0.0,
		"duration": 0.12,
		"start_scale": 0.20,
		"end_scale": 0.55
	})


## 3D-дуга молнии между глайдером и объектом при манёвре «На грани» или цепном 3D-лазере
func spawn_graze_arc(from_pos: Vector3, to_pos: Vector3, col: Color = Color(0.28, 0.96, 1.0)) -> void:
	_ensure_meshes()
	_trim_excess_effects()
	var diff: Vector3 = to_pos - from_pos
	var dist: float = diff.length()
	if dist < 0.2:
		return

	var arc := MeshInstance3D.new()
	arc.mesh = _arc_cyl_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = col
	arc.material_override = mat
	add_child(arc)

	arc.global_position = from_pos + diff * 0.5
	var dir: Vector3 = diff / dist
	var up_ref: Vector3 = Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x_axis: Vector3 = up_ref.cross(dir).normalized()
	var z_axis: Vector3 = dir.cross(x_axis).normalized()
	arc.global_transform.basis = Basis(x_axis, dir * dist, z_axis)

	_effects.append({
		"type": "arc_fade",
		"node": arc,
		"mat": mat,
		"color": col,
		"age": 0.0,
		"duration": 0.20
	})


## 3D-кольцо реактивного плазменного следа позади сопел глайдера
func spawn_engine_wake_ring(world_pos: Vector3, col: Color) -> void:
	_ensure_meshes()
	_trim_excess_effects()
	var wake := MeshInstance3D.new()
	wake.mesh = _ring_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.r, col.g, col.b, 0.45)
	wake.material_override = mat
	wake.position = world_pos
	wake.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	wake.scale = Vector3.ONE * 0.42
	add_child(wake)

	_effects.append({
		"type": "wake_ring",
		"node": wake,
		"mat": mat,
		"color": col,
		"age": 0.0,
		"duration": 0.34,
		"start_scale": 0.42,
		"end_scale": 0.95
	})


func update_effects(delta: float) -> void:
	var i: int = _effects.size() - 1
	while i >= 0:
		var fx: Dictionary = _effects[i]
		var node := fx.get("node") as Node3D
		if not is_instance_valid(node):
			_effects.remove_at(i)
			i -= 1
			continue

		var age: float = float(fx["age"]) + delta
		var dur: float = float(fx["duration"])
		if age >= dur:
			node.queue_free()
			_effects.remove_at(i)
			i -= 1
			continue

		fx["age"] = age
		var t: float = clampf(age / dur, 0.0, 1.0)
		var fx_type: String = String(fx["type"])

		if fx_type == "sphere_expand":
			var s: float = lerpf(float(fx["start_scale"]), float(fx["end_scale"]), 1.0 - pow(1.0 - t, 2.0))
			node.scale = Vector3.ONE * s
			var mat := fx.get("mat") as StandardMaterial3D
			if mat != null:
				var c: Color = fx["color"]
				mat.albedo_color = Color(c.r, c.g, c.b, (1.0 - t) * 0.65)
		elif fx_type == "debris":
			var vel: Vector3 = fx["vel"]
			var rot: Vector3 = fx["rot"]
			node.position += vel * delta
			node.rotation += rot * delta
			var s_deb: float = float(fx["start_scale"]) * (1.0 - t * 0.85)
			node.scale = Vector3.ONE * maxf(0.02, s_deb)
		elif fx_type == "arc_fade":
			var mat_a := fx.get("mat") as StandardMaterial3D
			if mat_a != null:
				var ca: Color = fx["color"]
				mat_a.albedo_color = Color(ca.r, ca.g, ca.b, (1.0 - t) * 0.92)
		elif fx_type == "wake_ring":
			node.position.z += 26.0 * delta
			var sw: float = lerpf(float(fx["start_scale"]), float(fx["end_scale"]), t)
			node.scale = Vector3.ONE * sw
			var mat_w := fx.get("mat") as StandardMaterial3D
			if mat_w != null:
				var cw: Color = fx["color"]
				mat_w.albedo_color = Color(cw.r, cw.g, cw.b, (1.0 - t) * 0.45)

		i -= 1
