extends Node3D

## Главный 3D-контроллер игры Hyper Glider 3D (Godot 4.7).
## Управляет 3D-камерой от 3-го лица (сверху и сзади глайдера), полётом сквозь космос и метеориты,
## стрельбой плазмой и мульти-арсеналом, прорывом сквозь 3D Чёрную дыру в сверхсветовой 3D Гипер-туннель,
## системой волн, Ангаром 3D-Апгрейдов и неоновым HUD.

const VIEW_W: float = 540.0
const VIEW_H: float = 960.0
const MAX_FLOATING_LABELS: int = 24

var _view_w: float = 540.0
var _view_h: float = 960.0
var _safe_top_vp: float = 0.0
var _safe_bot_vp: float = 0.0

enum GameState {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

var _state: GameState = GameState.MENU
var _config: GameConfig
var _audio: SynthAudioController
var _env3d: SpaceEnvironment3D
var _glider: Glider3DController
var _camera: Camera3D
var _fx3d: FxManager3D
var _director: SpawnDirector3D

var _entities_root: Node3D
var _frame_entities: Array[Node] = []
var _projectiles_root: Node3D
var _active_projectiles: Array[WeaponProjectile3D] = []
var _free_projectiles: Array[WeaponProjectile3D] = []

# Параметры текущего вылета
var _is_assault_mode: bool = false
var _score: int = 0
var _last_banked_score: int = 0
var _run_crystals: int = 0
var _crystals_dirty_save: bool = false
var _wave: int = 1
var _wave_timer: float = 0.0
var _wave_duration: float = 26.0
var _shields: int = 3
var _max_shields: int = 3
var _graze_shield_progress: int = 0
var _slowmo_timer: float = 0.0
var _wake_ring_timer: float = 0.0
var _wingtip_trail_timer: float = 0.0
var _prev_wingtips: Array[Vector3] = []
var _last_tap_msec: int = 0
var _last_back_action_msec: int = 0
var _exit_confirm_msec: int = 0
var _last_tap_pos: Vector2 = Vector2.ZERO
var _combo: int = 1
var _combo_timer: float = 0.0
var _stat_destroyed: int = 0
var _stat_grazes: int = 0
var _max_combo_reached: int = 1
var _boost_fov_kick: float = 0.0
var _bar_boss_trail: ProgressBar
var _boss_bar_trail_val: float = 100.0

var _base_forward_speed: float = 42.0
var _hyper_charge: float = 0.0 # 0.0 .. 100.0
var _hyper_timer: float = 0.0
var _tunnel_timer: float = 0.0
var _sector_index: int = 0
var _active_boss: SpaceEntity3D = null

# Таймеры и боезапас мульти-арсенала
var _timer_heavy_plasma: float = 0.0
var _timer_vulcan: float = 0.0
var _timer_laser: float = 0.0
var _ammo_missiles: int = 0

var _cd_base_plasma: float = 0.0
var _cd_heavy_plasma: float = 0.0
var _cd_vulcan: float = 0.0
var _cd_missile: float = 0.0
var _cd_drones: float = 0.0

# 3D-камера и тряска
var _cam_shake: float = 0.0
var _cam_current_fov: float = 66.0
var _screen_flash_alpha: float = 0.0
var _screen_flash_color: Color = Color(0.25, 0.95, 1.0)
var _edge_flash_alpha: float = 0.0
var _edge_flash_color: Color = Color(0.25, 0.95, 1.0)

# Тач / мышь управление в 3D
var _is_dragging: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO
var _active_touches: Dictionary = {}

# UI-элементы (CanvasLayer)
var _ui_layer: CanvasLayer
var _ui_root: Control
var _flash_rect: ColorRect
var _edge_flash_panel: Panel
var _floating_texts_root: Control
var _floating_labels: Array[Dictionary] = []
var _free_floating_labels: Array[Label] = []
var _modal_cards: Array[Dictionary] = []

var _hud_root: Control
var _top_panel: PanelContainer
var _hyper_hbox: HBoxContainer
var _slots_hbox: HBoxContainer
var _lbl_score: Label
var _lbl_wave: Label
var _lbl_sector: Label
var _lbl_shields: Label
var _shield_dots: Array[ColorRect] = []
var _lbl_graze_progress: Label
var _lbl_combo: Label
var _lbl_banner: Label
var _banner_timer: float = 0.0
var _boss_hud_panel: PanelContainer
var _lbl_boss_title: Label
var _bar_boss_hp: ProgressBar

var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _btn_hyper: Button
var _bar_hyper: ProgressBar

var _menu_overlay: Control
var _lbl_menu_records: Label
var _lbl_menu_credits: Label
var _btn_mode_arcade: Button
var _btn_mode_assault: Button
var _btn_wave_prev: Button
var _btn_wave_next: Button
var _btn_start_launch: Button
var _lbl_start_wave: Label

var _pause_overlay: Control
var _gameover_overlay: Control
var _lbl_gameover_stats: Label
var _hangar_overlay: Control
var _lbl_hangar_credits: Label
var _hangar_rows: Array[Dictionary] = []
var _overclock_row: Dictionary = {}
var _hull_rows: Array[Dictionary] = []
var _settings_overlay: Control
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

# Стартовый экран прогрева 3D-ресурсов и шейдеров с прогресс-баром
var _boot_loader_overlay: Control
var _boot_panel: PanelContainer
var _lbl_boot_status: Label
var _bar_boot_load: ProgressBar
var _boot_step: int = 0
var _boot_fade_timer: float = 0.0
var _shader_warmup_node: Node3D = null

# Dirty-check кэш HUD (исключает лишнее форматирование строк и перекраску StyleBoxFlat каждый кадр)
var _hud_c_score: int = -1
var _hud_c_wave: int = -1
var _hud_c_combo: int = -1
var _hud_c_crystals: int = -1
var _hud_c_shields: int = -1
var _hud_c_max_shields: int = -1
var _hud_c_graze: int = -1
var _hud_c_sector_mode: int = -1
var _hud_c_sector_tenths: int = -1
var _hud_c_sector_idx: int = -1
var _hud_c_hyper_mode: int = -1
var _hud_c_hyper_val: int = -1
var _hud_c_boss_pct: int = -1
var _hud_c_boss_rage: int = -1
var _hud_c_slot_val: Array[int] = [-99, -99, -99, -99]


func _ready() -> void:
	randomize()
	_config = GameConfig.new()
	_config.load_data()

	_audio = SynthAudioController.new()
	add_child(_audio)
	_audio.apply_volumes(_config.music_volume, _config.sfx_volume)

	_env3d = SpaceEnvironment3D.new()
	add_child(_env3d)
	_env3d.set_brightness(_config.bg_brightness)

	_entities_root = Node3D.new()
	add_child(_entities_root)

	_projectiles_root = Node3D.new()
	add_child(_projectiles_root)

	_fx3d = FxManager3D.new()
	add_child(_fx3d)

	_glider = Glider3DController.new()
	add_child(_glider)
	_glider.apply_hull_skin(_config.selected_hull, _config.get_hull_barrel_roll_cd_mult())
	_glider.set_drones_active(_config.upg_wing_drones > 0)

	_setup_camera_3d()
	_director = SpawnDirector3D.new()
	_apply_3d_quality_settings()
	_build_all_ui()
	_apply_hud_safe_margins()
	if not get_viewport().size_changed.is_connected(_apply_hud_safe_margins):
		get_viewport().size_changed.connect(_apply_hud_safe_margins)
	_enter_menu_state()


func _apply_3d_quality_settings() -> void:
	if _env3d != null:
		_env3d.set_high_quality_mode(_config.high_quality_3d)
	if _glider != null:
		_glider.set_dynamic_lights_enabled(_config.high_quality_3d)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back_navigation()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_active_touches.clear()
			_is_dragging = false
			_bank_uncommitted_credits()
			if _state == GameState.PLAYING:
				_toggle_pause(true)
			if _config != null:
				_config.save_data()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_bank_uncommitted_credits()
			if _config != null:
				_config.save_data()


func _award_crystals(amount: int, save_now: bool = false) -> void:
	if amount <= 0 or _config == null:
		return
	_run_crystals += amount
	_config.add_crystals(amount, save_now)
	if not save_now:
		_crystals_dirty_save = true


func _scale_score(raw_pts: int) -> int:
	if _config == null:
		return raw_pts
	return int(round(float(raw_pts) * _config.get_overclock_score_multiplier()))


func _bank_uncommitted_credits() -> void:
	if _config == null:
		return
	# Боевые очки конвертируются в Квантовые Кристаллы по курсу 1 КР за 1000 очков (остаток копится)
	if _score > _last_banked_score:
		var whole: int = (_score - _last_banked_score) / GameConfig.SCORE_PER_BONUS_CRYSTAL
		if whole > 0:
			_last_banked_score += whole * GameConfig.SCORE_PER_BONUS_CRYSTAL
			_award_crystals(whole, false)
	if _crystals_dirty_save:
		_crystals_dirty_save = false
		_config.save_data()


func _open_hangar_overlay() -> void:
	_audio.play_ui_click()
	_refresh_hangar_ui()
	_hangar_overlay.visible = true


func _open_settings_overlay() -> void:
	_audio.play_ui_click()
	_settings_overlay.visible = true


func _close_all_modals() -> void:
	for overlay: Control in [_menu_overlay, _pause_overlay, _gameover_overlay, _hangar_overlay, _settings_overlay]:
		if overlay != null:
			overlay.visible = false


func _handle_back_navigation() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_back_action_msec < 260:
		return
	_last_back_action_msec = now_msec

	if _settings_overlay != null and _settings_overlay.visible:
		_audio.play_ui_click()
		_settings_overlay.visible = false
		_exit_confirm_msec = 0
		return
	if _hangar_overlay != null and _hangar_overlay.visible:
		_audio.play_ui_click()
		_hangar_overlay.visible = false
		_exit_confirm_msec = 0
		return
	if _state == GameState.GAME_OVER:
		_audio.play_ui_click()
		_enter_menu_state()
		_exit_confirm_msec = 0
		return
	if _state == GameState.PLAYING:
		_toggle_pause(true)
		_exit_confirm_msec = now_msec
		_show_toast("Для выхода нажмите еще раз")
		return
	if _state == GameState.PAUSED or _state == GameState.MENU:
		if _exit_confirm_msec > 0 and (now_msec - _exit_confirm_msec) <= 2000:
			_bank_uncommitted_credits()
			if _config != null:
				_config.save_data()
			get_tree().quit()
		else:
			_exit_confirm_msec = now_msec
			_audio.play_ui_click()
			_show_toast("Для выхода нажмите еще раз")


func _build_toast_ui() -> void:
	_toast_panel = UiBuilder.create_glass_panel(
		Color(0.02, 0.06, 0.14, 0.94),
		Color(0.22, 0.85, 0.98, 0.85),
		14,
		20.0,
		12.0
	)
	_toast_panel.position = Vector2(50.0, _view_h - 115.0 - _safe_bot_vp)
	_toast_panel.size = Vector2(_view_w - 100.0, 50.0)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_ui_root.add_child(_toast_panel)

	_toast_label = UiBuilder.create_label("", 17, Color(0.92, 0.98, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 3)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)


func _show_toast(msg: String) -> void:
	if _toast_panel == null or _toast_label == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = msg
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.14)
	_toast_tween.tween_interval(1.65)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.30)
	_toast_tween.tween_callback(func() -> void:
		if _toast_panel != null:
			_toast_panel.visible = false
	)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	_active_touches.clear()
	_modal_cards.clear()
	_floating_labels.clear()
	_free_floating_labels.clear()
	_hangar_rows.clear()
	_slot_panels.clear()
	_slot_labels.clear()
	_shield_dots.clear()
	_prev_wingtips.clear()
	_active_projectiles.clear()
	_free_projectiles.clear()
	UiBuilder.clear_static_caches()
	WeaponProjectile3D.clear_static_caches()
	SpaceEntity3D.clear_static_caches()
	FxManager3D.clear_static_caches()


func _setup_camera_3d() -> void:
	_camera = Camera3D.new()
	_camera.fov = _config.camera_fov_base
	_cam_current_fov = _config.camera_fov_base
	_camera.near = 0.15
	_camera.far = 260.0
	# Вид от 3-го лица: позади и сверху 3D-глайдера
	_camera.position = Vector3(0.0, 3.35, 9.2)
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.35, -24.0), Vector3.UP)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_BACK:
				_handle_back_navigation()
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_P:
				if _state == GameState.PLAYING:
					_toggle_pause(true)
				elif _state == GameState.PAUSED:
					_toggle_pause(false)
			elif ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER:
				if _state == GameState.PLAYING:
					_try_activate_hyper_core()
			elif ke.keycode == KEY_Q:
				if _state == GameState.PLAYING:
					_try_perform_barrel_roll(-1.0)
			elif ke.keycode == KEY_E or ke.keycode == KEY_SHIFT:
				if _state == GameState.PLAYING:
					_try_perform_barrel_roll(1.0)

	if _state != GameState.PLAYING:
		_is_dragging = false
		_active_touches.clear()
		return

	# Верхняя граница игровой зоны касания — сразу под верхней строкой кнопки паузы, и до самого низа экрана без ограничений!
	var touch_top_limit: float = _safe_top_vp + 64.0

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if st.position.y >= touch_top_limit:
				_check_double_tap_barrel_roll(st.position)
				_active_touches[st.index] = st.position
				_is_dragging = true
				_last_drag_pos = st.position
				if not _config.swipe_control_enabled:
					_set_glider_target_from_screen(st.position)
		else:
			_active_touches.erase(st.index)
			if _active_touches.is_empty():
				_is_dragging = false

	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _active_touches.has(sd.index):
			var prev_pos: Vector2 = _active_touches[sd.index]
			_active_touches[sd.index] = sd.position
			_apply_touch_delta(sd.position - prev_pos, sd.position)
		elif sd.position.y >= touch_top_limit:
			_active_touches[sd.index] = sd.position
			_is_dragging = true
			_last_drag_pos = sd.position

	elif event is InputEventMouseButton and not OS.has_feature("mobile"):
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.position.y >= touch_top_limit:
					_check_double_tap_barrel_roll(mb.position)
					_is_dragging = true
					_last_drag_pos = mb.position
					if not _config.swipe_control_enabled:
						_set_glider_target_from_screen(mb.position)
			else:
				_is_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_try_perform_barrel_roll(1.0 if mb.position.x >= _view_w * 0.5 else -1.0)

	elif event is InputEventMouseMotion and not OS.has_feature("mobile"):
		var mm := event as InputEventMouseMotion
		if _is_dragging:
			var delta_px: Vector2 = mm.position - _last_drag_pos
			_last_drag_pos = mm.position
			_apply_touch_delta(delta_px, mm.position)


func _apply_touch_delta(delta_px: Vector2, cur_pos: Vector2) -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = Vector2(_view_w, _view_h)

	if _config.swipe_control_enabled:
		var sens: float = _config.glider_responsiveness
		var dx: float = (delta_px.x / vp_size.x) * (Glider3DController.BOUNDS_X * 2.35) * sens
		var y_sign: float = 1.0 if _config.invert_y_axis else -1.0
		var dy: float = (delta_px.y / vp_size.y) * ((Glider3DController.BOUNDS_Y_MAX - Glider3DController.BOUNDS_Y_MIN) * 2.25) * sens * y_sign
		_glider.move_target_by_delta(Vector2(dx, dy))
	else:
		_set_glider_target_from_screen(cur_pos)


func _check_double_tap_barrel_roll(tap_pos: Vector2) -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_tap_msec <= 290 and tap_pos.distance_to(_last_tap_pos) <= 92.0:
		_last_tap_msec = 0
		var roll_dir: float = 1.0 if tap_pos.x >= _view_w * 0.5 else -1.0
		if absf(_glider.current_vel.x) > 1.5:
			roll_dir = signf(_glider.current_vel.x)
		_try_perform_barrel_roll(roll_dir)
	else:
		_last_tap_msec = now_msec
		_last_tap_pos = tap_pos


func _try_perform_barrel_roll(dir_sign: float) -> void:
	if _glider != null and _glider.trigger_barrel_roll(dir_sign):
		_audio.play_graze(_combo)
		_trigger_edge_flash(Color(0.28, 0.96, 1.0), 0.42)


func _set_glider_target_from_screen(screen_pos: Vector2) -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = Vector2(_view_w, _view_h)
	var nx: float = clampf((screen_pos.x / vp_size.x) * 2.0 - 1.0, -1.0, 1.0)
	var ny: float = clampf(1.0 - (screen_pos.y / vp_size.y) * 2.0, -1.0, 1.0)
	if _config.invert_y_axis:
		ny = -ny
	_glider.set_target_normalized(Vector2(nx, ny))


func _process(delta: float) -> void:
	var raw_dt: float = minf(delta, 0.05)
	if _slowmo_timer > 0.0:
		_slowmo_timer -= raw_dt
		if _slowmo_timer <= 0.0:
			Engine.time_scale = 1.0
	var dt: float = raw_dt

	if _screen_flash_alpha > 0.0:
		_screen_flash_alpha = maxf(0.0, _screen_flash_alpha - dt * 2.2)
		if _flash_rect != null:
			_flash_rect.color = Color(_screen_flash_color.r, _screen_flash_color.g, _screen_flash_color.b, _screen_flash_alpha)

	if _edge_flash_alpha > 0.0:
		_edge_flash_alpha = maxf(0.0, _edge_flash_alpha - dt * 2.6)
		if _edge_flash_panel != null:
			_edge_flash_panel.visible = _edge_flash_alpha > 0.01
			var esb := _edge_flash_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if esb != null:
				esb.border_color = Color(_edge_flash_color.r, _edge_flash_color.g, _edge_flash_color.b, _edge_flash_alpha)

	_update_floating_labels(dt)
	_update_boot_loader(dt)

	if _state == GameState.MENU:
		_update_menu_demo_3d(dt)
		return

	if _state != GameState.PLAYING:
		return

	_update_gameplay_3d(dt)


func _update_menu_demo_3d(delta: float) -> void:
	# В главном меню 3D-глайдер плавно парит на фоне 3D-звёзд и туманности
	var t: float = float(Time.get_ticks_msec()) * 0.001
	_glider.target_pos = Vector2(sin(t * 0.85) * 3.4, cos(t * 0.65) * 1.6)
	_glider.update_glider(delta, Vector2.ZERO, 0.85, false, false, false, 3)
	_env3d.update_environment(delta, 38.0, false, false)
	_fx3d.update_effects(delta)
	_update_camera_3d(delta, false, false)

	# Едва заметное «дыхание» свечения рамки и внешнего ореола кнопки «В ПОЛЁТ!»
	if _btn_start_launch != null:
		var breath: float = 0.5 + 0.5 * sin(t * 2.2)
		var sb := _btn_start_launch.get_theme_stylebox("normal") as StyleBoxFlat
		if sb != null:
			sb.border_color = Color(0.28, 0.95, 0.84, 0.88).lerp(Color(0.65, 1.0, 1.0, 1.0), breath)
			sb.shadow_color = Color(0.04, 0.94, 0.82, lerpf(0.28, 0.48, breath))
			sb.shadow_size = int(round(lerpf(11.0, 16.0, breath)))


func _update_gameplay_3d(delta: float) -> void:
	var is_tunnel: bool = _tunnel_timer > 0.0
	var is_hyper: bool = _hyper_timer > 0.0
	var is_overdrive: bool = _get_active_special_weapons_count() >= 3

	if _tunnel_timer > 0.0:
		_tunnel_timer -= delta
		if _tunnel_timer <= 0.0:
			_exit_hyper_tunnel()

	if _hyper_timer > 0.0:
		_hyper_timer = maxf(0.0, _hyper_timer - delta)
		if _hyper_timer <= 0.0 and not is_tunnel:
			_audio.set_hyper_mode(false)

	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo = 1

	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and _lbl_banner != null:
			_lbl_banner.visible = false

	# Прогресс волны (при активном 3D-Боссе таймер ждёт победы над Боссом)
	var has_boss: bool = is_instance_valid(_active_boss) and not _active_boss.is_destroyed and not _active_boss.is_queued_for_deletion()
	if not is_tunnel and not has_boss:
		_wave_timer += delta
		if _wave_timer >= _wave_duration:
			_wave_timer = 0.0
			_wave += 1
			_config.update_wave_checkpoint(_is_assault_mode, _wave)
			if _wave % 3 == 0:
				_active_boss = _director.spawn_boss_3d(_entities_root, _wave, _base_forward_speed)
				_audio.play_boss_warning()
				_show_banner("ВНИМАНИЕ! В СЕКТОРЕ " + _active_boss.boss_title + "!", Color(1.0, 0.35, 0.55), 3.4)
			else:
				_show_banner("ВОЛНА %d — СКОРОСТЬ ПОТОКА РАСТЁТ!" % _wave, Color(0.32, 0.96, 1.0), 2.3)

	# Скорость полёта сквозь 3D-космос (плавный рост до 18-й волны, далее мягкий потолок +52 без туннелинга коллизий!)
	var base_w_add: float = minf(float(_wave - 1) * 2.1, 35.7)
	var late_w_add: float = minf(maxf(0.0, float(_wave - 18)) * 0.45, 16.3)
	var wave_speed_add: float = base_w_add + late_w_add
	var mode_mult: float = 1.22 if _is_assault_mode else 1.0
	var speed_mult: float = 1.85 if is_tunnel else (1.55 if is_hyper else 1.0)
	var current_forward_speed: float = (_base_forward_speed + wave_speed_add) * mode_mult * speed_mult

	# Клавиатурный ввод (WASD / стрелки)
	var key_vec := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up")
	)
	if _config.invert_y_axis:
		key_vec.y = -key_vec.y

	_glider.update_glider(
		delta,
		key_vec,
		_config.glider_responsiveness * _config.get_hull_responsiveness_mult(),
		is_hyper,
		is_tunnel,
		is_overdrive,
		_shields
	)

	# 3D-кольца реактивного плазменного следа позади сопел глайдера при манёврах или Гиперскорости
	_wake_ring_timer -= delta
	if _wake_ring_timer <= 0.0 and (_glider.current_vel.length() > 3.5 or is_hyper or is_tunnel):
		_wake_ring_timer = 0.09 if (is_hyper or is_tunnel) else 0.16
		var wake_col: Color = Color(0.32, 1.0, 0.78) if (is_hyper or is_tunnel) else Color(0.18, 0.88, 1.0)
		_fx3d.spawn_engine_wake_ring(_glider.global_position + Vector3(0.0, 0.0, 2.2), wake_col)

	# Неоновые трассеры вихревых срывов с кончиков крыльев (Winglets) при виражах и 360°-Бочке
	var cur_tips: Array[Vector3] = _glider.get_wingtip_positions()
	for p_i: int in range(_prev_wingtips.size()):
		_prev_wingtips[p_i] += Vector3(0.0, 0.0, 24.0 * delta)
	_wingtip_trail_timer -= delta
	if _glider.is_barrel_rolling() or _wingtip_trail_timer <= 0.0:
		_wingtip_trail_timer = 0.032
		if _prev_wingtips.size() == 2 and (_glider.current_vel.length() > 2.2 or _glider.is_barrel_rolling() or is_hyper or is_tunnel):
			var trail_col: Color = Color(1.0, 0.86, 0.28) if (_glider.is_barrel_rolling() or is_overdrive) else Color(0.22, 0.94, 1.0)
			for t_i: int in range(2):
				_fx3d.spawn_wingtip_trail_segment(_prev_wingtips[t_i], cur_tips[t_i], trail_col)
		_prev_wingtips = cur_tips

	_update_camera_3d(delta, is_hyper, is_tunnel)
	_env3d.update_environment(delta, current_forward_speed, is_hyper, is_tunnel)

	# Единый снимок активных 3D-объектов на текущий кадр (без 6..8 повторных get_children())
	_frame_entities = _entities_root.get_children()

	# Спавн 3D-метеоритов, сфер и Чёрных дыр
	_director.update_spawning(
		delta,
		_entities_root,
		_wave,
		_base_forward_speed + wave_speed_add,
		_is_assault_mode,
		is_tunnel,
		_has_active_black_hole()
	)

	# Автоматическая стрельба плазмой и мульти-арсеналом из 3D-глайдера (только при наличии угроз на пути!)
	_update_weapons_3d(delta, is_overdrive, is_tunnel)

	# Обновление снарядов, объектов космоса и 3D-эффектов
	_update_projectiles_3d(delta)
	_update_entities_3d(delta, speed_mult * mode_mult, is_hyper or is_tunnel)
	_frame_entities.clear()
	_fx3d.update_effects(delta)
	_update_hud_ui()


func _update_camera_3d(delta: float, is_hyper: bool, is_tunnel: bool) -> void:
	if _camera == null or _glider == null:
		return

	var target_fov: float = _config.camera_fov_base
	if is_tunnel:
		target_fov += 18.0
	elif is_hyper:
		target_fov += 11.0
	_boost_fov_kick = move_toward(_boost_fov_kick, 0.0, delta * 14.0)
	target_fov += _boost_fov_kick

	# Адаптируем вертикальный FOV под вытянутые экраны смартфонов (20:9, _view_h > 960), чтобы ширина 3D-коридора всегда совпадала с экраном
	var aspect_scale: float = clampf(_view_h / 960.0, 1.0, 1.45)
	if aspect_scale > 1.01:
		var half_rad: float = deg_to_rad(target_fov * 0.5)
		target_fov = rad_to_deg(2.0 * atan(tan(half_rad) * aspect_scale))

	_cam_current_fov = lerpf(_cam_current_fov, target_fov, clampf(delta * 5.5, 0.0, 1.0))
	_camera.fov = _cam_current_fov

	# Плавное следование камеры сзади и сверху за 3D-глайдером
	var g_pos: Vector3 = _glider.position
	var desired_cam_pos := Vector3(
		g_pos.x * 0.56,
		g_pos.y * 0.46 + 3.35,
		9.2
	)

	if _cam_shake > 0.0:
		_cam_shake = maxf(0.0, _cam_shake - delta * 2.8)
		var shake_amt: float = _cam_shake * 0.48
		desired_cam_pos.x += randf_range(-shake_amt, shake_amt)
		desired_cam_pos.y += randf_range(-shake_amt, shake_amt)

	_camera.position = _camera.position.lerp(desired_cam_pos, clampf(delta * 8.5, 0.0, 1.0))

	var look_target := Vector3(
		g_pos.x * 0.74,
		g_pos.y * 0.62 + 0.30,
		-24.0
	)
	_camera.look_at(look_target, Vector3.UP)
	# Лёгкий динамический наклон горизонта камеры вслед за креном глайдера
	_camera.rotation.z = lerpf(_camera.rotation.z, -_glider.current_vel.x * 0.012, clampf(delta * 6.0, 0.0, 1.0))


func _update_weapons_3d(delta: float, is_overdrive: bool, is_tunnel: bool) -> void:
	var fire_rate_mult: float = _config.get_plasma_fire_rate_multiplier() * _config.get_hull_fire_rate_mult() * (1.25 if is_overdrive else 1.0)
	var dmg_bonus: float = _config.get_plasma_damage_bonus()
	var oc_dmg_mult: float = _config.get_overclock_damage_multiplier()

	# В бонусном 3D Гипер-туннеле нет врагов и метеоритов — автоматика переходит в мирный режим,
	# а таймеры собранного спецоружия ставятся на паузу и не сгорают впустую!
	if is_tunnel:
		_glider.update_target_lock(false, Vector3.ZERO, delta)
		_glider.hide_quantum_laser()
		_cd_base_plasma = maxf(0.0, _cd_base_plasma - delta * fire_rate_mult)
		_cd_heavy_plasma = maxf(0.0, _cd_heavy_plasma - delta * fire_rate_mult)
		_cd_vulcan = maxf(0.0, _cd_vulcan - delta * fire_rate_mult)
		_cd_missile = maxf(0.0, _cd_missile - delta * fire_rate_mult)
		_cd_drones = maxf(0.0, _cd_drones - delta)
		return

	if _timer_heavy_plasma > 0.0:
		_timer_heavy_plasma = maxf(0.0, _timer_heavy_plasma - delta)
	if _timer_vulcan > 0.0:
		_timer_vulcan = maxf(0.0, _timer_vulcan - delta)
	if _timer_laser > 0.0:
		_timer_laser = maxf(0.0, _timer_laser - delta)

	# Умный 3D-автозахват прицела (Target Lock-On) на ближайшую угрозу впереди по курсу
	var lock_target: SpaceEntity3D = _find_best_meteor_target(72.0, 5.8)
	_glider.update_target_lock(lock_target != null, lock_target.global_position if lock_target != null else Vector3.ZERO, delta)

	# Орудия глайдера стреляют автоматически ТОЛЬКО когда на пути впереди есть враги или метеориты
	var fire_target: SpaceEntity3D = lock_target if lock_target != null else _find_best_meteor_target(128.0, 5.0)
	var has_forward_threat: bool = fire_target != null

	# 1. Базовая спаренная Плазма из крыльевых орудий глайдера (с мягким доворотом на захваченную 3D-цель!)
	_cd_base_plasma = maxf(0.0, _cd_base_plasma - delta * fire_rate_mult)
	if has_forward_threat and _cd_base_plasma <= 0.0:
		_cd_base_plasma = 0.22
		var muzzles: Array[Vector3] = _glider.get_muzzle_positions()
		for m_pos: Vector3 in muzzles:
			var bolt_vel := Vector3(0.0, 0.0, -118.0)
			if lock_target != null:
				var to_lock: Vector3 = (lock_target.global_position - m_pos).normalized()
				var forward_dir := Vector3(0.0, 0.0, -1.0).lerp(to_lock, 0.38).normalized()
				bolt_vel = forward_dir * 118.0
			_spawn_projectile(
				WeaponProjectile3D.Kind.PLASMA_BASE,
				m_pos,
				bolt_vel,
				dmg_bonus
			)
		_glider.trigger_muzzle_flash(false)
		_audio.play_plasma_fire(false)

	# 2. Тяжёлая Изумрудно-Золотая Плазма с взрывной волной
	if _timer_heavy_plasma > 0.0:
		_cd_heavy_plasma = maxf(0.0, _cd_heavy_plasma - delta * fire_rate_mult)
		if has_forward_threat and _cd_heavy_plasma <= 0.0:
			_cd_heavy_plasma = 0.42
			var nose_pos: Vector3 = _glider.get_nose_muzzle_position()
			_spawn_projectile(
				WeaponProjectile3D.Kind.PLASMA_HEAVY,
				nose_pos,
				Vector3(0.0, 0.0, -108.0),
				dmg_bonus
			)
			_glider.trigger_muzzle_flash(true)
			_audio.play_plasma_fire(true)

	# 3. Скорострельный Пулемёт «Вулкан»
	if _timer_vulcan > 0.0:
		_cd_vulcan = maxf(0.0, _cd_vulcan - delta * fire_rate_mult)
		if has_forward_threat and _cd_vulcan <= 0.0:
			_cd_vulcan = 0.11
			var muzzles_v: Array[Vector3] = _glider.get_muzzle_positions()
			for m_pos: Vector3 in muzzles_v:
				_spawn_projectile(
					WeaponProjectile3D.Kind.VULCAN_BULLET,
					m_pos + Vector3(0.0, 0.12, -0.2),
					Vector3(randf_range(-1.4, 1.4), randf_range(-1.0, 1.0), -138.0),
					dmg_bonus
				)
			_audio.play_bullet_fire()

	# 4. Квантовый 3D-Лазер (непрерывный прожигающий луч по ближайшему метеориту по курсу + цепной разряд в OVERDRIVE!)
	if _timer_laser > 0.0:
		var laser_target: SpaceEntity3D = _find_best_meteor_target(48.0, 7.5)
		if laser_target != null:
			_glider.show_quantum_laser(laser_target.global_position, is_overdrive)
			_audio.play_laser_hum()
			var laser_dps: float = (95.0 + dmg_bonus * 2.2) * fire_rate_mult * oc_dmg_mult * _config.get_hull_special_damage_mult()
			if randf() < 0.35:
				_fx3d.spawn_hit_spark(laser_target.global_position, Color(1.0, 0.45, 0.96) if is_overdrive else Color(0.25, 0.96, 1.0))
			if is_overdrive:
				var chain_target: SpaceEntity3D = _find_chain_laser_target(laser_target, 10.5)
				if chain_target != null:
					if randf() < 0.35:
						_fx3d.spawn_graze_arc(laser_target.global_position, chain_target.global_position, Color(1.0, 0.45, 0.96))
					if chain_target.apply_damage(laser_dps * 0.55 * delta):
						_on_meteor_destroyed(chain_target)
			if laser_target.apply_damage(laser_dps * delta):
				_on_meteor_destroyed(laser_target)
		else:
			_glider.hide_quantum_laser()
	else:
		_glider.hide_quantum_laser()

	# 5. Самонаводящиеся 3D-Ракеты
	if _ammo_missiles > 0:
		_cd_missile = maxf(0.0, _cd_missile - delta * fire_rate_mult)
		if _cd_missile <= 0.0:
			var m_target: SpaceEntity3D = _find_best_meteor_target(125.0, 14.0)
			if m_target != null:
				_cd_missile = 0.58
				_ammo_missiles = maxi(0, _ammo_missiles - 1)
				var muzzles_m: Array[Vector3] = _glider.get_muzzle_positions()
				var side_idx: int = _ammo_missiles % muzzles_m.size()
				var launch_pos: Vector3 = muzzles_m[side_idx]
				var side_push: float = -7.0 if side_idx == 0 else 7.0
				_spawn_projectile(
					WeaponProjectile3D.Kind.HOMING_MISSILE,
					launch_pos,
					Vector3(side_push, 3.5, -82.0),
					dmg_bonus,
					m_target
				)
				_audio.play_missile_launch()

	# 6. Крыльевые 3D-Дроны (апгрейд Ангара — также стреляют только при наличии угроз впереди)
	if _config.upg_wing_drones > 0:
		_cd_drones = maxf(0.0, _cd_drones - delta)
		var drone_interval: float = maxf(0.40, 0.72 - float(_config.upg_wing_drones) * 0.06)
		if _cd_drones <= 0.0:
			var drone_target: SpaceEntity3D = fire_target if fire_target != null else _find_best_meteor_target(128.0, 7.2)
			if drone_target != null:
				_cd_drones = drone_interval
				var d_muzzles: Array[Vector3] = _glider.get_drone_muzzle_positions()
				for dm_pos: Vector3 in d_muzzles:
					var dp: WeaponProjectile3D = _spawn_projectile(
						WeaponProjectile3D.Kind.PLASMA_BASE,
						dm_pos,
						Vector3(0.0, 0.0, -115.0),
						0.0
					)
					dp.damage = (10.0 + float(_config.upg_wing_drones) * 1.5 + dmg_bonus * 0.25) * oc_dmg_mult


func _spawn_projectile(
	p_kind: WeaponProjectile3D.Kind,
	start_pos: Vector3,
	init_vel: Vector3,
	dmg_bonus: float = 0.0,
	homing_target: Node3D = null
) -> WeaponProjectile3D:
	var proj: WeaponProjectile3D = null
	while not _free_projectiles.is_empty():
		var cand: WeaponProjectile3D = _free_projectiles.pop_back()
		if is_instance_valid(cand):
			proj = cand
			break
	if proj == null:
		proj = WeaponProjectile3D.new()
		_projectiles_root.add_child(proj)
	proj.setup_projectile(p_kind, start_pos, init_vel, dmg_bonus, homing_target)
	if not proj.is_enemy and _config != null:
		var dmg_m: float = _config.get_overclock_damage_multiplier()
		if p_kind == WeaponProjectile3D.Kind.HOMING_MISSILE:
			dmg_m *= _config.get_hull_special_damage_mult()
		proj.damage *= dmg_m
		if proj.splash_radius > 0.0:
			proj.splash_radius *= _config.get_hull_blast_radius_mult()
	_active_projectiles.append(proj)
	return proj


func _release_projectile_at(active_idx: int) -> void:
	var proj: WeaponProjectile3D = _active_projectiles[active_idx]
	var last_idx: int = _active_projectiles.size() - 1
	if active_idx != last_idx:
		_active_projectiles[active_idx] = _active_projectiles[last_idx]
	_active_projectiles.resize(last_idx)
	if is_instance_valid(proj):
		proj.deactivate_projectile()
		_free_projectiles.append(proj)


func _clear_enemy_projectiles(spawn_sparks: bool) -> int:
	var cleared: int = 0
	var i: int = _active_projectiles.size() - 1
	while i >= 0:
		var pr: WeaponProjectile3D = _active_projectiles[i]
		if pr != null and is_instance_valid(pr) and pr.is_enemy:
			cleared += 1
			if spawn_sparks:
				_fx3d.spawn_hit_spark(pr.global_position, Color(0.24, 1.0, 0.72))
			_release_projectile_at(i)
		i -= 1
	return cleared


func _warm_up_projectile_pool(prealloc_count: int = 32) -> void:
	WeaponProjectile3D.warm_up_resources()
	var current_total: int = _active_projectiles.size() + _free_projectiles.size()
	for i: int in range(maxi(0, prealloc_count - current_total)):
		var pr := WeaponProjectile3D.new()
		_projectiles_root.add_child(pr)
		pr.setup_projectile(WeaponProjectile3D.Kind.PLASMA_BASE, Vector3.ZERO, Vector3.FORWARD)
		pr.deactivate_projectile()
		_free_projectiles.append(pr)


func _find_best_meteor_target(max_dist_z: float, max_xy_offset: float) -> SpaceEntity3D:
	var best: SpaceEntity3D = null
	var best_score: float = 999999.0
	var g_pos: Vector3 = _glider.global_position

	var entities_src: Array[Node] = _frame_entities if not _frame_entities.is_empty() else _entities_root.get_children()
	for child: Node in entities_src:
		var ent := child as SpaceEntity3D
		if ent == null or not ent.is_hostile() or ent.is_destroyed or ent.is_queued_for_deletion():
			continue
		var dz: float = g_pos.z - ent.global_position.z
		if dz < 1.5 or dz > max_dist_z:
			continue
		var dxy: float = Vector2(ent.global_position.x - g_pos.x, ent.global_position.y - g_pos.y).length()
		var max_off: float = max_xy_offset + ent.radius + (2.0 if ent.kind == SpaceEntity3D.Kind.ENEMY_BOSS_3D else 0.0)
		if dxy > max_off:
			continue
		var score_val: float = dz + dxy * 2.4 - (12.0 if ent.is_enemy_ship() else 0.0)
		if score_val < best_score:
			best_score = score_val
			best = ent
	return best


func _find_chain_laser_target(primary: SpaceEntity3D, max_chain_dist: float) -> SpaceEntity3D:
	if primary == null:
		return null
	var best: SpaceEntity3D = null
	var best_d: float = max_chain_dist
	var p_pos: Vector3 = primary.global_position
	var entities_src: Array[Node] = _frame_entities if not _frame_entities.is_empty() else _entities_root.get_children()
	for child: Node in entities_src:
		var ent := child as SpaceEntity3D
		if ent == null or ent == primary or not ent.is_hostile() or ent.is_destroyed or ent.is_queued_for_deletion():
			continue
		var d: float = p_pos.distance_to(ent.global_position)
		if d < best_d:
			best_d = d
			best = ent
	return best


func _update_projectiles_3d(delta: float) -> void:
	var g_pos: Vector3 = _glider.global_position
	var is_warp_invuln: bool = (_hyper_timer > 0.0 or _tunnel_timer > 0.0)
	var entities_list: Array[Node] = _frame_entities if not _frame_entities.is_empty() else _entities_root.get_children()

	var i: int = _active_projectiles.size() - 1
	while i >= 0:
		var proj: WeaponProjectile3D = _active_projectiles[i]
		if not is_instance_valid(proj) or not proj.is_active:
			_release_projectile_at(i)
			i -= 1
			continue
		if not proj.update_projectile(delta):
			_release_projectile_at(i)
			i -= 1
			continue

		var p_pos: Vector3 = proj.position

		# Если это вражеский плазменный снаряд — проверяем отражение 360°-Бочкой или попадание по 3D-глайдеру
		if proj.is_enemy:
			var d_to_glider: float = p_pos.distance_to(g_pos)
			if _glider.is_barrel_rolling() and d_to_glider <= proj.hit_radius + 3.2:
				# Рикошет вражеской плазмы 360°-Бочкой обратно во врагов!
				proj.is_enemy = false
				proj.damage = 65.0 + _config.get_plasma_damage_bonus()
				proj.age = 0.0
				var reflect_target: SpaceEntity3D = _find_best_meteor_target(95.0, 12.0)
				if reflect_target != null:
					proj.velocity = (reflect_target.global_position - p_pos).normalized() * 128.0
				else:
					proj.velocity = Vector3(0.0, 0.0, -128.0)
				var def_pts: int = 85 * _combo
				_score += def_pts
				_add_hyper_charge(7.5)
				_audio.play_graze(_combo)
				_fx3d.spawn_hit_spark(p_pos, Color(1.0, 0.88, 0.28))
				_spawn_floating_3d_text(p_pos, "РИКОШЕТ БОЧКОЙ +%d!" % def_pts, Color(1.0, 0.88, 0.30))
				i -= 1
				continue
			if d_to_glider <= proj.hit_radius + 1.25:
				_release_projectile_at(i)
				if not is_warp_invuln and not _glider.is_barrel_rolling():
					_damage_glider_shield(p_pos)
				else:
					_fx3d.spawn_hit_spark(p_pos, Color(0.32, 1.0, 0.78))
			i -= 1
			continue

		# Проверка попадания 3D-снаряда глайдера в метеориты, катера и 3D-боссов
		var hit_any: bool = false
		for e_child: Node in entities_list:
			var ent := e_child as SpaceEntity3D
			if ent == null or not ent.is_hostile() or ent.is_destroyed or ent.is_queued_for_deletion():
				continue
			var combined_r: float = proj.hit_radius + ent.radius
			if absf(p_pos.z - ent.position.z) > combined_r + 0.5:
				continue
			if p_pos.distance_squared_to(ent.position) <= combined_r * combined_r:
				hit_any = true
				var spark_col := Color(0.28, 1.0, 0.62) if proj.kind == WeaponProjectile3D.Kind.PLASMA_HEAVY else Color(0.22, 0.94, 1.0)
				_fx3d.spawn_hit_spark(p_pos, spark_col)
				var was_enraged: bool = ent.boss_enraged
				var killed: bool = ent.apply_damage(proj.damage)
				if ent.kind == SpaceEntity3D.Kind.ENEMY_BOSS_3D and ent.boss_enraged and not was_enraged:
					_audio.play_boss_warning()
					_show_banner(ent.boss_title + " — ФАЗА ЯРОСТИ!", Color(1.0, 0.32, 0.25), 2.4)
				if killed:
					_on_meteor_destroyed(ent)

				# Если у снаряда есть взрывная волна (Тяжёлая плазма или 3D-Ракета)
				if proj.splash_radius > 0.1:
					_apply_aoe_explosion(p_pos, proj.splash_radius, proj.damage * 0.72, spark_col)
				break

		if hit_any:
			_release_projectile_at(i)
		i -= 1


func _apply_aoe_explosion(center: Vector3, radius: float, aoe_dmg: float, col: Color) -> void:
	_fx3d.spawn_meteor_explosion(center, radius * 0.35, col, true)
	var r_sq: float = radius * radius
	for e_child: Node in _entities_root.get_children():
		var ent := e_child as SpaceEntity3D
		if ent == null or not ent.is_hostile() or ent.is_destroyed or ent.is_queued_for_deletion():
			continue
		if center.distance_squared_to(ent.global_position) <= r_sq:
			if ent.apply_damage(aoe_dmg):
				_on_meteor_destroyed(ent)


func _on_meteor_destroyed(ent: SpaceEntity3D) -> void:
	if ent == null or ent.is_queued_for_deletion():
		return
	ent.is_destroyed = true
	var pos: Vector3 = ent.global_position
	var rad: float = ent.radius
	var is_bomb: bool = ent.is_plasma_bomb()
	var is_crystal: bool = ent.kind == SpaceEntity3D.Kind.METEOR_CRYSTAL
	var is_boss: bool = ent.kind == SpaceEntity3D.Kind.ENEMY_BOSS_3D
	var is_sniper: bool = ent.kind == SpaceEntity3D.Kind.ENEMY_SNIPER_3D
	var is_interceptor: bool = ent.kind == SpaceEntity3D.Kind.ENEMY_INTERCEPTOR or is_sniper
	_stat_destroyed += 1

	var pts: int = _scale_score(ent.score_value * _combo)
	_score += pts
	_add_hyper_charge(25.0 if is_boss else (8.0 if is_interceptor else (6.5 if is_bomb else 3.5)))

	var exp_col := Color(0.32, 0.88, 1.0)
	if ent.kind == SpaceEntity3D.Kind.METEOR_PLASMA_GREEN:
		exp_col = Color(0.22, 1.0, 0.55)
	elif ent.kind == SpaceEntity3D.Kind.METEOR_PLASMA_GOLD:
		exp_col = Color(1.0, 0.72, 0.18)
	elif is_boss:
		match ent.boss_archetype:
			SpaceEntity3D.BossArchetype.PHANTOM_SNIPER:
				exp_col = Color(0.84, 0.30, 1.0)
			SpaceEntity3D.BossArchetype.SWARM_CARRIER:
				exp_col = Color(0.24, 1.0, 0.66)
			SpaceEntity3D.BossArchetype.OMEGA_DREADNOUGHT:
				exp_col = Color(1.0, 0.76, 0.22)
			_:
				exp_col = Color(1.0, 0.28, 0.52)
	elif is_interceptor:
		exp_col = Color(1.0, 0.28, 0.52)

	if is_boss and _active_boss == ent:
		_active_boss = null

	ent.queue_free()
	_fx3d.spawn_meteor_explosion(pos, rad, exp_col, is_bomb or is_boss)

	if is_boss:
		_audio.play_boss_explode()
		var gold_drop_cnt: int = mini(3 + (ent.boss_tier - 1), 7)
		_spawn_crystal_burst(pos, gold_drop_cnt, 3)
		_spawn_crystal_burst(pos, 4 + mini(_wave / 3, 4), 1)
		_cam_shake = 1.1
		_trigger_screen_flash(Color(1.0, 0.32, 0.55), 0.48)
		_show_banner(ent.boss_title + " УНИЧТОЖЕН! ОТКРЫТА 3D ЧЁРНАЯ ДЫРА!", Color(1.0, 0.88, 0.30), 3.4)
		# Очищаем вражеские снаряды и открываем портал 3D Чёрной дыры прямо по курсу!
		_clear_enemy_projectiles(false)
		var bh := SpaceEntity3D.new()
		_entities_root.add_child(bh)
		bh.setup_entity(SpaceEntity3D.Kind.BLACK_HOLE_PORTAL, Vector3(0.0, 1.2, -52.0), _base_forward_speed, 4.6, _wave)
		return

	if is_bomb:
		_audio.play_bomb_explode()
		_cam_shake = maxf(_cam_shake, 0.65)
		_spawn_floating_3d_text(pos, "+%d ПЛАЗМА-ВЗРЫВ!" % pts, exp_col)
		# Цепная детонация соседних метеоритов и врагов!
		var blast_r: float = (8.5 if ent.kind == SpaceEntity3D.Kind.METEOR_PLASMA_GOLD else 6.8) * _config.get_hull_blast_radius_mult()
		var blast_dmg: float = 95.0 if ent.kind == SpaceEntity3D.Kind.METEOR_PLASMA_GOLD else 70.0
		for other_node: Node in _entities_root.get_children():
			var other := other_node as SpaceEntity3D
			if other != null and other != ent and other.is_hostile() and not other.is_destroyed and not other.is_queued_for_deletion():
				if pos.distance_to(other.global_position) <= blast_r:
					if other.apply_damage(blast_dmg):
						_on_meteor_destroyed(other)
	else:
		_audio.play_asteroid_explode()
		_cam_shake = maxf(_cam_shake, 0.22)
		if is_sniper:
			_spawn_floating_3d_text(pos, "+%d СНАЙПЕР!" % pts, exp_col)
		elif is_interceptor:
			_spawn_floating_3d_text(pos, "+%d ПЕРЕХВАТЧИК!" % pts, exp_col)

	# Квантовые Кристаллы: щедро из бомб и катеров, редко из кристаллических метеоритов
	if is_sniper or ent.kind == SpaceEntity3D.Kind.METEOR_PLASMA_GOLD:
		_spawn_crystal_burst(pos, 1, 3)
	elif is_interceptor and randf() < 0.55:
		_spawn_crystal_burst(pos, 1 + (1 if randf() < 0.3 else 0))
	elif is_bomb and randf() < 0.45:
		_spawn_crystal_burst(pos, 1)
	elif is_crystal and randf() < 0.30:
		_spawn_crystal_burst(pos, 1)

	# Из кристаллических метеоритов и сбитых 3D-перехватчиков выпадает сфера энергии или оружие!
	if is_crystal or is_interceptor or (rad >= 2.2 and randf() < 0.35):
		var drop := SpaceEntity3D.new()
		_entities_root.add_child(drop)
		var drop_kind: SpaceEntity3D.Kind = SpaceEntity3D.Kind.ORB_ENERGY
		if (is_crystal or is_interceptor) and randf() < 0.55:
			drop_kind = SpaceEntity3D.pick_random_weapon_orb_kind()
		drop.setup_entity(drop_kind, pos, _base_forward_speed * 0.75, 1.15, _wave)


func _spawn_crystal_burst(pos: Vector3, count: int, tier_val: int = 1) -> void:
	for i: int in range(count):
		var cr := SpaceEntity3D.new()
		_entities_root.add_child(cr)
		cr.setup_entity(
			SpaceEntity3D.Kind.ORB_QUANTUM_CRYSTAL,
			pos + Vector3(randf_range(-0.8, 0.8), randf_range(-0.6, 0.6), 0.0),
			_base_forward_speed * 0.8,
			1.0,
			_wave
		)
		cr.set_crystal_tier(tier_val)
		cr.velocity.x = randf_range(-5.0, 5.0)
		cr.velocity.y = randf_range(-3.0, 4.0)


func _update_entities_3d(delta: float, speed_mult: float, is_invulnerable_warp: bool) -> void:
	var g_pos: Vector3 = _glider.global_position
	var magnet_r: float = 6.2 * _config.get_magnet_multiplier() * (1.85 if _tunnel_timer > 0.0 else 1.0)
	var glider_hit_r: float = 1.35
	var graze_r: float = 3.25

	var entities_src: Array[Node] = _frame_entities if not _frame_entities.is_empty() else _entities_root.get_children()
	for child: Node in entities_src:
		var ent := child as SpaceEntity3D
		if ent == null or ent.is_queued_for_deletion():
			continue

		if not ent.update_entity(delta, speed_mult, g_pos, magnet_r):
			ent.queue_free()
			continue

		var dist: float = g_pos.distance_to(ent.global_position)

		# 1. Влёт в 3D Чёрную дыру -> Прорыв в 3D Гипер-туннель!
		if ent.kind == SpaceEntity3D.Kind.BLACK_HOLE_PORTAL:
			# Лёгкое гравитационное притяжение к воронке на близкой дистанции
			if dist < 14.0 and absf(ent.global_position.z - g_pos.z) < 16.0:
				var pull: Vector2 = Vector2(ent.global_position.x - g_pos.x, ent.global_position.y - g_pos.y) * delta * 1.4
				_glider.move_target_by_delta(pull)
			if dist <= ent.radius + 1.4:
				var bh_pos: Vector3 = ent.global_position
				ent.queue_free()
				_enter_hyper_tunnel(bh_pos)
			continue

		# 1b. Кольцо ускорения
		if ent.kind == SpaceEntity3D.Kind.BOOST_RING_3D:
			if absf(ent.position.z - g_pos.z) < 2.2 and Vector2(ent.position.x - g_pos.x, ent.position.y - g_pos.y).length() <= ent.radius + 0.85:
				_combo = mini(_combo + 1, 8)
				_max_combo_reached = maxi(_max_combo_reached, _combo)
				_combo_timer = 4.5
				var ring_pts: int = _scale_score(180 * _combo)
				_score += ring_pts
				_award_crystals(1, false)
				_add_hyper_charge(12.0)
				_boost_fov_kick = 6.5
				_audio.play_weapon_pickup()
				_fx3d.spawn_engine_wake_ring(ent.global_position, Color(0.28, 1.0, 0.78))
				_spawn_floating_3d_text(ent.global_position, "УСКОРЕНИЕ +%d • +1 КР!" % ring_pts, Color(0.32, 1.0, 0.78))
				ent.queue_free()
			continue

		# 2. Подбор энергетических сфер и капсул вооружения
		if ent.is_pickup_orb():
			if dist <= ent.radius + glider_hit_r + 0.55:
				_collect_orb(ent)
			continue

		# 3. Огонь вражеских 3D-кораблей и столкновения / виражи с угрозами
		if ent.is_enemy_ship() and not is_invulnerable_warp:
			ent.fire_cooldown -= delta
			if ent.fire_cooldown <= 0.0 and ent.global_position.z < -8.0 and ent.global_position.z > -95.0:
				ent.fire_cooldown = ent.fire_interval
				_fire_enemy_weapons_3d(ent)

		if ent.is_hostile():
			if dist <= ent.radius + glider_hit_r:
				if is_invulnerable_warp and ent.kind != SpaceEntity3D.Kind.ENEMY_BOSS_3D:
					_on_meteor_destroyed(ent)
				else:
					_on_glider_hit_meteor(ent)
			elif not ent.grazed and absf(ent.global_position.z - g_pos.z) < 2.2 and dist <= ent.radius + graze_r:
				ent.grazed = true
				_trigger_graze_bonus(ent.global_position)


func _trigger_graze_bonus(threat_pos: Vector3) -> void:
	var g_pos: Vector3 = _glider.global_position
	_combo = mini(_combo + 1, 8)
	_max_combo_reached = maxi(_max_combo_reached, _combo)
	_stat_grazes += 1
	_combo_timer = 4.5
	var graze_pts: int = _scale_score(45 * _combo)
	_score += graze_pts
	_add_hyper_charge(5.5)
	_audio.play_graze(_combo)
	_fx3d.spawn_graze_arc(g_pos, threat_pos, Color(0.28, 0.96, 1.0))
	_trigger_edge_flash(Color(0.22, 0.92, 1.0), 0.52)

	# Короткий сочный микро-слоумо «На грани»
	Engine.time_scale = 0.50
	_slowmo_timer = 0.045

	_graze_shield_progress += 1
	if _graze_shield_progress >= 5:
		_graze_shield_progress = 0
		_audio.play_shield_restore()
		_glider.trigger_shield_flash(false)
		_trigger_edge_flash(Color(0.24, 1.0, 0.72), 0.72)
		if _shields < _max_shields:
			_shields += 1
			_spawn_floating_3d_text(g_pos + Vector3(0.0, 1.2, 0.0), "5/5 НА ГРАНИ -> +1 ЩИТ!", Color(0.28, 1.0, 0.72))
		else:
			_score += 250
			_spawn_floating_3d_text(g_pos + Vector3(0.0, 1.2, 0.0), "СВЕРХЗАРЯД ЩИТА +250!", Color(1.0, 0.88, 0.30))
	else:
		_spawn_floating_3d_text(threat_pos, "НА ГРАНИ x%d +%d" % [_combo, graze_pts], Color(0.35, 0.98, 1.0))


func _fire_enemy_weapons_3d(ent: SpaceEntity3D) -> void:
	var g_pos: Vector3 = _glider.global_position
	var start_pos: Vector3 = ent.global_position + Vector3(0.0, 0.0, 1.8)
	var to_player: Vector3 = (g_pos - start_pos).normalized()
	if to_player.z < 0.25:
		to_player.z = 0.65
		to_player = to_player.normalized()

	_audio.play_enemy_fire()
	if ent.kind == SpaceEntity3D.Kind.ENEMY_INTERCEPTOR:
		_spawn_projectile(WeaponProjectile3D.Kind.ENEMY_PLASMA_BOLT, start_pos, to_player * 56.0)
	elif ent.kind == SpaceEntity3D.Kind.ENEMY_SNIPER_3D:
		var aim_pt: Vector3 = ent.sniper_aim_pos if ent.sniper_aim_pos != Vector3.ZERO else g_pos
		var aim_dir: Vector3 = (aim_pt - start_pos).normalized()
		if aim_dir.z < 0.35:
			aim_dir.z = 0.35
			aim_dir = aim_dir.normalized()
		_spawn_projectile(WeaponProjectile3D.Kind.ENEMY_PLASMA_BOLT, start_pos, aim_dir * 78.0)
		ent.sniper_aim_pos = Vector3.ZERO
	elif ent.kind == SpaceEntity3D.Kind.ENEMY_BOSS_3D:
		ent.attack_counter += 1
		match ent.boss_archetype:
			SpaceEntity3D.BossArchetype.PHANTOM_SNIPER:
				# 2 (в Ярости 3) сверхбыстрых снайперских копья точно по точкам 3D лазерных прицелов
				var beam_cnt: int = 3 if ent.boss_enraged else 2
				for i: int in range(beam_cnt):
					var muzzle_off_x: float = (float(i) - float(beam_cnt - 1) * 0.5) * 1.65
					var m_pos: Vector3 = start_pos + Vector3(muzzle_off_x, 0.1, 0.0)
					var aim_pt: Vector3 = ent.boss_aim_points[i] if i < ent.boss_aim_points.size() else g_pos
					var dir_s: Vector3 = (aim_pt - m_pos).normalized()
					if dir_s.z < 0.35:
						dir_s.z = 0.35
						dir_s = dir_s.normalized()
					_spawn_projectile(WeaponProjectile3D.Kind.ENEMY_PLASMA_BOLT, m_pos, dir_s * 82.0)
				ent.boss_aim_points.clear()

			SpaceEntity3D.BossArchetype.SWARM_CARRIER:
				# Чередует выпуск звена 3D-дронов-перехватчиков (до 4 активных) и парные залпы турелей
				var spawn_cadence: int = 2 if ent.boss_enraged else 3
				var active_minions: int = 0
				for n: Node in _entities_root.get_children():
					var se := n as SpaceEntity3D
					if se != null and se.kind == SpaceEntity3D.Kind.ENEMY_INTERCEPTOR and not se.is_destroyed and not se.is_queued_for_deletion():
						active_minions += 1
				if ent.attack_counter % spawn_cadence == 0 and active_minions < 4:
					var drone_cnt: int = mini(3 if ent.boss_enraged else 2, 4 - active_minions)
					for d_i: int in range(drone_cnt):
						var side_x: float = (float(d_i) - float(drone_cnt - 1) * 0.5) * 4.2
						var spawn_p: Vector3 = ent.global_position + Vector3(side_x, -0.2, 2.2)
						var minion := SpaceEntity3D.new()
						_entities_root.add_child(minion)
						minion.setup_entity(SpaceEntity3D.Kind.ENEMY_INTERCEPTOR, spawn_p, _base_forward_speed * 0.82, 1.45, _wave)
						minion.max_hp *= 0.65
						minion.hp = minion.max_hp
						_fx3d.spawn_engine_wake_ring(spawn_p, Color(0.24, 1.0, 0.68))
				else:
					var shots: int = 4 if ent.boss_enraged else 2
					for i: int in range(shots):
						var sx: float = -3.4 if i % 2 == 0 else 3.4
						var sy: float = -0.35 if i < 2 else 0.55
						var m_pos: Vector3 = start_pos + Vector3(sx, sy, 0.0)
						var dir_c: Vector3 = (g_pos - m_pos).normalized()
						if dir_c.z < 0.30:
							dir_c.z = 0.60
							dir_c = dir_c.normalized()
						_spawn_projectile(WeaponProjectile3D.Kind.ENEMY_PLASMA_BOLT, m_pos, dir_c * 58.0)

			SpaceEntity3D.BossArchetype.OMEGA_DREADNOUGHT:
				if ent.attack_counter % 2 == 1:
					# Спиральный 3D bullet-hell (4..6 снарядов по вращающемуся кольцу!)
					var spokes: int = 6 if ent.boss_enraged else 4
					var base_ang: float = float(ent.attack_counter) * 0.62
					for i: int in range(spokes):
						var ang: float = base_ang + (float(i) / float(spokes)) * TAU
						var dir_o := Vector3(cos(ang) * 0.24 + to_player.x * 0.45, sin(ang) * 0.20 + to_player.y * 0.45, maxf(0.68, to_player.z)).normalized()
						_spawn_projectile(WeaponProjectile3D.Kind.ENEMY_PLASMA_BOLT, start_pos + Vector3(cos(ang) * 2.4, sin(ang) * 1.8, 0.0), dir_o * 56.0)
				else:
					# Развёртывающаяся стена с просветом (вынуждает манёвр или 360°-Бочку с рикошетом!)
					var wall_cnt: int = 7 if ent.boss_enraged else 5
					var gap_idx: int = posmod(ent.attack_counter, wall_cnt)
					for i: int in range(wall_cnt):
						if i == gap_idx:
							continue
						var t_w: float = (float(i) - float(wall_cnt - 1) * 0.5) * 0.13
						var dir_w := Vector3(t_w, to_player.y * 0.72 + t_w * (0.35 if ent.attack_counter % 4 == 0 else -0.35), maxf(0.70, to_player.z)).normalized()
						_spawn_projectile(WeaponProjectile3D.Kind.ENEMY_PLASMA_BOLT, start_pos + Vector3(t_w * 9.0, 0.0, 0.0), dir_w * 62.0)

			_:
				# TITAN_CRUISER: классический веер 3..5 снарядов + чередующаяся дуга
				var fan_count: int = 5 if ent.boss_enraged else 3
				for i: int in range(fan_count):
					var spread: float = (float(i) - float(fan_count - 1) * 0.5) * 0.14
					var dir := Vector3(to_player.x + spread, to_player.y + (ent.attack_counter % 2 - 0.5) * 0.06, to_player.z).normalized()
					_spawn_projectile(WeaponProjectile3D.Kind.ENEMY_PLASMA_BOLT, start_pos + Vector3(spread * 6.0, 0.0, 0.0), dir * 60.0)


func _collect_orb(ent: SpaceEntity3D) -> void:
	var pos: Vector3 = ent.global_position
	var ammo_mult: float = _config.get_ammo_multiplier()

	match ent.kind:
		SpaceEntity3D.Kind.ORB_ENERGY:
			_combo = mini(_combo + 1, 8)
			_combo_timer = 4.5
			var pts: int = _scale_score(85 * _combo)
			_score += pts
			_add_hyper_charge(9.0)
			_audio.play_orb_pickup(false, _combo)
			_spawn_floating_3d_text(pos, "+%d ЭНЕРГИЯ" % pts, Color(0.25, 0.95, 1.0))
		SpaceEntity3D.Kind.ORB_HYPER_CORE:
			_score += _scale_score(220 * _combo)
			_add_hyper_charge(28.0)
			_audio.play_orb_pickup(true, _combo)
			_spawn_floating_3d_text(pos, "+28% ГИПЕР-ЯДРО!", Color(0.96, 0.35, 1.0))
		SpaceEntity3D.Kind.ORB_SHIELD:
			# 3D ЭМИ-Импульс испаряет все вражеские плазменные снаряды в пространстве!
			var cleared_bolts: int = _clear_enemy_projectiles(true)

			if _shields < _max_shields:
				_shields += 1
				_score += (90 + cleared_bolts * 35) * _combo
				_spawn_floating_3d_text(pos, "+1 ЩИТ • ЭМИ-ОЧИСТКА!", Color(0.24, 1.0, 0.68))
			else:
				var emp_pts: int = (280 + cleared_bolts * 35) * _combo
				_score += emp_pts
				_apply_aoe_explosion(_glider.global_position + Vector3(0.0, 0.0, -18.0), 18.0, 85.0, Color(0.24, 1.0, 0.72))
				_spawn_floating_3d_text(pos, "СВЕРХЗАРЯД ЭМИ +%d!" % emp_pts, Color(1.0, 0.88, 0.30))
			_glider.trigger_shield_flash(false)
			_audio.play_shield_restore()
		SpaceEntity3D.Kind.ORB_QUANTUM_CRYSTAL:
			var cr_val: int = maxi(1, ent.crystal_value)
			_award_crystals(cr_val, false)
			_score += 60 * cr_val * _combo
			_audio.play_orb_pickup(true, _combo)
			var cr_col: Color = Color(1.0, 0.88, 0.28) if cr_val > 1 else Color(0.45, 0.95, 1.0)
			_spawn_floating_3d_text(pos, "+%d КР" % cr_val, cr_col)
		SpaceEntity3D.Kind.ORB_WEAPON_PLASMA:
			_timer_heavy_plasma = minf(38.0 * ammo_mult, _timer_heavy_plasma + 16.0 * ammo_mult)
			_audio.play_weapon_pickup()
			_spawn_floating_3d_text(pos, "ТЯЖЁЛАЯ ПЛАЗМА!", Color(0.28, 1.0, 0.52))
		SpaceEntity3D.Kind.ORB_WEAPON_VULCAN:
			_timer_vulcan = minf(42.0 * ammo_mult, _timer_vulcan + 18.0 * ammo_mult)
			_audio.play_weapon_pickup()
			_spawn_floating_3d_text(pos, "ПУЛЕМЁТ «ВУЛКАН»!", Color(1.0, 0.85, 0.24))
		SpaceEntity3D.Kind.ORB_WEAPON_LASER:
			_timer_laser = minf(28.0 * ammo_mult, _timer_laser + 12.0 * ammo_mult)
			_audio.play_weapon_pickup()
			_spawn_floating_3d_text(pos, "КВАНТОВЫЙ 3D-ЛАЗЕР!", Color(0.28, 0.96, 1.0))
		SpaceEntity3D.Kind.ORB_WEAPON_MISSILE:
			var max_m: int = int(round(16.0 * ammo_mult))
			var add_m: int = int(round(5.0 * ammo_mult))
			_ammo_missiles = mini(max_m, _ammo_missiles + add_m)
			_audio.play_weapon_pickup()
			_spawn_floating_3d_text(pos, "+%d 3D-РАКЕТЫ!" % add_m, Color(1.0, 0.42, 0.32))

	_fx3d.spawn_hit_spark(pos, Color(0.45, 1.0, 0.88))
	ent.queue_free()


func _on_glider_hit_meteor(ent: SpaceEntity3D) -> void:
	var pos: Vector3 = ent.global_position
	var rad: float = ent.radius
	if ent.kind != SpaceEntity3D.Kind.ENEMY_BOSS_3D:
		ent.queue_free()
	_fx3d.spawn_meteor_explosion(pos, rad, Color(1.0, 0.35, 0.45), true)
	_damage_glider_shield(pos)


func _damage_glider_shield(hit_pos: Vector3) -> void:
	if _glider.is_damage_invulnerable() or _glider.is_barrel_rolling():
		return

	_shields -= 1
	_combo = 1
	_glider.trigger_shield_flash(true)
	_audio.play_shield_hit()
	_cam_shake = 1.0
	_trigger_screen_flash(Color(1.0, 0.22, 0.36), 0.42)
	_fx3d.spawn_hit_spark(hit_pos, Color(1.0, 0.30, 0.45))

	if _config.vibration_enabled and DisplayServer.get_name() != "headless":
		Input.vibrate_handheld(90)

	# Если прокачан Грави-Щит в Ангаре — при ударе расходится защитная волна, расчищающая камни вокруг!
	if _config.upg_wave_shield >= 1:
		var wave_r: float = 9.0 + float(_config.upg_wave_shield) * 2.2
		_apply_aoe_explosion(_glider.global_position, wave_r, 120.0, Color(0.24, 0.94, 1.0))

	if _shields < 0:
		_trigger_game_over()


func _enter_hyper_tunnel(bh_pos: Vector3) -> void:
	_audio.play_black_hole_enter()
	_audio.set_tunnel_mode(true)
	_tunnel_timer = 9.5 + _config.get_hyper_duration_bonus()
	_score += 500 * _combo
	_cam_shake = 0.85
	_trigger_screen_flash(Color(0.65, 0.28, 1.0), 0.58)
	_show_banner("ПРОРЫВ СКВОЗЬ ЧЁРНУЮ ДЫРУ -> 3D ГИПЕР-ТУННЕЛЬ!", Color(0.42, 1.0, 0.85), 3.4)
	_spawn_floating_3d_text(bh_pos, "ГИПЕР-ТУННЕЛЬ +500!", Color(0.85, 0.45, 1.0))

	# Расчищаем текущие метеориты, вражеские корабли и вражеские снаряды при входе в Чёрную дыру
	_clear_enemy_projectiles(true)
	var entities_src: Array[Node] = _frame_entities if not _frame_entities.is_empty() else _entities_root.get_children()
	for child: Node in entities_src:
		var ent := child as SpaceEntity3D
		if ent != null and ent.is_hostile() and ent.kind != SpaceEntity3D.Kind.ENEMY_BOSS_3D:
			_fx3d.spawn_meteor_explosion(ent.global_position, ent.radius, Color(0.75, 0.35, 1.0), false)
			ent.queue_free()


func _exit_hyper_tunnel() -> void:
	_tunnel_timer = 0.0
	_audio.set_tunnel_mode(false)
	_audio.play_hyperjump()
	_sector_index += 1
	_env3d.set_sector_palette(_sector_index)
	if _shields < _max_shields:
		_shields += 1
	_trigger_screen_flash(Color(0.28, 0.96, 1.0), 0.45)
	_show_banner(_env3d.get_current_sector_name() + " (+1 ЩИТ)", Color(0.35, 0.96, 1.0), 3.0)


func _add_hyper_charge(amount: float) -> void:
	if _hyper_timer > 0.0 or _tunnel_timer > 0.0:
		return
	var mult: float = (1.0 + float(_config.upg_hyper_core) * 0.12) * _config.get_hull_hyper_charge_mult()
	_hyper_charge = clampf(_hyper_charge + amount * mult, 0.0, 100.0)


func _try_activate_hyper_core() -> void:
	if _state != GameState.PLAYING or _hyper_charge < 100.0 or _hyper_timer > 0.0:
		return
	_hyper_charge = 0.0
	_hyper_timer = 6.2 + _config.get_hyper_duration_bonus()
	_audio.play_hyperjump()
	_audio.set_hyper_mode(true)
	_cam_shake = 0.6
	_trigger_screen_flash(Color(0.25, 1.0, 0.78), 0.45)
	_show_banner("ГИПЕРСКОРОСТЬ АКТИВИРОВАНА — НЕУЯЗВИМЫЙ ПРОРЫВ!", Color(0.28, 1.0, 0.75), 2.6)


func _has_active_black_hole() -> bool:
	var entities_src: Array[Node] = _frame_entities if not _frame_entities.is_empty() else _entities_root.get_children()
	for child: Node in entities_src:
		var ent := child as SpaceEntity3D
		if ent != null and ent.kind == SpaceEntity3D.Kind.BLACK_HOLE_PORTAL:
			return true
	return false


func _get_active_special_weapons_count() -> int:
	var c: int = 0
	if _timer_heavy_plasma > 0.0:
		c += 1
	if _timer_vulcan > 0.0:
		c += 1
	if _timer_laser > 0.0:
		c += 1
	if _ammo_missiles > 0:
		c += 1
	return c


func _trigger_screen_flash(col: Color, alpha: float) -> void:
	_screen_flash_color = col
	_screen_flash_alpha = alpha
	if _flash_rect != null:
		_flash_rect.color = Color(col.r, col.g, col.b, alpha)
	_trigger_edge_flash(col, minf(0.92, alpha * 1.65))


func _trigger_edge_flash(col: Color, alpha: float) -> void:
	_edge_flash_color = col
	_edge_flash_alpha = alpha
	if _edge_flash_panel != null:
		_edge_flash_panel.visible = true
		var esb := _edge_flash_panel.get_theme_stylebox("panel") as StyleBoxFlat
		if esb != null:
			esb.border_color = Color(col.r, col.g, col.b, alpha)


func _show_banner(text: String, col: Color, duration: float = 2.5) -> void:
	if _lbl_banner == null:
		return
	_lbl_banner.text = text
	_lbl_banner.add_theme_color_override("font_color", col)
	_lbl_banner.visible = true
	_banner_timer = duration


func _spawn_floating_3d_text(world_pos: Vector3, text: String, col: Color) -> void:
	if _camera == null or _floating_texts_root == null:
		return
	if _camera.is_position_behind(world_pos):
		return
	while _floating_labels.size() >= MAX_FLOATING_LABELS:
		var oldest: Dictionary = _floating_labels[0]
		var old_lbl := oldest.get("label") as Label
		_release_floating_label(old_lbl)
		_floating_labels.remove_at(0)

	var screen_pt: Vector2 = _camera.unproject_position(world_pos)
	var lbl: Label = null
	while not _free_floating_labels.is_empty():
		var cand: Label = _free_floating_labels.pop_back()
		if is_instance_valid(cand):
			lbl = cand
			break
	if lbl == null:
		lbl = UiBuilder.create_label(text, 15, col, HORIZONTAL_ALIGNMENT_CENTER, 3)
		lbl.custom_minimum_size = Vector2(180.0, 24.0)
		_floating_texts_root.add_child(lbl)
	else:
		lbl.text = text
		lbl.add_theme_color_override("font_color", col)
		lbl.visible = true

	lbl.modulate = Color.WHITE
	lbl.position = screen_pt - Vector2(90.0, 12.0)
	_floating_labels.append({
		"label": lbl,
		"age": 0.0,
		"duration": 0.85,
		"color": col
	})


func _release_floating_label(lbl: Label) -> void:
	if lbl != null and is_instance_valid(lbl):
		lbl.visible = false
		_free_floating_labels.append(lbl)


func _update_floating_labels(delta: float) -> void:
	var i: int = _floating_labels.size() - 1
	while i >= 0:
		var item: Dictionary = _floating_labels[i]
		var lbl := item.get("label") as Label
		if not is_instance_valid(lbl):
			_floating_labels.remove_at(i)
			i -= 1
			continue
		var age: float = float(item["age"]) + delta
		var dur: float = float(item["duration"])
		if age >= dur:
			_release_floating_label(lbl)
			_floating_labels.remove_at(i)
			i -= 1
			continue
		item["age"] = age
		if not bool(item.get("static", false)):
			lbl.position.y -= 38.0 * delta
		lbl.modulate = Color(1.0, 1.0, 1.0, 1.0 - (age / dur))
		i -= 1


# ============================================================================
# УПРАВЛЕНИЕ СОСТОЯНИЯМИ ИГРЫ (МЕНЮ, СТАРТ, ПАУЗА, GAME OVER)
# ============================================================================

func _clear_world_entities() -> void:
	Engine.time_scale = 1.0
	_slowmo_timer = 0.0
	_frame_entities.clear()
	for c: Node in _entities_root.get_children():
		c.queue_free()
	var p_i: int = _active_projectiles.size() - 1
	while p_i >= 0:
		_release_projectile_at(p_i)
		p_i -= 1
	_fx3d.clear_all()
	for item: Dictionary in _floating_labels:
		var lbl := item.get("label") as Label
		_release_floating_label(lbl)
	_floating_labels.clear()


func _enter_menu_state() -> void:
	_bank_uncommitted_credits()
	_state = GameState.MENU
	_clear_world_entities()
	_glider.reset_glider()
	_glider.apply_hull_skin(_config.selected_hull, _config.get_hull_barrel_roll_cd_mult())
	_glider.set_drones_active(_config.upg_wing_drones > 0)
	_audio.set_hyper_mode(false)
	_audio.set_tunnel_mode(false)
	_hud_root.visible = false
	_close_all_modals()
	_menu_overlay.visible = true
	_refresh_menu_ui()


func _start_new_run() -> void:
	_finish_boot_loader_immediately()
	_audio.play_ui_click()
	_clear_world_entities()
	_glider.reset_glider()
	_glider.apply_hull_skin(_config.selected_hull, _config.get_hull_barrel_roll_cd_mult())
	_glider.set_drones_active(_config.upg_wing_drones > 0)
	_reset_hud_cache()

	_state = GameState.PLAYING
	_score = 0
	_last_banked_score = 0
	_run_crystals = 0
	_wave = _config.get_saved_wave(_is_assault_mode)
	_wave_timer = 0.0
	_max_shields = _config.get_max_shields()
	_shields = _max_shields
	_graze_shield_progress = 0
	_slowmo_timer = 0.0
	_prev_wingtips.clear()
	Engine.time_scale = 1.0
	_active_boss = null
	_combo = 1
	_combo_timer = 0.0
	_stat_destroyed = 0
	_stat_grazes = 0
	_max_combo_reached = 1
	_boost_fov_kick = 0.0
	_boss_bar_trail_val = 100.0
	_hyper_charge = 0.0
	_hyper_timer = 0.0
	_tunnel_timer = 0.0
	_sector_index = (_wave - 1) % 4
	_env3d.set_sector_palette(_sector_index)

	# Начальный бонус арсенала на борту для яркого старта
	var ammo_mult: float = _config.get_ammo_multiplier()
	_timer_heavy_plasma = 10.0 * ammo_mult
	_timer_vulcan = 0.0
	_timer_laser = 0.0
	_ammo_missiles = int(round(4.0 * ammo_mult))
	_cd_base_plasma = 0.0
	_cd_heavy_plasma = 0.0
	_cd_vulcan = 0.0
	_cd_missile = 0.0
	_cd_drones = 0.0
	_wake_ring_timer = 0.0
	_wingtip_trail_timer = 0.0

	_director.reset_director()
	_audio.set_hyper_mode(false)
	_audio.set_tunnel_mode(false)

	_close_all_modals()
	_hud_root.visible = true

	_show_banner(_env3d.get_current_sector_name() + " — ПОЛЁТ НАЧАТ!", Color(0.32, 0.96, 1.0), 2.8)
	_update_hud_ui()


func _toggle_pause(paused: bool) -> void:
	_audio.play_ui_click()
	if paused and _state == GameState.PLAYING:
		Engine.time_scale = 1.0
		_slowmo_timer = 0.0
		_bank_uncommitted_credits()
		_state = GameState.PAUSED
		_pause_overlay.visible = true
	elif not paused and _state == GameState.PAUSED:
		_state = GameState.PLAYING
		_pause_overlay.visible = false
		_exit_confirm_msec = 0


func _trigger_game_over() -> void:
	Engine.time_scale = 1.0
	_slowmo_timer = 0.0
	_state = GameState.GAME_OVER
	_audio.play_game_over()
	_audio.set_hyper_mode(false)
	_audio.set_tunnel_mode(false)
	_glider.hide_quantum_laser()

	var is_new_rec: bool = _config.register_run_result(_is_assault_mode, _score, _wave)
	_bank_uncommitted_credits()
	var wave_bonus_crystals: int = maxi(1, _wave / 2)
	_award_crystals(wave_bonus_crystals, true)
	_crystals_dirty_save = false
	var earned_credits: int = _run_crystals

	var mode_title: String = "ГИПЕР-ШТУРМ 3D" if _is_assault_mode else "КОСМО-РЕЙД 3D"
	var rec_tag: String = "\nНОВЫЙ РЕКОРД СЕКТОРА!" if is_new_rec else ""
	_lbl_gameover_stats.text = (
		"РЕЖИМ: %s\n" % mode_title
		+ "СЧЁТ: %d%s\n" % [_score, rec_tag]
		+ "ДОСТИГНУТА ВОЛНА: %d\n" % _wave
		+ "ЛУЧШИЙ РЕКОРД: %d\n" % _config.get_high_score(_is_assault_mode)
		+ "УНИЧТОЖЕНО: %d • НА ГРАНИ: %d • МАКС. КОМБО: x%d\n\n" % [_stat_destroyed, _stat_grazes, _max_combo_reached]
		+ "СОБРАНО КВАНТОВЫХ КРИСТАЛЛОВ: +%d" % earned_credits
	)
	_gameover_overlay.visible = true


# ============================================================================
# ПОСТРОЕНИЕ НЕОНОВОГО SCI-FI ИНТЕРФЕЙСА (HUD, МЕНЮ, АНГАР, НАСТРОЙКИ)
# ============================================================================

func _build_all_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	_ui_root = Control.new()
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_layer.add_child(_ui_root)

	_floating_texts_root = Control.new()
	_floating_texts_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floating_texts_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_floating_texts_root)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_ui_root.add_child(_flash_rect)

	_edge_flash_panel = Panel.new()
	_edge_flash_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge_flash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_flash_panel.visible = false
	var edge_sb := StyleBoxFlat.new()
	edge_sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	edge_sb.border_color = Color(0.22, 0.92, 1.0, 0.85)
	edge_sb.set_border_width_all(10)
	edge_sb.border_blend = true
	_edge_flash_panel.add_theme_stylebox_override("panel", edge_sb)
	_ui_root.add_child(_edge_flash_panel)

	_build_hud_ui()
	_build_menu_overlay()
	_build_pause_overlay()
	_build_gameover_overlay()
	_build_hangar_overlay()
	_build_settings_overlay()
	_build_toast_ui()
	_build_boot_loader_ui()


func _build_boot_loader_ui() -> void:
	_boot_loader_overlay = Control.new()
	_boot_loader_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_loader_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(_boot_loader_overlay)

	var bg_tex_rect := TextureRect.new()
	bg_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex_rect.texture = load("res://Assets/Sprites/SplashScreen.png") as Texture2D
	bg_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_boot_loader_overlay.add_child(bg_tex_rect)

	_boot_panel = UiBuilder.create_glass_panel(
		Color(0.015, 0.045, 0.12, 0.92),
		Color(0.28, 0.96, 1.0, 0.88),
		14,
		18.0,
		12.0
	)
	_boot_panel.position = Vector2(34.0, VIEW_H - 148.0)
	_boot_panel.size = Vector2(VIEW_W - 68.0, 82.0)
	_boot_loader_overlay.add_child(_boot_panel)

	var b_vbox := VBoxContainer.new()
	b_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_vbox.add_theme_constant_override("separation", 8)
	_boot_panel.add_child(b_vbox)

	_lbl_boot_status = UiBuilder.create_label(
		"ИНИЦИАЛИЗАЦИЯ 3D-СИСТЕМ... 10%",
		14,
		Color(0.84, 0.98, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER,
		3
	)
	b_vbox.add_child(_lbl_boot_status)

	_bar_boot_load = UiBuilder.create_neon_progress_bar(
		14.0,
		Color(0.01, 0.03, 0.08, 0.95),
		Color(0.20, 0.72, 0.92, 0.65),
		Color(0.18, 0.96, 0.84, 0.98),
		7,
		1
	)
	_bar_boot_load.value = 10.0
	b_vbox.add_child(_bar_boot_load)

	_boot_step = 0
	_boot_fade_timer = 0.0


func _update_boot_loader(delta: float) -> void:
	if _boot_loader_overlay == null or not _boot_loader_overlay.visible:
		return

	if _boot_step == 0:
		_lbl_boot_status.text = "ГЕНЕРАЦИЯ 3D-МЕТЕОРИТОВ И КРИСТАЛЛОВ... 25%"
		_bar_boot_load.value = 25.0
		_boot_step = 1
	elif _boot_step == 1:
		SpaceEntity3D.warm_up_assets()
		_lbl_boot_status.text = "ЗАРЯДКА ПУЛА ПЛАЗМЕННЫХ ОРУДИЙ... 52%"
		_bar_boot_load.value = 52.0
		_boot_step = 2
	elif _boot_step == 2:
		_warm_up_projectile_pool(32)
		_lbl_boot_status.text = "ПОДГОТОВКА ПУЛА 3D-СПЕЦЭФФЕКТОВ... 76%"
		_bar_boot_load.value = 76.0
		_boot_step = 3
	elif _boot_step == 3:
		_fx3d.warm_up_pool(42)
		# Помещаем мини-кластер всех 3D-шейдеров перед камерой за экраном загрузки на 1 кадр для компиляции PSO Vulkan
		_shader_warmup_node = SpaceEntity3D.build_shader_warmup_cluster()
		_shader_warmup_node.position = Vector3(0.0, 0.5, -10.0)
		add_child(_shader_warmup_node)
		_env3d.set_tunnel_warmup(true)
		_lbl_boot_status.text = "КОМПИЛЯЦИЯ 3D-ШЕЙДЕРОВ... 94%"
		_bar_boot_load.value = 94.0
		_boot_step = 4
	elif _boot_step == 4:
		_env3d.set_tunnel_warmup(false)
		if _shader_warmup_node != null and is_instance_valid(_shader_warmup_node):
			_shader_warmup_node.queue_free()
			_shader_warmup_node = null
		_lbl_boot_status.text = "СИСТЕМЫ ГОТОВЫ К ВЗЛЁТУ! 100%"
		_bar_boot_load.value = 100.0
		_boot_fade_timer = 0.26
		_boot_step = 5
	elif _boot_step == 5:
		_boot_fade_timer -= delta
		if _boot_fade_timer <= 0.0:
			_boot_loader_overlay.visible = false
			_boot_loader_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			_boot_loader_overlay.modulate.a = clampf(_boot_fade_timer / 0.26, 0.0, 1.0)


func _finish_boot_loader_immediately() -> void:
	if _boot_step < 5:
		SpaceEntity3D.warm_up_assets()
		_warm_up_projectile_pool(32)
		_fx3d.warm_up_pool(42)
		if _env3d != null:
			_env3d.set_tunnel_warmup(false)
		if _shader_warmup_node != null and is_instance_valid(_shader_warmup_node):
			_shader_warmup_node.queue_free()
			_shader_warmup_node = null
		_boot_step = 5
	if _boot_loader_overlay != null:
		_boot_loader_overlay.visible = false
		_boot_loader_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_hud_safe_margins() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return
	_view_w = vp_size.x
	_view_h = maxf(VIEW_H, vp_size.y)

	# Переводим системную безопасную зону (вырез камеры, статус-бар, скругления Android) в логические пиксели (safe_top_vp)
	var win_size := Vector2(DisplayServer.window_get_size())
	var safe_top_vp: float = 0.0
	var safe_bot_vp: float = 0.0
	if win_size.y > 1.0:
		var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
		var scale_y: float = _view_h / win_size.y
		safe_top_vp = maxf(0.0, float(safe_rect.position.y) * scale_y)
		safe_bot_vp = maxf(0.0, (win_size.y - float(safe_rect.end.y)) * scale_y)

	if OS.has_feature("mobile") or _view_h > 1020.0:
		safe_top_vp = maxf(safe_top_vp, 44.0)

	_safe_top_vp = safe_top_vp
	_safe_bot_vp = safe_bot_vp

	var top_y: float = _safe_top_vp + 10.0
	if _top_panel != null:
		_top_panel.position = Vector2(12.0, top_y)
		_top_panel.size = Vector2(_view_w - 24.0, 58.0)
	if _hyper_hbox != null:
		_hyper_hbox.position = Vector2(12.0, top_y + 62.0)
		_hyper_hbox.size = Vector2(_view_w - 24.0, 30.0)
	if _slots_hbox != null:
		_slots_hbox.position = Vector2(12.0, top_y + 96.0)
		_slots_hbox.size = Vector2(_view_w - 24.0, 42.0)
	if _lbl_sector != null:
		_lbl_sector.position = Vector2(16.0, top_y + 142.0)
		_lbl_sector.size = Vector2(_view_w - 32.0, 20.0)
	if _lbl_banner != null:
		_lbl_banner.position = Vector2(16.0, top_y + 164.0)
		_lbl_banner.size = Vector2(_view_w - 32.0, 44.0)
	if _boss_hud_panel != null:
		_boss_hud_panel.position = Vector2(20.0, top_y + 210.0)
		_boss_hud_panel.size = Vector2(_view_w - 40.0, 42.0)
	if _toast_panel != null:
		_toast_panel.position = Vector2(50.0, _view_h - 115.0 - _safe_bot_vp)
		_toast_panel.size = Vector2(_view_w - 100.0, 50.0)
	if _boot_panel != null:
		_boot_panel.position = Vector2(34.0, _view_h - 148.0 - _safe_bot_vp)
		_boot_panel.size = Vector2(_view_w - 68.0, 82.0)

	_relayout_modal_cards()


func _relayout_modal_cards() -> void:
	for item: Dictionary in _modal_cards:
		var card := item.get("card") as Control
		var mx: float = float(item.get("margin_x", 22.0))
		var ch: float = float(item.get("card_h", 500.0))
		if card != null and is_instance_valid(card):
			card.size = Vector2(_view_w - mx * 2.0, ch)
			card.position = Vector2(mx, (_view_h - card.size.y) * 0.5)


func _build_hud_ui() -> void:
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_root.add_child(_hud_root)

	# 1. Верхняя стеклянная панель статуса (Счёт, Щиты, Волна, Комбо, Пауза)
	_top_panel = UiBuilder.create_glass_panel(
		Color(0.02, 0.06, 0.14, 0.84),
		Color(0.22, 0.86, 1.0, 0.72),
		12,
		12.0,
		6.0
	)
	_top_panel.position = Vector2(12.0, 10.0)
	_top_panel.size = Vector2(VIEW_W - 24.0, 58.0)
	_hud_root.add_child(_top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	_top_panel.add_child(top_hbox)

	var left_vbox := VBoxContainer.new()
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_theme_constant_override("separation", 2)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(left_vbox)

	_lbl_score = UiBuilder.create_label("СЧЁТ: 0", 18, Color(0.92, 0.99, 1.0), HORIZONTAL_ALIGNMENT_LEFT, 2)
	left_vbox.add_child(_lbl_score)

	# Неоновые ячейки Грави-Щита (ColorRect вместо спецсимволов шрифта) + прогресс манёвра «На грани»
	var shield_row := HBoxContainer.new()
	shield_row.add_theme_constant_override("separation", 5)
	left_vbox.add_child(shield_row)

	_lbl_shields = UiBuilder.create_label("ЩИТ:", 12, Color(0.25, 1.0, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	shield_row.add_child(_lbl_shields)

	_shield_dots.clear()
	for i: int in range(6):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(11.0, 11.0)
		dot.color = Color(0.22, 0.96, 0.76, 1.0)
		shield_row.add_child(dot)
		_shield_dots.append(dot)

	_lbl_graze_progress = UiBuilder.create_label(" • 0/5", 11, Color(0.56, 0.88, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	shield_row.add_child(_lbl_graze_progress)

	var mid_vbox := VBoxContainer.new()
	mid_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mid_vbox.add_theme_constant_override("separation", 2)
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(mid_vbox)

	_lbl_wave = UiBuilder.create_label("ВОЛНА 1", 17, Color(0.36, 0.94, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 2)
	mid_vbox.add_child(_lbl_wave)

	_lbl_combo = UiBuilder.create_label("КОМБО x1", 13, Color(1.0, 0.84, 0.28), HORIZONTAL_ALIGNMENT_CENTER)
	mid_vbox.add_child(_lbl_combo)

	var btn_pause := UiBuilder.create_neon_button(
		"II",
		Vector2(44.0, 44.0),
		Color(0.05, 0.16, 0.30, 0.92),
		Color(0.32, 0.88, 1.0, 0.85),
		Color.WHITE,
		17
	)
	btn_pause.pressed.connect(func() -> void: _toggle_pause(true))
	top_hbox.add_child(btn_pause)

	# 2. Вторая строка сверху: Шкала и кнопка Гипер-Ядра / Гипер-Туннеля (вверху, чтобы низ экрана с 3D-глайдером был полностью чистым!)
	_hyper_hbox = HBoxContainer.new()
	_hyper_hbox.position = Vector2(12.0, 72.0)
	_hyper_hbox.size = Vector2(VIEW_W - 24.0, 30.0)
	_hyper_hbox.add_theme_constant_override("separation", 8)
	_hud_root.add_child(_hyper_hbox)

	_bar_hyper = UiBuilder.create_neon_progress_bar(
		30.0,
		Color(0.01, 0.03, 0.08, 0.92),
		Color(0.20, 0.65, 0.88, 0.65),
		Color(0.22, 0.94, 0.82, 0.92),
		8,
		1
	)
	_bar_hyper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hyper_hbox.add_child(_bar_hyper)

	_btn_hyper = UiBuilder.create_neon_button(
		"ГИПЕР-ЯДРО 0%",
		Vector2(204.0, 30.0),
		Color(0.05, 0.16, 0.28, 0.92),
		Color(0.24, 0.78, 0.96, 0.70),
		Color(0.82, 0.95, 1.0),
		12
	)
	_btn_hyper.pressed.connect(_try_activate_hyper_core)
	_hyper_hbox.add_child(_btn_hyper)

	# 3. Третья строка сверху: 4 компактных слота Мульти-Арсенала (как в Super Glider, под панелью Гипер-Ядра)
	_slots_hbox = HBoxContainer.new()
	_slots_hbox.position = Vector2(12.0, 106.0)
	_slots_hbox.size = Vector2(VIEW_W - 24.0, 42.0)
	_slots_hbox.add_theme_constant_override("separation", 6)
	_hud_root.add_child(_slots_hbox)

	var slot_titles: Array[String] = ["ПЛАЗМА+", "ВУЛКАН", "3D-ЛАЗЕР", "РАКЕТЫ"]
	_slot_panels.clear()
	_slot_labels.clear()
	for i: int in range(4):
		var sp := UiBuilder.create_glass_panel(
			Color(0.03, 0.09, 0.18, 0.86),
			Color(0.18, 0.55, 0.75, 0.45),
			9,
			5.0,
			3.0
		)
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_slots_hbox.add_child(sp)
		_slot_panels.append(sp)

		var sl := UiBuilder.create_label("%s\n--" % slot_titles[i], 11, Color(0.62, 0.78, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
		sp.add_child(sl)
		_slot_labels.append(sl)

	# 4. Индикатор текущего сектора и баннер событий под верхним блоком HUD
	_lbl_sector = UiBuilder.create_label("СЕКТОР I: КВАНТОВАЯ БЕЗДНА", 12, Color(0.65, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 2)
	_lbl_sector.position = Vector2(16.0, 152.0)
	_lbl_sector.size = Vector2(VIEW_W - 32.0, 20.0)
	_hud_root.add_child(_lbl_sector)

	_lbl_banner = UiBuilder.create_label("", 16, Color(0.35, 0.98, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 3)
	_lbl_banner.position = Vector2(16.0, 174.0)
	_lbl_banner.size = Vector2(VIEW_W - 32.0, 42.0)
	_lbl_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_banner.visible = false
	_hud_root.add_child(_lbl_banner)

	# 5. Панель здоровья 3D Босса-Дредноута (появляется во время битвы с 3D-Боссом)
	_boss_hud_panel = UiBuilder.create_glass_panel(
		Color(0.14, 0.03, 0.08, 0.90),
		Color(1.0, 0.28, 0.48, 0.88),
		10,
		10.0,
		4.0
	)
	_boss_hud_panel.position = Vector2(20.0, 220.0)
	_boss_hud_panel.size = Vector2(VIEW_W - 40.0, 42.0)
	_boss_hud_panel.visible = false
	_hud_root.add_child(_boss_hud_panel)

	var boss_vbox := VBoxContainer.new()
	boss_vbox.add_theme_constant_override("separation", 3)
	_boss_hud_panel.add_child(boss_vbox)

	_lbl_boss_title = UiBuilder.create_label("КРЕЙСЕР «ТИТАН-3D»", 12, Color(1.0, 0.58, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	boss_vbox.add_child(_lbl_boss_title)

	var boss_bar_stack := Control.new()
	boss_bar_stack.custom_minimum_size = Vector2(0.0, 10.0)
	boss_vbox.add_child(boss_bar_stack)
	_bar_boss_trail = UiBuilder.create_neon_progress_bar(
		10.0,
		Color(0.06, 0.01, 0.03, 0.95),
		Color(0.0, 0.0, 0.0, 0.0),
		Color(1.0, 0.88, 0.36, 0.92),
		5,
		0
	)
	_bar_boss_trail.value = 100.0
	_bar_boss_trail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_bar_stack.add_child(_bar_boss_trail)
	_bar_boss_hp = UiBuilder.create_neon_progress_bar(
		10.0,
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0),
		Color(1.0, 0.24, 0.46, 0.98),
		5,
		0
	)
	_bar_boss_hp.value = 100.0
	_bar_boss_hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_bar_stack.add_child(_bar_boss_hp)


func _reset_hud_cache() -> void:
	_hud_c_score = -1
	_hud_c_wave = -1
	_hud_c_combo = -1
	_hud_c_crystals = -1
	_hud_c_shields = -1
	_hud_c_max_shields = -1
	_hud_c_graze = -1
	_hud_c_sector_mode = -1
	_hud_c_sector_tenths = -1
	_hud_c_sector_idx = -1
	_hud_c_hyper_mode = -1
	_hud_c_hyper_val = -1
	_hud_c_boss_pct = -1
	_hud_c_boss_rage = -1
	_hud_c_slot_val = [-99, -99, -99, -99]


func _update_hud_ui() -> void:
	if _hud_root == null or not _hud_root.visible:
		return

	if _score != _hud_c_score:
		_hud_c_score = _score
		_lbl_score.text = "СЧЁТ: %d" % _score
	if _wave != _hud_c_wave:
		_hud_c_wave = _wave
		_lbl_wave.text = "ВОЛНА %d" % _wave
	if _combo != _hud_c_combo or _run_crystals != _hud_c_crystals:
		_hud_c_combo = _combo
		_hud_c_crystals = _run_crystals
		_lbl_combo.text = "КОМБО x%d  •  %d КР" % [_combo, _run_crystals]

	if _shields != _hud_c_shields or _max_shields != _hud_c_max_shields:
		_hud_c_shields = _shields
		_hud_c_max_shields = _max_shields
		for i: int in range(_shield_dots.size()):
			var dot: ColorRect = _shield_dots[i]
			dot.visible = i < _max_shields
			if i < _shields:
				dot.color = Color(0.22, 0.98, 0.76, 1.0)
			else:
				dot.color = Color(0.12, 0.24, 0.34, 0.65)

	if _lbl_graze_progress != null and _graze_shield_progress != _hud_c_graze:
		_hud_c_graze = _graze_shield_progress
		_lbl_graze_progress.text = " • ГРАНЬ %d/5" % _graze_shield_progress

	var sec_mode: int = 2 if _tunnel_timer > 0.0 else (1 if _hyper_timer > 0.0 else (3 if _get_active_special_weapons_count() >= 3 else 0))
	var sec_tenths: int = int(round((_tunnel_timer if sec_mode == 2 else _hyper_timer) * 10.0))
	if sec_mode != _hud_c_sector_mode or (sec_mode > 0 and sec_tenths != _hud_c_sector_tenths) or (sec_mode == 0 and _sector_index != _hud_c_sector_idx) or (sec_mode == 3 and _hud_c_sector_mode != 3):
		_hud_c_sector_mode = sec_mode
		_hud_c_sector_tenths = sec_tenths
		_hud_c_sector_idx = _sector_index
		if sec_mode == 3:
			_lbl_sector.text = "ОВЕРДРАЙВ АРСЕНАЛА — ОГОНЬ x1.25!"
		elif sec_mode == 2:
			_lbl_sector.text = "3D ГИПЕР-ТУННЕЛЬ ЧЁРНОЙ ДЫРЫ: %.1f СЕК" % (float(sec_tenths) * 0.1)
		elif sec_mode == 1:
			_lbl_sector.text = "ГИПЕРСКОРОСТЬ АКТИВНА: %.1f СЕК" % (float(sec_tenths) * 0.1)
		else:
			_lbl_sector.text = _env3d.get_current_sector_name()

	if _boss_hud_panel != null:
		var has_b: bool = is_instance_valid(_active_boss) and not _active_boss.is_destroyed and not _active_boss.is_queued_for_deletion()
		if _boss_hud_panel.visible != has_b:
			_boss_hud_panel.visible = has_b
			if not has_b:
				_hud_c_boss_pct = -1
		if has_b:
			var pct: float = clampf((_active_boss.hp / maxf(1.0, _active_boss.max_hp)) * 100.0, 0.0, 100.0)
			_bar_boss_hp.value = pct
			if pct > _boss_bar_trail_val:
				_boss_bar_trail_val = pct
			else:
				_boss_bar_trail_val = move_toward(_boss_bar_trail_val, pct, get_process_delta_time() * 26.0)
			_bar_boss_trail.value = _boss_bar_trail_val
			var pct_int: int = int(ceil(pct))
			var rage_int: int = 1 if _active_boss.boss_enraged else 0
			if pct_int != _hud_c_boss_pct or rage_int != _hud_c_boss_rage:
				_hud_c_boss_pct = pct_int
				_hud_c_boss_rage = rage_int
				var rage_str: String = " [ЯРОСТЬ]" if rage_int == 1 else ""
				_lbl_boss_title.text = "%s%s — %d%%" % [_active_boss.boss_title, rage_str, pct_int]

	# Обновляем 4 слота оружия только при изменении целых секунд / боезапаса
	var s0: int = int(ceil(_timer_heavy_plasma)) if _timer_heavy_plasma > 0.0 else 0
	var s1: int = int(ceil(_timer_vulcan)) if _timer_vulcan > 0.0 else 0
	var s2: int = int(ceil(_timer_laser)) if _timer_laser > 0.0 else 0
	var s3: int = _ammo_missiles if _ammo_missiles > 0 else 0
	if s0 != _hud_c_slot_val[0]:
		_hud_c_slot_val[0] = s0
		_update_weapon_slot_ui(0, "ПЛАЗМА+", s0 > 0, "%dс" % s0, Color(0.28, 1.0, 0.55))
	if s1 != _hud_c_slot_val[1]:
		_hud_c_slot_val[1] = s1
		_update_weapon_slot_ui(1, "ВУЛКАН", s1 > 0, "%dс" % s1, Color(1.0, 0.85, 0.25))
	if s2 != _hud_c_slot_val[2]:
		_hud_c_slot_val[2] = s2
		_update_weapon_slot_ui(2, "3D-ЛАЗЕР", s2 > 0, "%dс" % s2, Color(0.25, 0.96, 1.0))
	if s3 != _hud_c_slot_val[3]:
		_hud_c_slot_val[3] = s3
		_update_weapon_slot_ui(3, "РАКЕТЫ", s3 > 0, "x%d" % s3, Color(1.0, 0.42, 0.32))

	_bar_hyper.value = 100.0 if (_hyper_timer > 0.0 or _tunnel_timer > 0.0) else _hyper_charge
	var h_mode: int = 3 if _tunnel_timer > 0.0 else (2 if _hyper_timer > 0.0 else (1 if _hyper_charge >= 100.0 else 0))
	var h_val: int = int(round(_tunnel_timer * 10.0)) if h_mode == 3 else (int(round(_hyper_timer * 10.0)) if h_mode == 2 else int(round(_hyper_charge)))
	if h_mode != _hud_c_hyper_mode or h_val != _hud_c_hyper_val:
		var mode_changed: bool = (h_mode != _hud_c_hyper_mode)
		_hud_c_hyper_mode = h_mode
		_hud_c_hyper_val = h_val
		if h_mode == 3:
			_btn_hyper.text = "ГИПЕР-ТУННЕЛЬ %.1fС" % (float(h_val) * 0.1)
			if mode_changed:
				UiBuilder.apply_button_colors(_btn_hyper, Color(0.32, 0.10, 0.55, 0.96), Color(0.92, 0.45, 1.0, 1.0))
		elif h_mode == 2:
			_btn_hyper.text = "ГИПЕРСКОРОСТЬ %.1fС" % (float(h_val) * 0.1)
			if mode_changed:
				UiBuilder.apply_button_colors(_btn_hyper, Color(0.06, 0.48, 0.38, 0.96), Color(0.35, 1.0, 0.82, 1.0))
		elif h_mode == 1:
			_btn_hyper.text = "ПУСК ГИПЕР-ЯДРА! [SPACE]"
			if mode_changed:
				UiBuilder.apply_button_colors(_btn_hyper, Color(0.08, 0.52, 0.42, 0.98), Color(0.42, 1.0, 0.84, 1.0))
		else:
			_btn_hyper.text = "ГИПЕР-ЯДРО %d%%" % h_val
			if mode_changed:
				UiBuilder.apply_button_colors(_btn_hyper, Color(0.05, 0.16, 0.28, 0.92), Color(0.24, 0.78, 0.96, 0.70))


func _update_weapon_slot_ui(idx: int, title: String, active: bool, val_str: String, active_col: Color) -> void:
	if idx >= _slot_panels.size() or idx >= _slot_labels.size():
		return
	var panel: PanelContainer = _slot_panels[idx]
	var lbl: Label = _slot_labels[idx]
	if active:
		lbl.text = "%s\n%s" % [title, val_str]
		lbl.add_theme_color_override("font_color", active_col)
		UiBuilder.set_panel_colors(panel, Color(0.05, 0.16, 0.28, 0.95), active_col)
	else:
		lbl.text = "%s\n--" % title
		lbl.add_theme_color_override("font_color", Color(0.50, 0.64, 0.78))
		UiBuilder.set_panel_colors(panel, Color(0.02, 0.07, 0.14, 0.85), Color(0.16, 0.42, 0.60, 0.38))


func _build_menu_overlay() -> void:
	var modal: Dictionary = UiBuilder.create_modal_overlay(
		_ui_root,
		VIEW_W,
		VIEW_H,
		22.0,
		690.0,
		Color(0.02, 0.05, 0.13, 0.84),
		Color(0.28, 0.92, 1.0, 0.88),
		Color(0.01, 0.02, 0.05, 0.42),
		12
	)
	_menu_overlay = modal["root"]
	_modal_cards.append({"card": modal["card"], "margin_x": 22.0, "card_h": 690.0})
	var vbox: VBoxContainer = modal["vbox"]

	var title := UiBuilder.create_label("HYPER GLIDER 3D", 30, Color(0.38, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 4)
	vbox.add_child(title)

	var subtitle := UiBuilder.create_label(
		"3D-ПОЛЁТ ОТ 3-ГО ЛИЦА • ПЛАЗМА • ЧЁРНЫЕ ДЫРЫ • ГИПЕР-ТУННЕЛЬ",
		12,
		Color(0.76, 0.92, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	_lbl_menu_records = UiBuilder.create_label("", 15, Color(0.28, 1.0, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_lbl_menu_records)

	_lbl_menu_credits = UiBuilder.create_label("", 15, Color(1.0, 0.86, 0.32), HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(_lbl_menu_credits)

	# Переключатель режима (Космо-Рейд 3D / Гипер-Штурм 3D)
	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(mode_hbox)

	_btn_mode_arcade = UiBuilder.create_secondary_button("КОСМО-РЕЙД 3D", 48.0, 15)
	_btn_mode_arcade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_mode_arcade.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_is_assault_mode = false
		_refresh_menu_ui()
	)
	mode_hbox.add_child(_btn_mode_arcade)

	_btn_mode_assault = UiBuilder.create_secondary_button("ГИПЕР-ШТУРМ 3D", 48.0, 15)
	_btn_mode_assault.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_mode_assault.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_is_assault_mode = true
		_refresh_menu_ui()
	)
	mode_hbox.add_child(_btn_mode_assault)

	# Выбор стартовой волны (чекпоинт)
	var wave_hbox := HBoxContainer.new()
	wave_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(wave_hbox)

	_btn_wave_prev = UiBuilder.create_secondary_button("<", 42.0, 18)
	_btn_wave_prev.custom_minimum_size = Vector2(52.0, 42.0)
	_btn_wave_prev.pressed.connect(func() -> void:
		_audio.play_ui_click()
		var cur_w: int = _config.get_saved_wave(_is_assault_mode)
		_config.set_saved_wave(_is_assault_mode, cur_w - 1)
		_refresh_menu_ui()
	)
	wave_hbox.add_child(_btn_wave_prev)

	_lbl_start_wave = UiBuilder.create_label("СТАРТ С ВОЛНЫ: 1 / 1", 16, Color(0.88, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_start_wave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wave_hbox.add_child(_lbl_start_wave)

	_btn_wave_next = UiBuilder.create_secondary_button(">", 42.0, 18)
	_btn_wave_next.custom_minimum_size = Vector2(52.0, 42.0)
	_btn_wave_next.pressed.connect(func() -> void:
		_audio.play_ui_click()
		var cur_w: int = _config.get_saved_wave(_is_assault_mode)
		_config.set_saved_wave(_is_assault_mode, cur_w + 1)
		_refresh_menu_ui()
	)
	wave_hbox.add_child(_btn_wave_next)

	_btn_start_launch = UiBuilder.create_launch_hero_button("В ПОЛЁТ!", 64.0, 24)
	_btn_start_launch.pressed.connect(_start_new_run)
	vbox.add_child(_btn_start_launch)

	var btn_hangar := UiBuilder.create_secondary_button("АНГАР 3D-АПГРЕЙДОВ", 52.0, 17)
	btn_hangar.pressed.connect(_open_hangar_overlay)
	vbox.add_child(btn_hangar)

	var btn_settings := UiBuilder.create_secondary_button("НАСТРОЙКИ 3D И ЗВУКА", 50.0, 17)
	btn_settings.pressed.connect(_open_settings_overlay)
	vbox.add_child(btn_settings)

	var hint_lbl := UiBuilder.create_label(
		"Управление: Свайп/Мышь (3D-полёт) или WASD / Стрелки.\nДвойной тап / Q, E — 360° Бочка (отражает вражескую плазму!).",
		12,
		Color(0.64, 0.82, 0.96),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint_lbl)


func _refresh_menu_ui() -> void:
	var rec: int = _config.get_high_score(_is_assault_mode)
	var best_w: int = _config.get_best_wave(_is_assault_mode)
	var saved_w: int = _config.get_saved_wave(_is_assault_mode)
	_lbl_menu_records.text = "РЕКОРД: %d ОЧКОВ • ЛУЧШАЯ ВОЛНА: %d" % [rec, best_w]
	_lbl_menu_credits.text = "КВАНТОВЫЕ КРИСТАЛЛЫ: %d КР" % _config.quantum_crystals
	_lbl_start_wave.text = "СТАРТ С ВОЛНЫ: %d / %d" % [saved_w, best_w]

	if not _is_assault_mode:
		UiBuilder.apply_button_colors(_btn_mode_arcade, Color(0.06, 0.42, 0.64, 0.96), Color(0.38, 0.96, 1.0, 1.0))
		UiBuilder.apply_button_colors(_btn_mode_assault, Color(0.04, 0.10, 0.20, 0.88), Color(0.22, 0.65, 0.82, 0.45))
	else:
		UiBuilder.apply_button_colors(_btn_mode_arcade, Color(0.04, 0.10, 0.20, 0.88), Color(0.22, 0.65, 0.82, 0.45))
		UiBuilder.apply_button_colors(_btn_mode_assault, Color(0.52, 0.12, 0.34, 0.96), Color(1.0, 0.42, 0.68, 1.0))


func _build_pause_overlay() -> void:
	var modal: Dictionary = UiBuilder.create_modal_overlay(
		_ui_root,
		VIEW_W,
		VIEW_H,
		34.0,
		420.0,
		Color(0.02, 0.06, 0.15, 0.94),
		Color(0.32, 0.92, 1.0, 0.88)
	)
	_pause_overlay = modal["root"]
	_modal_cards.append({"card": modal["card"], "margin_x": 34.0, "card_h": 420.0})
	var vbox: VBoxContainer = modal["vbox"]

	vbox.add_child(UiBuilder.create_label("ПАУЗА", 26, Color(0.38, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 3))

	var btn_resume := UiBuilder.create_primary_button("ПРОДОЛЖИТЬ ПОЛЁТ", 56.0, 19)
	btn_resume.pressed.connect(func() -> void: _toggle_pause(false))
	vbox.add_child(btn_resume)

	var btn_hangar := UiBuilder.create_secondary_button("АНГАР 3D-АПГРЕЙДОВ", 48.0, 16)
	btn_hangar.pressed.connect(_open_hangar_overlay)
	vbox.add_child(btn_hangar)

	var btn_settings := UiBuilder.create_secondary_button("НАСТРОЙКИ", 48.0, 16)
	btn_settings.pressed.connect(_open_settings_overlay)
	vbox.add_child(btn_settings)

	var btn_menu := UiBuilder.create_danger_button("В ГЛАВНОЕ МЕНЮ", 50.0, 17)
	btn_menu.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_enter_menu_state()
	)
	vbox.add_child(btn_menu)


func _build_gameover_overlay() -> void:
	var modal: Dictionary = UiBuilder.create_modal_overlay(
		_ui_root,
		VIEW_W,
		VIEW_H,
		26.0,
		500.0,
		Color(0.04, 0.05, 0.14, 0.95),
		Color(1.0, 0.36, 0.54, 0.90)
	)
	_gameover_overlay = modal["root"]
	_modal_cards.append({"card": modal["card"], "margin_x": 26.0, "card_h": 545.0})
	var vbox: VBoxContainer = modal["vbox"]

	vbox.add_child(UiBuilder.create_label("ГЛАЙДЕР ПОДБИТ", 26, Color(1.0, 0.42, 0.56), HORIZONTAL_ALIGNMENT_CENTER, 3))

	_lbl_gameover_stats = UiBuilder.create_label("", 16, Color(0.88, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_lbl_gameover_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_lbl_gameover_stats)

	var btn_retry := UiBuilder.create_primary_button("НОВЫЙ ВЫЛЕТ В 3D", 58.0, 20)
	btn_retry.pressed.connect(_start_new_run)
	vbox.add_child(btn_retry)

	var btn_hangar := UiBuilder.create_secondary_button("АНГАР 3D-АПГРЕЙДОВ", 52.0, 17)
	btn_hangar.pressed.connect(_open_hangar_overlay)
	vbox.add_child(btn_hangar)

	var btn_menu := UiBuilder.create_secondary_button("ГЛАВНОЕ МЕНЮ", 50.0, 17)
	btn_menu.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_enter_menu_state()
	)
	vbox.add_child(btn_menu)


func _build_hangar_overlay() -> void:
	var modal: Dictionary = UiBuilder.create_modal_overlay(
		_ui_root,
		VIEW_W,
		VIEW_H,
		18.0,
		760.0,
		Color(0.02, 0.05, 0.14, 0.96),
		Color(0.32, 0.94, 1.0, 0.90),
		Color(0.01, 0.02, 0.06, 0.86),
		10
	)
	_hangar_overlay = modal["root"]
	_modal_cards.append({"card": modal["card"], "margin_x": 18.0, "card_h": 760.0})
	var card_vbox: VBoxContainer = modal["vbox"]

	card_vbox.add_child(UiBuilder.create_label("АНГАР 3D-АПГРЕЙДОВ", 23, Color(0.38, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 3))

	_lbl_hangar_credits = UiBuilder.create_label("КРИСТАЛЛЫ: 25 КР", 17, Color(1.0, 0.86, 0.30), HORIZONTAL_ALIGNMENT_CENTER)
	card_vbox.add_child(_lbl_hangar_credits)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_vbox.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var upg_defs: Array[Dictionary] = [
		{"key": "wave_shield", "title": "3D ГРАВИ-ЩИТ", "desc": "До 5 щитов (+1 с Титаном) + ударная волна"},
		{"key": "plasma_cannon", "title": "ПЛАЗМЕННЫЙ УСИЛИТЕЛЬ", "desc": "+Темп стрельбы и урон плазменных пушек"},
		{"key": "ammo_bay", "title": "ОРУЖЕЙНЫЙ ОТСЕК", "desc": "+20%..+100% к времени спецоружия и ракетам"},
		{"key": "wing_drones", "title": "КРЫЛЬЕВЫЕ 3D-ДРОНЫ", "desc": "Два 3D-дрона ведут огонь плазмой по курсу"},
		{"key": "hyper_core", "title": "ГИПЕР-РЕАКТОР И МАГНИТ", "desc": "+Захват сфер и время в Гипер-туннеле"}
	]

	_hangar_rows.clear()
	for def: Dictionary in upg_defs:
		var card := UiBuilder.create_glass_panel(
			Color(0.03, 0.09, 0.19, 0.92),
			Color(0.20, 0.68, 0.88, 0.55),
			12,
			10.0,
			8.0
		)
		vbox.add_child(card)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 8)
		card.add_child(row_hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_child(info_vbox)

		var lbl_t := UiBuilder.create_label(String(def["title"]), 15, Color(0.88, 0.97, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
		info_vbox.add_child(lbl_t)

		var lbl_d := UiBuilder.create_label(String(def["desc"]), 12, Color(0.62, 0.82, 0.96), HORIZONTAL_ALIGNMENT_LEFT)
		lbl_d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(lbl_d)

		# 5 неоновых индикаторов уровня апгрейда (ColorRect)
		var pips_hbox := HBoxContainer.new()
		pips_hbox.add_theme_constant_override("separation", 5)
		info_vbox.add_child(pips_hbox)
		var level_pips: Array[ColorRect] = []
		for p_i: int in range(GameConfig.MAX_UPGRADE_LEVEL):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(22.0, 7.0)
			pip.color = Color(0.12, 0.24, 0.36, 0.75)
			pips_hbox.add_child(pip)
			level_pips.append(pip)

		var key_str: String = String(def["key"])
		var btn_buy := UiBuilder.create_primary_button("КУПИТЬ", 44.0, 14)
		btn_buy.custom_minimum_size = Vector2(132.0, 44.0)
		btn_buy.pressed.connect(func() -> void:
			if _config.buy_upgrade(key_str):
				_audio.play_weapon_pickup()
				_glider.set_drones_active(_config.upg_wing_drones > 0)
				_max_shields = _config.get_max_shields()
				_refresh_hangar_ui()
				_refresh_menu_ui()
			else:
				_audio.play_ui_click()
		)
		row_hbox.add_child(btn_buy)

		_hangar_rows.append({
			"key": key_str,
			"base_title": String(def["title"]),
			"lbl_title": lbl_t,
			"btn_buy": btn_buy,
			"pips": level_pips
		})

	# Бесконечный эндгейм-блок: ОВЕРКЛОК РЕАКТОРА (открывается после 5/5 всех 5 систем)
	var oc_card := UiBuilder.create_glass_panel(
		Color(0.09, 0.04, 0.16, 0.94),
		Color(1.0, 0.78, 0.24, 0.72),
		12,
		10.0,
		8.0
	)
	vbox.add_child(oc_card)
	var oc_hbox := HBoxContainer.new()
	oc_hbox.add_theme_constant_override("separation", 8)
	oc_card.add_child(oc_hbox)
	var oc_info := VBoxContainer.new()
	oc_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oc_hbox.add_child(oc_info)
	var oc_title := UiBuilder.create_label("ОВЕРКЛОК РЕАКТОРА", 15, Color(1.0, 0.86, 0.32), HORIZONTAL_ALIGNMENT_LEFT)
	oc_info.add_child(oc_title)
	var oc_desc := UiBuilder.create_label("+6% урон и +8% очки за каждый уровень (∞)", 12, Color(0.88, 0.82, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	oc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	oc_info.add_child(oc_desc)
	var oc_btn := UiBuilder.create_primary_button("5/5 СИСТЕМ", 44.0, 13)
	oc_btn.custom_minimum_size = Vector2(132.0, 44.0)
	oc_btn.pressed.connect(func() -> void:
		if _config.buy_overclock():
			_audio.play_weapon_pickup()
			_refresh_hangar_ui()
			_refresh_menu_ui()
		else:
			_audio.play_ui_click()
	)
	oc_hbox.add_child(oc_btn)
	_overclock_row = {"lbl_title": oc_title, "lbl_desc": oc_desc, "btn_buy": oc_btn}

	# Секция выбора и покупки 4 уникальных 3D-корпусов глайдера с боевыми перками
	vbox.add_child(UiBuilder.create_label("3D-КОРПУСА ГЛАЙДЕРА (СКИН + ПЕРК)", 15, Color(0.38, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 2))
	_hull_rows.clear()
	for h_def: Dictionary in GameConfig.HULL_DEFS:
		var h_id: int = int(h_def["id"])
		var h_card := UiBuilder.create_glass_panel(
			Color(0.03, 0.08, 0.17, 0.92),
			Color(0.32, 0.72, 0.96, 0.55),
			12,
			10.0,
			8.0
		)
		vbox.add_child(h_card)
		var h_hbox := HBoxContainer.new()
		h_hbox.add_theme_constant_override("separation", 8)
		h_card.add_child(h_hbox)
		var h_info := VBoxContainer.new()
		h_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_hbox.add_child(h_info)
		var h_title := UiBuilder.create_label(String(h_def["name"]), 15, Color(0.92, 0.98, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
		h_info.add_child(h_title)
		var h_desc := UiBuilder.create_label(String(h_def["desc"]), 12, Color(0.68, 0.86, 0.98), HORIZONTAL_ALIGNMENT_LEFT)
		h_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h_info.add_child(h_desc)
		var h_btn := UiBuilder.create_primary_button("ВЫБРАТЬ", 44.0, 13)
		h_btn.custom_minimum_size = Vector2(132.0, 44.0)
		h_btn.pressed.connect(func() -> void:
			if _config.buy_or_select_hull(h_id):
				_audio.play_weapon_pickup()
				_glider.apply_hull_skin(_config.selected_hull, _config.get_hull_barrel_roll_cd_mult())
				_max_shields = _config.get_max_shields()
				_shields = mini(_shields, _max_shields)
				_refresh_hangar_ui()
				_refresh_menu_ui()
			else:
				_audio.play_ui_click()
		)
		h_hbox.add_child(h_btn)
		_hull_rows.append({"id": h_id, "name": String(h_def["name"]), "lbl_title": h_title, "btn": h_btn})

	var btn_refund := UiBuilder.create_danger_button("СБРОСИТЬ АПГРЕЙДЫ И ВЕРНУТЬ КР", 44.0, 14)
	btn_refund.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_config.refund_all_upgrades()
		_glider.set_drones_active(false)
		_max_shields = _config.get_max_shields()
		_shields = mini(_shields, _max_shields)
		_refresh_hangar_ui()
		_refresh_menu_ui()
	)
	card_vbox.add_child(btn_refund)

	var btn_close := UiBuilder.create_secondary_button("ЗАКРЫТЬ АНГАР", 48.0, 17)
	btn_close.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_hangar_overlay.visible = false
	)
	card_vbox.add_child(btn_close)


func _refresh_hangar_ui() -> void:
	_lbl_hangar_credits.text = "КВАНТОВЫХ КРИСТАЛЛОВ: %d КР" % _config.quantum_crystals
	for row: Dictionary in _hangar_rows:
		var key_str: String = String(row["key"])
		var lvl: int = _config.get_upgrade_level(key_str)
		var lbl_t := row["lbl_title"] as Label
		var btn_b := row["btn_buy"] as Button
		var pips: Array = row.get("pips", [])
		for p_i: int in range(pips.size()):
			var pip := pips[p_i] as ColorRect
			if pip != null:
				if p_i < lvl:
					pip.color = Color(0.28, 0.98, 0.78, 1.0) if lvl < GameConfig.MAX_UPGRADE_LEVEL else Color(1.0, 0.86, 0.28, 1.0)
				else:
					pip.color = Color(0.10, 0.22, 0.34, 0.70)
		lbl_t.text = "%s [УР. %d/%d]" % [String(row["base_title"]), lvl, GameConfig.MAX_UPGRADE_LEVEL]
		if lvl >= GameConfig.MAX_UPGRADE_LEVEL:
			btn_b.text = "МАКСИМУМ"
			UiBuilder.apply_button_colors(btn_b, Color(0.06, 0.34, 0.26, 0.90), Color(0.28, 0.95, 0.72, 0.85))
		else:
			var cost: int = _config.get_upgrade_cost(key_str)
			btn_b.text = "+1 (%d КР)" % cost
			if _config.can_buy_upgrade(key_str):
				UiBuilder.apply_button_colors(btn_b, Color(0.05, 0.45, 0.68, 0.98), Color(0.38, 0.95, 1.0, 1.0))
			else:
				UiBuilder.apply_button_colors(btn_b, Color(0.06, 0.10, 0.18, 0.85), Color(0.24, 0.42, 0.56, 0.45))

	if not _overclock_row.is_empty():
		var oc_t := _overclock_row["lbl_title"] as Label
		var oc_d := _overclock_row["lbl_desc"] as Label
		var oc_b := _overclock_row["btn_buy"] as Button
		var oc_lvl: int = _config.upg_overclock
		oc_t.text = "ОВЕРКЛОК РЕАКТОРА [УР. %d]" % oc_lvl
		if not _config.is_all_base_maxed():
			oc_d.text = "Откроется после прокачки всех 5 систем до 5/5"
			oc_b.text = "НУЖНО 5/5"
			UiBuilder.apply_button_colors(oc_b, Color(0.08, 0.08, 0.14, 0.85), Color(0.45, 0.38, 0.56, 0.45))
		else:
			var dmg_pct: int = oc_lvl * 6
			var pts_pct: int = oc_lvl * 8
			oc_d.text = "Бонус: +%d%% урон, +%d%% очки (след.: +6%% / +8%%)" % [dmg_pct, pts_pct]
			oc_b.text = "+1 (%d КР)" % _config.get_overclock_cost()
			if _config.can_buy_overclock():
				UiBuilder.apply_button_colors(oc_b, Color(0.56, 0.32, 0.06, 0.98), Color(1.0, 0.84, 0.28, 1.0))
			else:
				UiBuilder.apply_button_colors(oc_b, Color(0.10, 0.08, 0.16, 0.85), Color(0.52, 0.42, 0.24, 0.45))

	for h_row: Dictionary in _hull_rows:
		var h_id: int = int(h_row["id"])
		var h_b := h_row["btn"] as Button
		var is_sel: bool = _config.selected_hull == h_id
		var is_open: bool = _config.is_hull_unlocked(h_id)
		if is_sel:
			h_b.text = "АКТИВЕН"
			UiBuilder.apply_button_colors(h_b, Color(0.06, 0.38, 0.28, 0.94), Color(0.28, 1.0, 0.74, 0.96))
		elif is_open:
			h_b.text = "ВЫБРАТЬ"
			UiBuilder.apply_button_colors(h_b, Color(0.06, 0.32, 0.56, 0.95), Color(0.38, 0.90, 1.0, 0.95))
		else:
			var h_cost: int = _config.get_hull_cost(h_id)
			h_b.text = "%d КР" % h_cost
			if _config.quantum_crystals >= h_cost:
				UiBuilder.apply_button_colors(h_b, Color(0.42, 0.16, 0.58, 0.98), Color(0.88, 0.42, 1.0, 1.0))
			else:
				UiBuilder.apply_button_colors(h_b, Color(0.06, 0.10, 0.18, 0.85), Color(0.24, 0.42, 0.56, 0.45))


func _build_settings_overlay() -> void:
	var modal: Dictionary = UiBuilder.create_modal_overlay(
		_ui_root,
		VIEW_W,
		VIEW_H,
		22.0,
		720.0,
		Color(0.02, 0.05, 0.14, 0.96),
		Color(0.32, 0.92, 1.0, 0.90),
		Color(0.01, 0.02, 0.06, 0.86),
		9
	)
	_settings_overlay = modal["root"]
	_modal_cards.append({"card": modal["card"], "margin_x": 22.0, "card_h": 720.0})
	var card_vbox: VBoxContainer = modal["vbox"]

	card_vbox.add_child(UiBuilder.create_label("НАСТРОЙКИ 3D И АУДИО", 22, Color(0.38, 0.96, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 3))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_vbox.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	# 1. Громкость музыки
	var row_mus: Dictionary = UiBuilder.create_slider_row(
		vbox,
		"ГРОМКОСТЬ МУЗЫКИ",
		"%d%%" % int(round(_config.music_volume * 100.0)),
		0.0,
		1.0,
		0.05,
		_config.music_volume
	)
	var sl_mus := row_mus["slider"] as HSlider
	var lbl_mus := row_mus["label_val"] as Label
	sl_mus.value_changed.connect(func(v: float) -> void:
		_config.music_volume = v
		lbl_mus.text = "%d%%" % int(round(v * 100.0))
		_audio.apply_volumes(_config.music_volume, _config.sfx_volume)
		_config.save_data()
	)

	# 2. Громкость эффектов
	var row_sfx: Dictionary = UiBuilder.create_slider_row(
		vbox,
		"ГРОМКОСТЬ SFX (ПЛАЗМА / ВЗРЫВЫ)",
		"%d%%" % int(round(_config.sfx_volume * 100.0)),
		0.0,
		1.0,
		0.05,
		_config.sfx_volume
	)
	var sl_sfx := row_sfx["slider"] as HSlider
	var lbl_sfx := row_sfx["label_val"] as Label
	sl_sfx.value_changed.connect(func(v: float) -> void:
		_config.sfx_volume = v
		lbl_sfx.text = "%d%%" % int(round(v * 100.0))
		_audio.apply_volumes(_config.music_volume, _config.sfx_volume)
		_config.save_data()
	)

	# 3. Чувствительность 3D-маневрирования
	var row_sens: Dictionary = UiBuilder.create_slider_row(
		vbox,
		"ОТЗЫВЧИВОСТЬ 3D-ГЛАЙДЕРА",
		"%.2fx" % _config.glider_responsiveness,
		0.6,
		1.6,
		0.05,
		_config.glider_responsiveness
	)
	var sl_sens := row_sens["slider"] as HSlider
	var lbl_sens := row_sens["label_val"] as Label
	sl_sens.value_changed.connect(func(v: float) -> void:
		_config.glider_responsiveness = v
		lbl_sens.text = "%.2fx" % v
		_config.save_data()
	)

	# 4. Угол обзора 3D-камеры (FOV)
	var row_fov: Dictionary = UiBuilder.create_slider_row(
		vbox,
		"УГОЛ ОБЗОРА 3D-КАМЕРЫ (FOV)",
		"%d°" % int(round(_config.camera_fov_base)),
		56.0,
		78.0,
		1.0,
		_config.camera_fov_base
	)
	var sl_fov := row_fov["slider"] as HSlider
	var lbl_fov := row_fov["label_val"] as Label
	sl_fov.value_changed.connect(func(v: float) -> void:
		_config.camera_fov_base = v
		lbl_fov.text = "%d°" % int(round(v))
		_config.save_data()
	)

	# 5. Яркость туманности космоса
	var row_bg: Dictionary = UiBuilder.create_slider_row(
		vbox,
		"ЯРКОСТЬ КОСМОСА И ТУМАННОСТИ",
		"%d%%" % int(round(_config.bg_brightness * 100.0)),
		0.35,
		1.30,
		0.05,
		_config.bg_brightness
	)
	var sl_bg := row_bg["slider"] as HSlider
	var lbl_bg := row_bg["label_val"] as Label
	sl_bg.value_changed.connect(func(v: float) -> void:
		_config.bg_brightness = v
		lbl_bg.text = "%d%%" % int(round(v * 100.0))
		_env3d.set_brightness(v)
		_config.save_data()
	)

	# Переключатель качества 3D-эффектов (Glow / MSAA 2x / свет) для экономии батареи и слабых GPU
	var btn_quality := UiBuilder.create_secondary_button(
		"3D-ГРАФИКА (GLOW / MSAA): " + ("МАКС" if _config.high_quality_3d else "ЭКОНОМ"),
		44.0,
		14
	)
	btn_quality.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_config.high_quality_3d = not _config.high_quality_3d
		btn_quality.text = "3D-ГРАФИКА (GLOW / MSAA): " + ("МАКС" if _config.high_quality_3d else "ЭКОНОМ")
		_apply_3d_quality_settings()
		_config.save_data()
	)
	vbox.add_child(btn_quality)

	# Переключатель инверсии оси Y
	var btn_invert_y := UiBuilder.create_secondary_button(
		"ИНВЕРСИЯ ВЕРТИКАЛИ (ОСЬ Y): " + ("ВКЛ" if _config.invert_y_axis else "ВЫКЛ"),
		44.0,
		14
	)
	btn_invert_y.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_config.invert_y_axis = not _config.invert_y_axis
		btn_invert_y.text = "ИНВЕРСИЯ ВЕРТИКАЛИ (ОСЬ Y): " + ("ВКЛ" if _config.invert_y_axis else "ВЫКЛ")
		_config.save_data()
	)
	vbox.add_child(btn_invert_y)

	var btn_swipe := UiBuilder.create_secondary_button(
		"УПРАВЛЕНИЕ: " + ("СВАЙП" if _config.swipe_control_enabled else "КАСАНИЕ"),
		44.0,
		14
	)
	btn_swipe.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_config.swipe_control_enabled = not _config.swipe_control_enabled
		btn_swipe.text = "УПРАВЛЕНИЕ: " + ("СВАЙП" if _config.swipe_control_enabled else "КАСАНИЕ")
		_config.save_data()
	)
	vbox.add_child(btn_swipe)

	var btn_vibro := UiBuilder.create_secondary_button(
		"ВИБРООТКЛИК: " + ("ВКЛ" if _config.vibration_enabled else "ВЫКЛ"),
		44.0,
		14
	)
	btn_vibro.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_config.vibration_enabled = not _config.vibration_enabled
		btn_vibro.text = "ВИБРООТКЛИК: " + ("ВКЛ" if _config.vibration_enabled else "ВЫКЛ")
		if _config.vibration_enabled and DisplayServer.get_name() != "headless":
			Input.vibrate_handheld(40)
		_config.save_data()
	)
	vbox.add_child(btn_vibro)

	var btn_close := UiBuilder.create_primary_button("СОХРАНИТЬ И ЗАКРЫТЬ", 52.0, 18)
	btn_close.pressed.connect(func() -> void:
		_audio.play_ui_click()
		_settings_overlay.visible = false
	)
	card_vbox.add_child(btn_close)
