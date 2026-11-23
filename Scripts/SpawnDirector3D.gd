class_name SpawnDirector3D
extends RefCounted

## Боевой 3D-режиссёр спавна объектов:
## - Генерирует потоки различных 3D-метеоритов (малые, средние, гигантские валуны, плазменные бомбы, кристаллы),
## - Выстраивает метеоритные арки/кольца и коридоры,
## - Спавнит энергетические сферы, щиты, капсулы спецоружия и порталы 3D Чёрных дыр,
## - Внутри 3D Гипер-туннеля выстраивает спиральные ленты энергетических сфер и бонусов!

const SPAWN_Z: float = -168.0
const TUNNEL_SPAWN_Z: float = -135.0

var _meteor_timer: float = 0.45
var _orb_timer: float = 1.6
var _pattern_timer: float = 5.5
var _black_hole_timer: float = 22.0
var _tunnel_ribbon_timer: float = 0.22
var _tunnel_angle: float = 0.0


func reset_director() -> void:
	_meteor_timer = 0.35
	_orb_timer = 1.4
	_pattern_timer = 5.2
	_black_hole_timer = 21.0
	_tunnel_ribbon_timer = 0.15
	_tunnel_angle = 0.0


func update_spawning(
	delta: float,
	entities_root: Node3D,
	wave_num: int,
	forward_speed: float,
	is_assault_mode: bool,
	is_tunnel_mode: bool,
	has_active_black_hole: bool
) -> void:
	if is_tunnel_mode:
		_update_tunnel_spawns(delta, entities_root, forward_speed)
		return

	var intensity: float = (1.28 if is_assault_mode else 1.0) * (1.0 + float(wave_num - 1) * 0.08)

	# 1. Одиночные и парные 3D-метеориты
	_meteor_timer -= delta * intensity
	if _meteor_timer <= 0.0:
		_meteor_timer = randf_range(0.34, 0.64)
		_spawn_random_meteor(entities_root, wave_num, forward_speed)
		if randf() < 0.38:
			_spawn_random_meteor(entities_root, wave_num, forward_speed, SPAWN_Z - randf_range(8.0, 16.0))

	# 2. Фигурные 3D-паттерны (кольцо астероидов, диагональная гряда, плазменная ловушка)
	_pattern_timer -= delta
	if _pattern_timer <= 0.0:
		_pattern_timer = randf_range(5.4, 8.2) / clampf(intensity, 1.0, 1.7)
		var pat: int = randi() % 3
		if pat == 0:
			_spawn_meteor_ring_gate(entities_root, wave_num, forward_speed)
		elif pat == 1:
			_spawn_diagonal_asteroid_wall(entities_root, wave_num, forward_speed)
		else:
			_spawn_plasma_cluster(entities_root, wave_num, forward_speed)

	# 3. Энергетические сферы и капсулы вооружения
	_orb_timer -= delta
	if _orb_timer <= 0.0:
		_orb_timer = randf_range(1.65, 2.65)
		_spawn_random_pickup(entities_root, forward_speed)

	# 4. Портал 3D Чёрной дыры (ведущий в 3D Гипер-туннель!)
	if not has_active_black_hole:
		_black_hole_timer -= delta
		if _black_hole_timer <= 0.0:
			_black_hole_timer = randf_range(24.0, 32.0)
			_spawn_black_hole_portal(entities_root, forward_speed)


func _spawn_random_meteor(entities_root: Node3D, wave_num: int, forward_speed: float, custom_z: float = SPAWN_Z) -> void:
	var pos := Vector3(
		randf_range(-7.2, 7.2),
		randf_range(-4.4, 5.6),
		custom_z
	)

	var roll: float = randf()
	var kind: SpaceEntity3D.Kind = SpaceEntity3D.Kind.METEOR_ROCK
	var rad: float = randf_range(1.15, 2.35)

	if roll < 0.14:
		kind = SpaceEntity3D.Kind.METEOR_PLASMA_GREEN
		rad = randf_range(1.45, 2.05)
	elif roll < 0.23:
		kind = SpaceEntity3D.Kind.METEOR_PLASMA_GOLD
		rad = randf_range(1.65, 2.25)
	elif roll < 0.34:
		kind = SpaceEntity3D.Kind.METEOR_CRYSTAL
		rad = randf_range(1.35, 1.95)
	elif roll > 0.86:
		# Гигантский валун
		rad = randf_range(2.55, 3.35)

	var ent := SpaceEntity3D.new()
	entities_root.add_child(ent)
	ent.setup_entity(kind, pos, forward_speed * randf_range(0.92, 1.15), rad, wave_num)


func _spawn_meteor_ring_gate(entities_root: Node3D, wave_num: int, forward_speed: float) -> void:
	var center_x: float = randf_range(-2.6, 2.6)
	var center_y: float = randf_range(-1.2, 2.0)
	var ring_r: float = 4.4
	var count: int = 8

	for i: int in range(count):
		var angle: float = (float(i) / float(count)) * TAU
		var pos := Vector3(
			clampf(center_x + cos(angle) * ring_r, -7.5, 7.5),
			clampf(center_y + sin(angle) * ring_r, -4.6, 5.8),
			SPAWN_Z - float(i % 2) * 3.0
		)
		var ent := SpaceEntity3D.new()
		entities_root.add_child(ent)
		ent.setup_entity(SpaceEntity3D.Kind.METEOR_ROCK, pos, forward_speed, 1.25, wave_num)

	# В центре кольца — ценная сфера оружия или Гипер-Ядра!
	var center_orb := SpaceEntity3D.new()
	entities_root.add_child(center_orb)
	var orb_kind: SpaceEntity3D.Kind = _pick_weapon_or_hyper_kind()
	center_orb.setup_entity(orb_kind, Vector3(center_x, center_y, SPAWN_Z), forward_speed, 1.2, wave_num)


func _spawn_diagonal_asteroid_wall(entities_root: Node3D, wave_num: int, forward_speed: float) -> void:
	var dir_sign: float = 1.0 if randi() % 2 == 0 else -1.0
	for i: int in range(5):
		var t: float = float(i) / 4.0 - 0.5
		var pos := Vector3(
			t * 11.5 * dir_sign,
			t * 7.2,
			SPAWN_Z - float(i) * 5.5
		)
		var ent := SpaceEntity3D.new()
		entities_root.add_child(ent)
		var k: SpaceEntity3D.Kind = SpaceEntity3D.Kind.METEOR_PLASMA_GREEN if i == 2 else SpaceEntity3D.Kind.METEOR_ROCK
		ent.setup_entity(k, pos, forward_speed, 1.55, wave_num)


func _spawn_plasma_cluster(entities_root: Node3D, wave_num: int, forward_speed: float) -> void:
	var cx: float = randf_range(-3.8, 3.8)
	var cy: float = randf_range(-2.2, 2.8)

	var bomb := SpaceEntity3D.new()
	entities_root.add_child(bomb)
	var b_kind: SpaceEntity3D.Kind = SpaceEntity3D.Kind.METEOR_PLASMA_GOLD if randf() < 0.45 else SpaceEntity3D.Kind.METEOR_PLASMA_GREEN
	bomb.setup_entity(b_kind, Vector3(cx, cy, SPAWN_Z), forward_speed, 1.85, wave_num)

	for offset: Vector3 in [Vector3(-2.8, 1.4, -4.0), Vector3(2.8, -1.4, -4.0), Vector3(0.0, 2.6, -7.0)]:
		var rock := SpaceEntity3D.new()
		entities_root.add_child(rock)
		rock.setup_entity(
			SpaceEntity3D.Kind.METEOR_ROCK,
			Vector3(clampf(cx + offset.x, -7.2, 7.2), clampf(cy + offset.y, -4.5, 5.6), SPAWN_Z + offset.z),
			forward_speed,
			1.35,
			wave_num
		)


func _spawn_random_pickup(entities_root: Node3D, forward_speed: float) -> void:
	var pos := Vector3(
		randf_range(-6.2, 6.2),
		randf_range(-3.6, 4.6),
		SPAWN_Z
	)
	var roll: float = randf()
	var kind: SpaceEntity3D.Kind = SpaceEntity3D.Kind.ORB_ENERGY
	if roll < 0.42:
		kind = SpaceEntity3D.Kind.ORB_ENERGY
	elif roll < 0.58:
		kind = SpaceEntity3D.Kind.ORB_HYPER_CORE
	elif roll < 0.68:
		kind = SpaceEntity3D.Kind.ORB_SHIELD
	else:
		kind = _pick_weapon_or_hyper_kind()

	var orb := SpaceEntity3D.new()
	entities_root.add_child(orb)
	orb.setup_entity(kind, pos, forward_speed, 1.15, 1)


func _pick_weapon_or_hyper_kind() -> SpaceEntity3D.Kind:
	var weapons: Array[SpaceEntity3D.Kind] = [
		SpaceEntity3D.Kind.ORB_WEAPON_PLASMA,
		SpaceEntity3D.Kind.ORB_WEAPON_VULCAN,
		SpaceEntity3D.Kind.ORB_WEAPON_LASER,
		SpaceEntity3D.Kind.ORB_WEAPON_MISSILE
	]
	return weapons[randi() % weapons.size()]


func _spawn_black_hole_portal(entities_root: Node3D, forward_speed: float) -> void:
	var pos := Vector3(
		randf_range(-3.5, 3.5),
		randf_range(-1.5, 2.5),
		SPAWN_Z - 15.0
	)
	var bh := SpaceEntity3D.new()
	entities_root.add_child(bh)
	bh.setup_entity(SpaceEntity3D.Kind.BLACK_HOLE_PORTAL, pos, forward_speed, 4.6, 1)


func _update_tunnel_spawns(delta: float, entities_root: Node3D, forward_speed: float) -> void:
	# Внутри 3D Гипер-туннеля спавним спиральные ленты энергетических сфер и оружия!
	_tunnel_ribbon_timer -= delta
	if _tunnel_ribbon_timer > 0.0:
		return
	_tunnel_ribbon_timer = 0.16
	_tunnel_angle += 0.52

	var rad: float = 3.8
	var pos := Vector3(
		cos(_tunnel_angle) * rad,
		sin(_tunnel_angle) * rad * 0.78 + 0.5,
		TUNNEL_SPAWN_Z
	)

	var kind: SpaceEntity3D.Kind = SpaceEntity3D.Kind.ORB_ENERGY
	var r: float = randf()
	if r < 0.18:
		kind = _pick_weapon_or_hyper_kind()
	elif r < 0.34:
		kind = SpaceEntity3D.Kind.ORB_HYPER_CORE

	var orb := SpaceEntity3D.new()
	entities_root.add_child(orb)
	orb.setup_entity(kind, pos, forward_speed * 1.25, 1.25, 1)
