extends Node

# ---------------------------------------------------------------------------
# GameUI — pause menu + settings page.
# No game pause; world keeps running while UI is open.
# Call init() once after adding to the scene tree.
# ---------------------------------------------------------------------------

const SETTINGS_SAVE_PATH : String = "user://camera_settings.tres"

var cam        : CameraSettings
var camera_rig : Node3D   # typed as Node3D; duck-typed access to rig properties

var pause_open         : bool = false
var settings_page_open : bool = false

var pause_layer      : CanvasLayer
var pause_panel      : PanelContainer
var pause_resume_btn : Button

var settings_layer       : CanvasLayer
var settings_panel       : PanelContainer
var settings_solid_chk   : CheckBox
var settings_opt_scroll  : ScrollContainer
var settings_first_focus : Control


func init(p_cam: CameraSettings, p_camera_rig: Node3D) -> void:
	cam        = p_cam
	camera_rig = p_camera_rig
	_build_pause_menu()
	_build_settings_page()


# ---------------------------------------------------------------------------
# PUBLIC INTERFACE — called by main.gd
# ---------------------------------------------------------------------------

func any_ui_open() -> bool:
	return pause_open or settings_page_open


func is_mouse_over_panel() -> bool:
	var mp : Vector2 = get_viewport().get_mouse_position()
	if pause_open      and pause_panel.get_global_rect().has_point(mp):
		return true
	if settings_page_open and settings_panel.get_global_rect().has_point(mp):
		return true
	return false


func on_escape() -> void:
	if settings_page_open:
		_close_settings_to_pause()
	elif pause_open:
		_close_pause()
	else:
		_open_pause()


# ---------------------------------------------------------------------------
# PAUSE MENU FLOW
# ---------------------------------------------------------------------------

func _open_pause() -> void:
	pause_layer.visible = true
	pause_open          = true
	pause_resume_btn.grab_focus()


func _close_pause() -> void:
	pause_layer.visible = false
	pause_open          = false


func _close_settings_to_pause() -> void:
	ResourceSaver.save(cam, SETTINGS_SAVE_PATH)
	settings_layer.visible = false
	settings_page_open     = false
	pause_layer.visible    = true
	pause_open             = true
	pause_resume_btn.grab_focus()


func _on_pause_resume() -> void:
	_close_pause()


func _on_pause_settings() -> void:
	_close_pause()
	settings_layer.visible = true
	settings_page_open     = true
	if settings_first_focus:
		settings_first_focus.grab_focus()


func _on_pause_exit() -> void:
	ResourceSaver.save(cam, SETTINGS_SAVE_PATH)
	get_tree().quit()


# ---------------------------------------------------------------------------
# BUILD — PAUSE MENU
# ---------------------------------------------------------------------------

func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.visible = false
	add_child(pause_layer)

	pause_panel = PanelContainer.new()
	pause_panel.anchor_left   = 0.5
	pause_panel.anchor_right  = 0.5
	pause_panel.anchor_top    = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.offset_left   = -150.0
	pause_panel.offset_right  =  150.0
	pause_panel.offset_top    = -100.0
	pause_panel.offset_bottom =  100.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	pause_panel.add_theme_stylebox_override("panel", style)
	pause_layer.add_child(pause_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    22)
	margin.add_theme_constant_override("margin_bottom", 22)
	pause_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "MENU"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	pause_resume_btn = Button.new()
	pause_resume_btn.text = "Resume"
	pause_resume_btn.add_theme_font_size_override("font_size", 16)
	pause_resume_btn.pressed.connect(_on_pause_resume)
	vbox.add_child(pause_resume_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.add_theme_font_size_override("font_size", 16)
	settings_btn.pressed.connect(_on_pause_settings)
	vbox.add_child(settings_btn)

	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.add_theme_font_size_override("font_size", 16)
	exit_btn.pressed.connect(_on_pause_exit)
	vbox.add_child(exit_btn)

	# Focus chain: Resume → Settings → Exit (Tab / Down)
	pause_resume_btn.focus_neighbor_bottom   = settings_btn.get_path()
	pause_resume_btn.focus_next              = settings_btn.get_path()
	settings_btn.focus_neighbor_top          = pause_resume_btn.get_path()
	settings_btn.focus_neighbor_bottom       = exit_btn.get_path()
	settings_btn.focus_next                  = exit_btn.get_path()
	exit_btn.focus_neighbor_top              = settings_btn.get_path()
	exit_btn.focus_neighbor_bottom           = exit_btn.get_path()   # block past last


# ---------------------------------------------------------------------------
# BUILD — SETTINGS PAGE
# ---------------------------------------------------------------------------

func _build_settings_page() -> void:
	settings_layer = CanvasLayer.new()
	settings_layer.visible = false
	add_child(settings_layer)

	settings_panel = PanelContainer.new()
	settings_panel.anchor_left   = 0.25
	settings_panel.anchor_right  = 0.75
	settings_panel.anchor_top    = 0.25
	settings_panel.anchor_bottom = 0.75
	settings_panel.offset_left   = 0.0
	settings_panel.offset_right  = 0.0
	settings_panel.offset_top    = 0.0
	settings_panel.offset_bottom = 0.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.08, 0.82)
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	settings_layer.add_child(settings_panel)

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left",   40)
	root_margin.add_theme_constant_override("margin_right",  40)
	root_margin.add_theme_constant_override("margin_top",    30)
	root_margin.add_theme_constant_override("margin_bottom", 30)
	settings_panel.add_child(root_margin)

	var root_vbox := VBoxContainer.new()
	root_margin.add_child(root_vbox)

	# Title bar: ← Back | CAMERA SETTINGS (centered) | Solid □ | Default
	var title_bar := HBoxContainer.new()
	root_vbox.add_child(title_bar)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.pressed.connect(_close_settings_to_pause)
	title_bar.add_child(back_btn)

	var title_lbl := Label.new()
	title_lbl.text = "CAMERA SETTINGS"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_lbl)

	settings_solid_chk = CheckBox.new()
	settings_solid_chk.text = "Solid"
	settings_solid_chk.button_pressed = false
	settings_solid_chk.toggled.connect(func(on: bool) -> void:
		panel_style.bg_color.a = 1.0 if on else 0.82)
	title_bar.add_child(settings_solid_chk)

	var default_btn := Button.new()
	default_btn.text = "Default"
	default_btn.pressed.connect(func() -> void:
		cam.outdoor_zoom_step  = 3
		cam.outdoor_pitch      = -30.0
		cam.indoor_zoom_step   = 1
		cam.indoor_pitch       = -20.0
		cam.mouse_zoom_enabled  = true
		cam.mouse_pitch_enabled = true
		cam.invert_orbit = false
		cam.invert_pitch = false
		cam.invert_zoom  = false
		cam.orbit_sens      = 0.4
		cam.pitch_sens      = 0.13
		cam.zoom_sens       = 0.12
		cam.orbit_key_speed = 90.0
		cam.qe_orbit_enabled = true
		cam.use_wasd         = true
		cam.use_arrows       = true
		cam.player_fade_alpha = 38
		camera_rig.apply_active_preset()
		settings_layer.queue_free()
		_build_settings_page()
		settings_layer.visible = true
		if settings_first_focus:
			settings_first_focus.grab_focus())
	title_bar.add_child(default_btn)

	root_vbox.add_child(_make_separator())

	# Flat scroll list
	var opt_scroll := ScrollContainer.new()
	opt_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	settings_opt_scroll = opt_scroll
	root_vbox.add_child(opt_scroll)

	var opt_margin := MarginContainer.new()
	opt_margin.add_theme_constant_override("margin_left",  16)
	opt_margin.add_theme_constant_override("margin_right", 16)
	opt_margin.add_theme_constant_override("margin_top",   8)
	opt_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_scroll.add_child(opt_margin)

	var opt_vbox := VBoxContainer.new()
	opt_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_vbox.add_theme_constant_override("separation", 14)
	opt_margin.add_child(opt_vbox)

	# --- PRESETS ---
	_build_section(opt_vbox, "PRESETS")
	settings_first_focus = _build_zoom_pitch_preset(opt_vbox, "Outdoor",
		cam.outdoor_zoom_step, cam.outdoor_pitch,
		func(z: int) -> void:
			cam.outdoor_zoom_step = z
			camera_rig.apply_outdoor_preset(z, cam.outdoor_pitch),
		func(p: float) -> void:
			cam.outdoor_pitch = p
			camera_rig.apply_outdoor_preset(cam.outdoor_zoom_step, p))
	_build_zoom_pitch_preset(opt_vbox, "Indoor",
		cam.indoor_zoom_step, cam.indoor_pitch,
		func(z: int) -> void:
			cam.indoor_zoom_step = z
			camera_rig.apply_indoor_preset(z, cam.indoor_pitch),
		func(p: float) -> void:
			cam.indoor_pitch = p
			camera_rig.apply_indoor_preset(cam.indoor_zoom_step, p))

	# --- MOUSE ---
	_build_section(opt_vbox, "MOUSE")
	_build_checkbox(opt_vbox, "Enable mouse zoom",  cam.mouse_zoom_enabled,
		func(v: bool) -> void: cam.mouse_zoom_enabled  = v)
	_build_checkbox(opt_vbox, "Enable mouse pitch", cam.mouse_pitch_enabled,
		func(v: bool) -> void: cam.mouse_pitch_enabled = v)
	_build_checkbox(opt_vbox, "Invert orbit", cam.invert_orbit,
		func(v: bool) -> void: cam.invert_orbit = v)
	_build_checkbox(opt_vbox, "Invert pitch", cam.invert_pitch,
		func(v: bool) -> void: cam.invert_pitch = v)
	_build_checkbox(opt_vbox, "Invert zoom",  cam.invert_zoom,
		func(v: bool) -> void: cam.invert_zoom  = v)
	_build_slider(opt_vbox, "Orbit sensitivity",  cam.orbit_sens, 0.05, 0.5,
		func(v: float) -> void: cam.orbit_sens = v)
	_build_slider(opt_vbox, "Pitch sensitivity",  cam.pitch_sens, 0.10, 0.15,
		func(v: float) -> void: cam.pitch_sens = v)
	_build_slider(opt_vbox, "Zoom sensitivity",   cam.zoom_sens, 0.01, 0.3,
		func(v: float) -> void: cam.zoom_sens = v)

	# --- KEYBOARD ---
	_build_section(opt_vbox, "KEYBOARD")
	_build_checkbox(opt_vbox, "Q/E orbit enabled", cam.qe_orbit_enabled,
		func(v: bool) -> void: cam.qe_orbit_enabled = v)
	_build_slider(opt_vbox, "Q/E orbit speed (°/s)", cam.orbit_key_speed, 20.0, 180.0,
		func(v: float) -> void: cam.orbit_key_speed = v)
	_build_section(opt_vbox, "Movement keys")
	_build_radio_group(opt_vbox,
		["WASD only", "Arrows only", "Both"] as Array[String],
		(0 if (cam.use_wasd and not cam.use_arrows) else (1 if (cam.use_arrows and not cam.use_wasd) else 2)),
		func(idx: int) -> void:
			cam.use_wasd   = idx != 1
			cam.use_arrows = idx != 0)

	# --- VISUAL ---
	_build_section(opt_vbox, "VISUAL")
	_build_int_slider(opt_vbox, "Player fade opacity (0-255)", cam.player_fade_alpha, 0, 255,
		func(v: int) -> void: cam.player_fade_alpha = v)


# ---------------------------------------------------------------------------
# WIDGET HELPERS
# ---------------------------------------------------------------------------

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 12)
	return sep


func _build_section(parent: VBoxContainer, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.6, 0.8, 1.0, 1.0)
	parent.add_child(lbl)
	parent.add_child(HSeparator.new())


func _build_checkbox(parent: VBoxContainer, label: String, initial: bool,
		on_change: Callable) -> void:
	var chk := CheckBox.new()
	chk.text = label
	chk.button_pressed = initial
	chk.add_theme_font_size_override("font_size", 15)
	chk.toggled.connect(on_change)
	chk.focus_entered.connect(func() -> void: settings_opt_scroll.ensure_control_visible(chk))
	parent.add_child(chk)


func _build_slider(parent: VBoxContainer, label: String, initial: float,
		min_val: float, max_val: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 240
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step      = (max_val - min_val) / 100.0
	slider.value     = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val_lbl := Label.new()
	val_lbl.custom_minimum_size.x = 44
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.text = "%.2f" % initial
	slider.focus_entered.connect(func() -> void: settings_opt_scroll.ensure_control_visible(slider))
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		val_lbl.text = "%.2f" % v)
	row.add_child(slider)
	row.add_child(val_lbl)


func _build_int_slider(parent: VBoxContainer, label: String, initial: int,
		min_val: int, max_val: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 240
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step      = 1
	slider.value     = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val_lbl := Label.new()
	val_lbl.custom_minimum_size.x = 44
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.text = str(initial)
	slider.focus_entered.connect(func() -> void: settings_opt_scroll.ensure_control_visible(slider))
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(int(v))
		val_lbl.text = str(int(v)))
	row.add_child(slider)
	row.add_child(val_lbl)


func _build_zoom_pitch_preset(parent: VBoxContainer, preset_name: String,
		init_zoom: int, init_pitch: float,
		on_zoom: Callable, on_pitch: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var name_lbl := Label.new()
	name_lbl.text = preset_name
	name_lbl.custom_minimum_size.x = 80
	name_lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(name_lbl)
	var zoom_lbl := Label.new()
	zoom_lbl.text = "Zoom %d" % init_zoom
	zoom_lbl.add_theme_font_size_override("font_size", 14)
	zoom_lbl.custom_minimum_size.x = 72
	var zoom_sl := HSlider.new()
	zoom_sl.min_value = 0
	zoom_sl.max_value = CameraSettings.ZOOM_STEPS - 1
	zoom_sl.step      = 1
	zoom_sl.value     = init_zoom
	zoom_sl.focus_mode = Control.FOCUS_ALL
	zoom_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_sl.focus_entered.connect(func() -> void: settings_opt_scroll.ensure_control_visible(zoom_sl))
	zoom_sl.value_changed.connect(func(v: float) -> void:
		on_zoom.call(int(v))
		zoom_lbl.text = "Zoom %d" % int(v))
	row.add_child(zoom_lbl)
	row.add_child(zoom_sl)
	var pitch_lbl := Label.new()
	pitch_lbl.text = "Pitch %.0f°" % init_pitch
	pitch_lbl.add_theme_font_size_override("font_size", 14)
	pitch_lbl.custom_minimum_size.x = 90
	var pitch_sl := HSlider.new()
	pitch_sl.min_value = CameraSettings.PITCH_MIN
	pitch_sl.max_value = CameraSettings.PITCH_MAX
	pitch_sl.step      = CameraSettings.PITCH_STEP
	pitch_sl.value     = init_pitch
	pitch_sl.focus_mode = Control.FOCUS_ALL
	pitch_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch_sl.focus_entered.connect(func() -> void: settings_opt_scroll.ensure_control_visible(pitch_sl))
	pitch_sl.value_changed.connect(func(v: float) -> void:
		on_pitch.call(v)
		pitch_lbl.text = "Pitch %.0f°" % v)
	row.add_child(pitch_lbl)
	row.add_child(pitch_sl)
	return zoom_sl


func _build_radio_group(parent: VBoxContainer, labels: Array[String],
		initial: int, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)
	var buttons : Array[CheckBox] = []
	for i : int in range(labels.size()):
		var btn := CheckBox.new()
		btn.text = labels[i]
		btn.button_pressed = (i == initial)
		btn.add_theme_font_size_override("font_size", 15)
		var idx : int = i
		btn.focus_entered.connect(func() -> void: settings_opt_scroll.ensure_control_visible(btn))
		btn.toggled.connect(func(on: bool) -> void:
			if not on:
				return
			for j : int in range(buttons.size()):
				buttons[j].set_pressed_no_signal(j == idx)
			on_change.call(idx))
		row.add_child(btn)
		buttons.append(btn)
