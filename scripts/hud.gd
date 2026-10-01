extends CanvasLayer
## Offline lobby and independently owned touch inputs (move + look + fire).
signal start_match(mode: String, map_id: int)
signal back_to_menu

const Radar = preload("res://scripts/radar.gd")
const LOADOUT_IDS = ["rifle", "smg", "marksman"]
const LOADOUT_LABELS = {"rifle": "Rifle", "smg": "SMG", "marksman": "Marksman"}

const POSITIONS = {
	"move": [0.14, 0.75], "fire": [0.88, 0.63], "ads": [0.75, 0.57],
	"jump": [0.89, 0.84], "reload": [0.74, 0.83],
}
const CAPTIONS = {"move": "MOVE", "fire": "FIRE", "ads": "ADS", "jump": "JUMP", "reload": "RELOAD"}

var move_vector: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var firing: bool = false
var aiming: bool = false
var jump_requested: bool = false
var reload_requested: bool = false
var settings: RefCounted
var root: Control
var lobby: PanelContainer
var preferences: PanelContainer
var match_ui: Control
var result_panel: PanelContainer
var editor_bar: PanelContainer
var status: Label
var result_text: Label
var crosshair: Label
var menu: Button
var map_picker: OptionButton
var loadout_picker: OptionButton
var radar: Control
var compass: Label
var vitals: PanelContainer
var health_label: Label
var health_bar: ProgressBar
var weapon_label: Label
var ammo_label: Label
var reserve_label: Label
var reload_bar: ProgressBar
var rating_label: Label
var hit_marker: Label
var damage_overlay: Panel
var damage_label: Label
var hit_marker_time: float = 0.0
var damage_time: float = 0.0
var pads: Dictionary = {}
var touches: Dictionary = {}
var screen: String = "lobby"
var layout_before_edit: Dictionary = {}
var mouse_drag: String = ""

func configure(prefs: RefCounted) -> void:
	settings = prefs
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new()
	theme.default_font_size = 22
	root.theme = theme
	_build_lobby()
	_build_preferences()
	_build_match()
	_build_editor()
	_build_result()
	get_viewport().size_changed.connect(_layout_pads)
	show_lobby()

func _style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	return style

func _panel(left: float, top: float, right: float, bottom: float) -> PanelContainer:
	var panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.07, 0.1, 0.96)))
	return panel

func _column(parent: Node) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	parent.add_child(column)
	return column

func _label(parent: Node, text: String, font_size: int = 22) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(120, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_lobby() -> void:
	lobby = _panel(0.14, 0.06, 0.86, 0.94)
	var scroll = ScrollContainer.new()
	lobby.add_child(scroll)
	var column = _column(scroll)
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(column, "ALMARAKAH", 36)
	_label(column, "OFFLINE TRAINING • EARLY PROTOTYPE", 18)
	var description = _label(column, "50-player BR or tactical 4v4 CS. All matches run locally with offline bots; ranked practice uses a device-only rating and is not online matchmaking.", 18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var choices = HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	column.add_child(choices)
	var maps = _column(choices)
	maps.add_theme_constant_override("separation", 4)
	maps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(maps, "Choose a map", 18)
	map_picker = OptionButton.new()
	map_picker.custom_minimum_size.y = 52
	map_picker.add_theme_font_size_override("font_size", 18)
	map_picker.add_item("Qamar Dunes — desert settlement", 0)
	map_picker.add_item("Wadi Highlands — green outpost", 1)
	maps.add_child(map_picker)
	var loadouts = _column(choices)
	loadouts.add_theme_constant_override("separation", 4)
	loadouts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(loadouts, "Offline loadout", 18)
	loadout_picker = OptionButton.new()
	loadout_picker.custom_minimum_size = Vector2(190, 52)
	for weapon_id in LOADOUT_IDS:
		loadout_picker.add_item(LOADOUT_LABELS[weapon_id])
	loadout_picker.item_selected.connect(_select_loadout)
	loadouts.add_child(loadout_picker)
	_button(column, "BR CLASSIC · 50 players", func(): start_match.emit("br_classic", map_picker.selected))
	_button(column, "BR RANKED · 50-player practice", func(): start_match.emit("br_ranked", map_picker.selected))
	_button(column, "CS CLASSIC · 4v4", func(): start_match.emit("cs_classic", map_picker.selected))
	_button(column, "CS RANKED · 4v4 practice", func(): start_match.emit("cs_ranked", map_picker.selected))
	rating_label = _label(column, "", 16)
	rating_label.add_theme_color_override("font_color", Color("9ac7c9"))
	_button(column, "Settings & HUD", show_settings)
	var help = _label(column, "Touch: move on the left, swipe right to look. Hold FIRE.\nDesktop: WASD · mouse · Space · R · Esc to release mouse.", 18)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _select_loadout(index: int) -> void:
	if index < 0 or index >= LOADOUT_IDS.size():
		return
	settings.data.weapon_id = LOADOUT_IDS[index]
	settings.save()

func _build_preferences() -> void:
	preferences = _panel(0.15, 0.04, 0.85, 0.96)
	var scroll = ScrollContainer.new()
	preferences.add_child(scroll)
	var column = _column(scroll)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(column, "SETTINGS & HUD", 32)
	_slider(column, "Camera sensitivity", "camera_sensitivity", 0.2, 3.0)
	_slider(column, "ADS sensitivity", "ads_sensitivity", 0.2, 3.0)
	_slider(column, "HUD scale", "hud_scale", 0.7, 1.5)
	_slider(column, "HUD opacity", "hud_opacity", 0.3, 1.0)
	var assist = CheckButton.new()
	assist.text = "Gentle aim assist while aiming (ADS)"
	assist.button_pressed = bool(settings.data.aim_assist)
	assist.toggled.connect(func(enabled: bool): settings.data.aim_assist = enabled)
	column.add_child(assist)
	_button(column, "Edit touch layout", show_editor)
	_button(column, "Save & return to lobby", func():
		settings.save()
		show_lobby()
	)

func _slider(parent: Node, caption: String, key: String, minimum: float, maximum: float) -> void:
	var label = _label(parent, "%s: %.2f" % [caption, float(settings.data[key])])
	var slider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = float(settings.data[key])
	slider.custom_minimum_size.y = 32
	parent.add_child(slider)
	slider.value_changed.connect(func(value: float):
		settings.data[key] = value
		label.text = "%s: %.2f" % [caption, value]
		_layout_pads()
	)

func _build_match() -> void:
	match_ui = Control.new()
	root.add_child(match_ui)
	match_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay = Panel.new()
	match_ui.add_child(damage_overlay)
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var damage_style = StyleBoxFlat.new()
	damage_style.bg_color = Color(0.8, 0.03, 0.02, 0.07)
	damage_style.border_color = Color(1, 0.25, 0.18, 0.75)
	damage_style.set_border_width_all(8)
	damage_overlay.add_theme_stylebox_override("panel", damage_style)
	damage_overlay.hide()
	radar = Radar.new()
	match_ui.add_child(radar)
	radar.position = Vector2(24, 20)
	radar.size = Vector2(188, 212)
	status = _label(match_ui, "", 18)
	status.position = Vector2(236, 20)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	compass = _label(match_ui, "N   000°", 24)
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass.offset_left = -130
	compass.offset_right = 130
	compass.offset_top = 104
	compass.offset_bottom = 140
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.add_theme_color_override("font_shadow_color", Color.BLACK)
	compass.add_theme_constant_override("shadow_offset_x", 2)
	compass.add_theme_constant_override("shadow_offset_y", 2)
	damage_label = _label(match_ui, "TAKING DAMAGE", 18)
	damage_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	damage_label.offset_left = -140
	damage_label.offset_right = 140
	damage_label.offset_top = 146
	damage_label.offset_bottom = 172
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.add_theme_color_override("font_color", Color("ff9279"))
	damage_label.hide()
	_build_vitals()
	menu = _button(match_ui, "MENU", func():
		reset_inputs()
		back_to_menu.emit()
	)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -148
	menu.offset_right = -24
	menu.offset_top = 20
	menu.offset_bottom = 72
	crosshair = _label(match_ui, "+", 32)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -12
	crosshair.offset_right = 12
	crosshair.offset_top = -22
	crosshair.offset_bottom = 22
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_marker = _label(match_ui, "×", 48)
	hit_marker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hit_marker.offset_left = -32
	hit_marker.offset_right = 32
	hit_marker.offset_top = -36
	hit_marker.offset_bottom = 36
	hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hit_marker.add_theme_color_override("font_shadow_color", Color.BLACK)
	hit_marker.add_theme_constant_override("shadow_offset_x", 1)
	hit_marker.add_theme_constant_override("shadow_offset_y", 1)
	hit_marker.hide()
	for key in POSITIONS:
		var pad = PanelContainer.new()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_theme_stylebox_override("panel", _style(Color(0.05, 0.13, 0.18, 0.85)))
		match_ui.add_child(pad)
		var caption = _label(pad, CAPTIONS[key], 20)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pads[key] = pad

func _build_vitals() -> void:
	vitals = PanelContainer.new()
	match_ui.add_child(vitals)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	vitals.offset_left = -186
	vitals.offset_right = 186
	vitals.offset_top = -138
	vitals.offset_bottom = -20
	var style = _style(Color(0.035, 0.07, 0.1, 0.88))
	style.set_content_margin_all(12)
	vitals.add_theme_stylebox_override("panel", style)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	vitals.add_child(row)
	var health = _column(row)
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health.custom_minimum_size.x = 112
	health.add_theme_constant_override("separation", 3)
	_label(health, "HEALTH", 14)
	health_label = _label(health, "HP 100", 26)
	health_bar = _bar(health, Color("66e1b3"), 8)
	var ammunition = _column(row)
	ammunition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammunition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammunition.add_theme_constant_override("separation", 2)
	weapon_label = _label(ammunition, "RIFLE", 16)
	ammo_label = _label(ammunition, "30 / 30", 28)
	reserve_label = _label(ammunition, "RES 180", 14)
	reload_bar = _bar(ammunition, Color("f6c96c"), 5)
	reload_bar.hide()

func _bar(parent: Node, color: Color, height: float) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.value = 100
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.12, 0.18, 0.21)
	background.set_corner_radius_all(3)
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _build_editor() -> void:
	editor_bar = _panel(0.03, 0.02, 0.97, 0.16)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	editor_bar.add_child(row)
	_label(row, "Drag controls to move", 20)
	_button(row, "Reset", func():
		settings.data.hud_positions = {}
		_layout_pads()
	)
	_button(row, "Cancel", func():
		settings.data.hud_positions = layout_before_edit.duplicate(true)
		show_settings()
	)
	_button(row, "Save layout", func():
		settings.save()
		show_settings()
	)

func _build_result() -> void:
	result_panel = _panel(0.15, 0.25, 0.85, 0.75)
	var column = _column(result_panel)
	result_text = _label(column, "", 28)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(column, "Return to lobby", func(): back_to_menu.emit())

func _show(next: String) -> void:
	reset_inputs()
	_clear_feedback()
	screen = next
	lobby.visible = next == "lobby"
	preferences.visible = next == "settings"
	match_ui.visible = next in ["match", "editor"]
	editor_bar.visible = next == "editor"
	result_panel.visible = next == "result"
	status.visible = next == "match"
	menu.visible = next == "match"
	crosshair.visible = next == "match"
	radar.visible = next == "match"
	compass.visible = next == "match"
	vitals.visible = next == "match"
	_layout_pads()

func show_lobby() -> void:
	var selected: int = LOADOUT_IDS.find(String(settings.data.get("weapon_id", "rifle")))
	rating_label.text = "Local ratings  •  BR %d   CS %d" % [int(settings.data.get("br_rating", 1000)), int(settings.data.get("cs_rating", 1000))]
	loadout_picker.select(maxi(0, selected))
	_show("lobby")

func show_settings() -> void:
	_show("settings")

func show_match() -> void:
	_show("match")

func show_editor() -> void:
	layout_before_edit = settings.data.hud_positions.duplicate(true)
	_show("editor")

func show_result(message: String) -> void:
	result_text.text = message
	_show("result")

func update_status(data: Dictionary) -> void:
	var mode_text: String = String(data.get("mode", "OFFLINE TRAINING"))
	var eliminated: bool = bool(data.get("eliminated", false))
	var reloading: bool = bool(data.get("reloading", false))
	status.text = "%s   |   Alive %d   |   Eliminations %d" % [mode_text, int(data.get("alive", 0)), int(data.get("kills", 0))]
	status.text += "\n"
	if mode_text.begins_with("CS"):
		status.text += "Round %d · %s   |   " % [int(data.get("round", 1)), String(data.get("score", "0 : 0"))]
	status.text += String(data.get("zone", ""))
	var health: float = clampf(float(data.get("health", 100)), 0, 100)
	health_label.text = "HP %d" % ceili(health)
	health_bar.value = health
	var health_color: Color = Color("ff9279") if health <= 30 else Color("66e1b3")
	health_label.add_theme_color_override("font_color", health_color)
	health_bar.get_theme_stylebox("fill").bg_color = health_color
	var weapon: String = String(data.get("weapon", settings.data.get("weapon_id", "rifle")))
	weapon_label.text = String(LOADOUT_LABELS.get(weapon, weapon)).to_upper()
	var magazine_size: int = maxi(1, int(data.get("magazine_size", 30)))
	var ammo: int = maxi(0, int(data.get("ammo", 0)))
	ammo_label.text = "%02d / %d" % [ammo, magazine_size]
	ammo_label.add_theme_color_override("font_color", Color("f6c96c") if ammo <= magazine_size / 4 else Color.WHITE)
	reserve_label.text = "RES %d" % maxi(0, int(data.get("reserve", 0)))
	reload_bar.visible = reloading
	reload_bar.value = clampf(float(data.get("reload_progress", 0.0)), 0, 1) * 100.0
	if reloading:
		reserve_label.text += " · RELOAD"
		if data.has("reload_progress"):
			reserve_label.text += " %d%%" % roundi(reload_bar.value)
	elif ammo == 0:
		reserve_label.text += " · EMPTY"
	if eliminated:
		status.text += "\nELIMINATED · Spectating"
		reset_inputs()
		hit_marker.hide()
		hit_marker_time = 0.0
	crosshair.visible = screen == "match" and not eliminated

func update_radar(player_position: Vector3, player_yaw: float, zone_radius: float, arena_extent: float, allies: Array[Vector3], is_cs: bool) -> void:
	radar.update_radar(player_position, player_yaw, zone_radius, arena_extent, allies, is_cs)
	# Godot's forward is -Z; positive yaw turns west, not east.
	var heading: float = fposmod(-rad_to_deg(player_yaw), 360.0)
	var cardinals = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	compass.text = "%s   %03d°" % [cardinals[roundi(heading / 45.0) % 8], roundi(heading) % 360]

func show_hit_marker(eliminated: bool = false) -> void:
	if screen != "match" or not crosshair.visible:
		return
	hit_marker_time = 0.4 if eliminated else 0.2
	hit_marker.modulate = Color("ffc96c") if eliminated else Color.WHITE
	hit_marker.show()
	set_process(true)

func show_damage_indicator() -> void:
	if screen != "match":
		return
	damage_time = 0.5
	damage_overlay.modulate.a = 1.0
	damage_label.modulate.a = 1.0
	damage_overlay.show()
	damage_label.show()
	set_process(true)

func _clear_feedback() -> void:
	hit_marker_time = 0.0
	damage_time = 0.0
	hit_marker.hide()
	damage_overlay.hide()
	damage_label.hide()
	set_process(false)

func _process(delta: float) -> void:
	hit_marker_time = maxf(0.0, hit_marker_time - delta)
	damage_time = maxf(0.0, damage_time - delta)
	hit_marker.visible = screen == "match" and hit_marker_time > 0.0
	hit_marker.modulate.a = minf(1.0, hit_marker_time / 0.1)
	damage_overlay.visible = screen == "match" and damage_time > 0.0
	damage_label.visible = damage_overlay.visible
	damage_overlay.modulate.a = minf(1.0, damage_time / 0.3)
	damage_label.modulate.a = damage_overlay.modulate.a
	if hit_marker_time <= 0.0 and damage_time <= 0.0:
		set_process(false)

func _layout_pads() -> void:
	if not is_instance_valid(root) or settings == null:
		return
	var area: Vector2 = root.size
	if is_instance_valid(status):
		status.size.x = maxf(200, area.x - 412)
	for key in pads:
		var pad: PanelContainer = pads[key]
		var point: Array = settings.data.hud_positions.get(key, POSITIONS[key])
		var side: float = (150.0 if key == "move" else 94.0) * float(settings.data.hud_scale)
		pad.custom_minimum_size = Vector2.ONE * side
		pad.size = Vector2.ONE * side
		var desired: Vector2 = Vector2(float(point[0]), float(point[1])) * area - pad.size * 0.5
		pad.position = Vector2(clampf(desired.x, 8, maxf(8, area.x - side - 8)), clampf(desired.y, 120, maxf(120, area.y - side - 8)))
		pad.modulate.a = float(settings.data.hud_opacity)

func reset_inputs() -> void:
	move_vector = Vector2.ZERO
	look_delta = Vector2.ZERO
	firing = false
	aiming = false
	jump_requested = false
	reload_requested = false
	touches.clear()
	mouse_drag = ""
	_refresh_aim()

func _refresh_aim() -> void:
	if pads.has("ads"):
		pads.ads.get_child(0).text = "ADS ON" if aiming else "ADS"

func _pad_at(point: Vector2) -> String:
	# Reverse drawing order makes hit testing agree with overlapping controls.
	var keys: Array = pads.keys()
	keys.reverse()
	for key in keys:
		if pads[key].get_global_rect().has_point(point):
			return key
	return ""

func _touch_start(index: int, point: Vector2) -> bool:
	if screen not in ["match", "editor"]:
		return false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if screen == "match" and menu.get_global_rect().has_point(point):
		return false
	if screen == "editor" and editor_bar.get_global_rect().has_point(point):
		return false
	var action: String = _pad_at(point)
	if screen == "editor":
		if not action.is_empty():
			touches[index] = "edit:" + action
		return not action.is_empty()
	if action.is_empty() and point.x > root.size.x * 0.45:
		action = "look"
	if action.is_empty():
		return false
	if action in touches.values():
		return true
	touches[index] = action
	match action:
		"move": _move_stick(point)
		"fire": firing = true
		"ads":
			aiming = not aiming
			_refresh_aim()
		"jump": jump_requested = true
		"reload": reload_requested = true
	return true

func _touch_end(index: int) -> bool:
	if not touches.has(index):
		return false
	match touches[index]:
		"move": move_vector = Vector2.ZERO
		"fire": firing = false
	touches.erase(index)
	return true

func _move_stick(point: Vector2) -> void:
	var pad: PanelContainer = pads.move
	move_vector = ((point - pad.get_global_rect().get_center()) / (pad.size.x * 0.38)).limit_length()

func _drag_pad(key: String, point: Vector2) -> void:
	var normalized: Vector2 = point / root.size.max(Vector2.ONE)
	settings.data.hud_positions[key] = [clampf(normalized.x, 0.05, 0.95), clampf(normalized.y, 0.15, 0.92)]
	_layout_pads()

func _input(event: InputEvent) -> void:
	var handled: bool = false
	if event is InputEventScreenTouch:
		handled = _touch_start(event.index, event.position) if event.pressed and not event.canceled else _touch_end(event.index)
	elif event is InputEventScreenDrag and touches.has(event.index):
		var action: String = touches[event.index]
		if action == "move":
			_move_stick(event.position)
		elif action == "look":
			look_delta += event.relative
		elif action.begins_with("edit:"):
			_drag_pad(action.trim_prefix("edit:"), event.position)
		handled = true
	elif screen == "editor" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not editor_bar.get_global_rect().has_point(event.position):
			mouse_drag = _pad_at(event.position)
			handled = not mouse_drag.is_empty()
		elif not event.pressed:
			handled = not mouse_drag.is_empty()
			mouse_drag = ""
	elif screen == "editor" and event is InputEventMouseMotion and not mouse_drag.is_empty():
		_drag_pad(mouse_drag, event.position)
		handled = true
	if handled:
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_inputs()
