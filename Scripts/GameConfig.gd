class_name GameConfig
extends RefCounted

## Модуль хранения настроек игры Hyper Glider 3D, параметров Game Feel,
## таблицы рекордов и системы прокачки «Ангар 3D-Апгрейдов».
## Автоматически сохраняет и загружает данные из user://hyper_glider_3d_save.cfg.

const SAVE_PATH: String = "user://hyper_glider_3d_save.cfg"
const MAX_UPGRADE_LEVEL: int = 5
const UPGRADE_COSTS: Array[int] = [40, 100, 220, 420, 750]
const SCORE_PER_BONUS_CRYSTAL: int = 1000
const DEFAULT_STARTING_CRYSTALS: int = 25

var music_volume: float = 0.85
var sfx_volume: float = 0.90
var glider_responsiveness: float = 1.0 # Множитель чувствительности 3D-глайдера (0.6 .. 1.6)
var camera_fov_base: float = 66.0 # Базовый угол обзора 3D-камеры (56 .. 78)
var bg_brightness: float = 0.85 # Яркость туманности и космоса (0.35 .. 1.3)
var vibration_enabled: bool = true
var swipe_control_enabled: bool = true
var invert_y_axis: bool = false
var high_quality_3d: bool = true # Glow + MSAA 2x + динамический свет глайдера (ВЫКЛ = Эконом GPU/батареи)

var high_score_arcade: int = 0
var high_score_assault: int = 0
var best_wave_arcade: int = 1
var best_wave_assault: int = 1
var saved_wave_arcade: int = 1
var saved_wave_assault: int = 1

# Банк Квантовых Кристаллов и уровни 5 систем 3D-апгрейда глайдера (0 .. 5)
var quantum_crystals: int = DEFAULT_STARTING_CRYSTALS # Стартовый запас кристаллов для первого улучшения в Ангаре
var upg_wave_shield: int = 0 # 3D Грави-Щит (до 5 сфер щита + ударная волна при попадании)
var upg_plasma_cannon: int = 0 # Плазменный Усилитель (+скорострельность и мощь базовой и тяжёлой плазмы)
var upg_ammo_bay: int = 0 # Оружейный Отсек (+20%..+100% к длительности спецоружия и боезапасу ракет)
var upg_wing_drones: int = 0 # Крыльевые 3D-Дроны (автоматические плазменные дроны-ведомые слева и справа)
var upg_hyper_core: int = 0 # Гипер-Реактор и Магнит (+радиус захвата сфер, +заряд ядра, +длительность гипер-туннеля)


func load_data() -> void:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		return

	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.85)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.90)), 0.0, 1.0)
	glider_responsiveness = clampf(float(cfg.get_value("feel", "glider_responsiveness", 1.0)), 0.6, 1.6)
	camera_fov_base = clampf(float(cfg.get_value("feel", "camera_fov_base", 66.0)), 56.0, 78.0)
	bg_brightness = clampf(float(cfg.get_value("feel", "bg_brightness", 0.85)), 0.35, 1.3)
	vibration_enabled = bool(cfg.get_value("feel", "vibration_enabled", true))
	swipe_control_enabled = bool(cfg.get_value("feel", "swipe_control_enabled", true))
	invert_y_axis = bool(cfg.get_value("feel", "invert_y_axis", false))
	high_quality_3d = bool(cfg.get_value("feel", "high_quality_3d", true))

	high_score_arcade = maxi(0, int(cfg.get_value("records", "high_score_arcade", 0)))
	high_score_assault = maxi(0, int(cfg.get_value("records", "high_score_assault", 0)))
	best_wave_arcade = maxi(1, int(cfg.get_value("records", "best_wave_arcade", 1)))
	best_wave_assault = maxi(1, int(cfg.get_value("records", "best_wave_assault", 1)))
	saved_wave_arcade = clampi(int(cfg.get_value("records", "saved_wave_arcade", best_wave_arcade)), 1, best_wave_arcade)
	saved_wave_assault = clampi(int(cfg.get_value("records", "saved_wave_assault", best_wave_assault)), 1, best_wave_assault)

	if cfg.has_section_key("upgrades", "quantum_crystals"):
		quantum_crystals = maxi(0, int(cfg.get_value("upgrades", "quantum_crystals", DEFAULT_STARTING_CRYSTALS)))
	elif cfg.has_section_key("upgrades", "upgrade_points"):
		# Мягкая миграция со старой системы очков в Квантовые Кристаллы
		var legacy_pts: int = maxi(0, int(cfg.get_value("upgrades", "upgrade_points", 0)))
		quantum_crystals = clampi(legacy_pts / 25, DEFAULT_STARTING_CRYSTALS, 140)
	else:
		quantum_crystals = DEFAULT_STARTING_CRYSTALS
	upg_wave_shield = clampi(int(cfg.get_value("upgrades", "upg_wave_shield", 0)), 0, MAX_UPGRADE_LEVEL)
	upg_plasma_cannon = clampi(int(cfg.get_value("upgrades", "upg_plasma_cannon", 0)), 0, MAX_UPGRADE_LEVEL)
	upg_ammo_bay = clampi(int(cfg.get_value("upgrades", "upg_ammo_bay", 0)), 0, MAX_UPGRADE_LEVEL)
	upg_wing_drones = clampi(int(cfg.get_value("upgrades", "upg_wing_drones", 0)), 0, MAX_UPGRADE_LEVEL)
	upg_hyper_core = clampi(int(cfg.get_value("upgrades", "upg_hyper_core", 0)), 0, MAX_UPGRADE_LEVEL)


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("feel", "glider_responsiveness", glider_responsiveness)
	cfg.set_value("feel", "camera_fov_base", camera_fov_base)
	cfg.set_value("feel", "bg_brightness", bg_brightness)
	cfg.set_value("feel", "vibration_enabled", vibration_enabled)
	cfg.set_value("feel", "swipe_control_enabled", swipe_control_enabled)
	cfg.set_value("feel", "invert_y_axis", invert_y_axis)
	cfg.set_value("feel", "high_quality_3d", high_quality_3d)

	cfg.set_value("records", "high_score_arcade", high_score_arcade)
	cfg.set_value("records", "high_score_assault", high_score_assault)
	cfg.set_value("records", "best_wave_arcade", best_wave_arcade)
	cfg.set_value("records", "best_wave_assault", best_wave_assault)
	cfg.set_value("records", "saved_wave_arcade", saved_wave_arcade)
	cfg.set_value("records", "saved_wave_assault", saved_wave_assault)

	cfg.set_value("upgrades", "quantum_crystals", quantum_crystals)
	cfg.set_value("upgrades", "upg_wave_shield", upg_wave_shield)
	cfg.set_value("upgrades", "upg_plasma_cannon", upg_plasma_cannon)
	cfg.set_value("upgrades", "upg_ammo_bay", upg_ammo_bay)
	cfg.set_value("upgrades", "upg_wing_drones", upg_wing_drones)
	cfg.set_value("upgrades", "upg_hyper_core", upg_hyper_core)
	cfg.save(SAVE_PATH)


func get_upgrade_level(key: String) -> int:
	match key:
		"wave_shield":
			return upg_wave_shield
		"plasma_cannon":
			return upg_plasma_cannon
		"ammo_bay":
			return upg_ammo_bay
		"wing_drones":
			return upg_wing_drones
		"hyper_core":
			return upg_hyper_core
	return 0


func set_upgrade_level(key: String, lvl: int) -> void:
	var c_lvl: int = clampi(lvl, 0, MAX_UPGRADE_LEVEL)
	match key:
		"wave_shield":
			upg_wave_shield = c_lvl
		"plasma_cannon":
			upg_plasma_cannon = c_lvl
		"ammo_bay":
			upg_ammo_bay = c_lvl
		"wing_drones":
			upg_wing_drones = c_lvl
		"hyper_core":
			upg_hyper_core = c_lvl


func get_upgrade_cost(key: String) -> int:
	var lvl: int = get_upgrade_level(key)
	if lvl >= MAX_UPGRADE_LEVEL:
		return 0
	return UPGRADE_COSTS[lvl]


func add_crystals(amount: int, save_now: bool = false) -> void:
	if amount <= 0:
		return
	quantum_crystals += amount
	if save_now:
		save_data()


func can_buy_upgrade(key: String) -> bool:
	var lvl: int = get_upgrade_level(key)
	if lvl >= MAX_UPGRADE_LEVEL:
		return false
	return quantum_crystals >= get_upgrade_cost(key)


func buy_upgrade(key: String) -> bool:
	if not can_buy_upgrade(key):
		return false
	var cost: int = get_upgrade_cost(key)
	quantum_crystals = maxi(0, quantum_crystals - cost)
	set_upgrade_level(key, get_upgrade_level(key) + 1)
	save_data()
	return true


func get_total_spent_crystals() -> int:
	var total: int = 0
	for key: String in ["wave_shield", "plasma_cannon", "ammo_bay", "wing_drones", "hyper_core"]:
		var lvl: int = get_upgrade_level(key)
		for i: int in range(lvl):
			total += UPGRADE_COSTS[i]
	return total


func refund_all_upgrades() -> int:
	var refunded: int = get_total_spent_crystals()
	if refunded <= 0:
		return 0
	quantum_crystals += refunded
	upg_wave_shield = 0
	upg_plasma_cannon = 0
	upg_ammo_bay = 0
	upg_wing_drones = 0
	upg_hyper_core = 0
	save_data()
	return refunded


func get_max_shields() -> int:
	var extra: int = 0
	if upg_wave_shield >= 2:
		extra += 1
	if upg_wave_shield >= 5:
		extra += 1
	return 3 + extra


func get_plasma_fire_rate_multiplier() -> float:
	return 1.0 + float(upg_plasma_cannon) * 0.14


func get_plasma_damage_bonus() -> float:
	return float(upg_plasma_cannon) * 4.5


func get_ammo_multiplier() -> float:
	return 1.0 + float(upg_ammo_bay) * 0.20


func get_magnet_multiplier() -> float:
	return 1.0 + float(upg_hyper_core) * 0.25


func get_hyper_duration_bonus() -> float:
	return float(upg_hyper_core) * 0.45


func get_high_score(is_assault_mode: bool) -> int:
	return high_score_assault if is_assault_mode else high_score_arcade


func get_best_wave(is_assault_mode: bool) -> int:
	return best_wave_assault if is_assault_mode else best_wave_arcade


func get_saved_wave(is_assault_mode: bool) -> int:
	return saved_wave_assault if is_assault_mode else saved_wave_arcade


func set_saved_wave(is_assault_mode: bool, w: int) -> void:
	var max_w: int = maxi(1, get_best_wave(is_assault_mode))
	var clamped_w: int = clampi(w, 1, max_w)
	if is_assault_mode:
		saved_wave_assault = clamped_w
	else:
		saved_wave_arcade = clamped_w
	save_data()


func update_wave_checkpoint(is_assault_mode: bool, current_w: int) -> void:
	var w: int = maxi(1, current_w)
	if is_assault_mode:
		saved_wave_assault = w
		if w > best_wave_assault:
			best_wave_assault = w
	else:
		saved_wave_arcade = w
		if w > best_wave_arcade:
			best_wave_arcade = w
	save_data()


func register_run_result(is_assault_mode: bool, score: int, wave: int) -> bool:
	var is_new_record: bool = false
	var w: int = maxi(1, wave)
	if is_assault_mode:
		saved_wave_assault = w
		if score > high_score_assault:
			high_score_assault = score
			is_new_record = true
		if w > best_wave_assault:
			best_wave_assault = w
	else:
		saved_wave_arcade = w
		if score > high_score_arcade:
			high_score_arcade = score
			is_new_record = true
		if w > best_wave_arcade:
			best_wave_arcade = w
	save_data()
	return is_new_record
