extends Node2D

const Profile = preload("res://game/profile.gd")
const Survival = preload("res://game/survival.gd")
const DuskCycle = preload("res://game/dusk_cycle.gd")
const SaveStore = preload("res://game/save_store.gd")
const SAVE_PATH := "user://monster_dusk_v1.json"
const BACKUP_PATH := "user://monster_dusk_backup_v1.json"
const INK := Color("253b49")
const CREAM := Color("fff2d5")
const GOLD := Color("ffc974")
const CORAL := Color("f28d79")
const SKY := Color("72bbb8")
const DUSK := Color("29394c")
var profile = Profile.new()
var simulation = Survival.new()
var catalog: Dictionary = {}
var screen := "home"
var ui: Control
var menu_scroll: ScrollContainer
var services: Node
var font: Font
var menu_visible := true
var clock := 0.0
var save_clock := 0.0
var toast_left := 0.0
var toast_text := ""
var joystick := Vector2.ZERO
var stick_origin := Vector2(105, 852)
var stick_current := Vector2(105, 852)
var pointer_index := -1
var paused := false
var finalized := false
var reward_pending := false
var _application_suspended := false
var run_receipt: Dictionary = {}
var particles: Array[Dictionary] = []
var textures: Dictionary = {}
var player_texture: Texture2D
var terrain: Array[Dictionary] = []
var hud_hp: ProgressBar
var hud_status: Label
var hud_wave: Label
var dash_button: Button
var music: AudioStreamPlayer
var music_context := ""
var music_streams: Dictionary = {}
var audio: Dictionary = {}
var capture_screen := ""
var capture_path := ""
var capture_frames := 0
var smoke := false
var qa := false
var smoke_frames := 0

func _ready() -> void:
	font = ThemeDB.fallback_font
	services = get_node_or_null("/root/Services")
	if is_instance_valid(services) and services.has_signal("menu_bottom_reserve_changed"):
		services.connect("menu_bottom_reserve_changed", _apply_banner_layout)
	get_viewport().size_changed.connect(_apply_banner_layout)
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--smoke-test": smoke = true
		if argument == "--qa-test": qa = true
		if argument.begins_with("--capture="): capture_screen = argument.trim_prefix("--capture=")
		if argument.begins_with("--capture-path="): capture_path = argument.trim_prefix("--capture-path=")
	_load_profile()
	profile.roll_day(_today())
	_check_achievements()
	player_texture = load("res://assets/player.png")
	var random := RandomNumberGenerator.new()
	random.seed = 44019
	for index in range(34):
		terrain.append({"pos": Vector2(random.randf_range(18, 522), random.randf_range(140, 790)), "tile": index % 6, "size": random.randf_range(20, 37)})
	if DisplayServer.get_name() != "headless": _setup_audio()
	_show_home()
	if smoke or capture_screen == "arena":
		_start_run()
		if not capture_screen.is_empty(): _capture_fixture()
	elif not capture_screen.is_empty():
		match capture_screen:
			"armory": _show_armory()
			"daily": _show_daily()
			"journal": _show_journal()
			"records": _show_records()
	set_process(true)

func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func _setup_audio() -> void:
	for key in ["shot", "hit", "click", "pickup"]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/" + key + ".ogg")
		player.volume_db = -22.0 if key == "shot" else -13.0
		add_child(player)
		audio[key] = player
	music_streams = {"camp": load("res://assets/audio/camp_watch.wav"), "patrol": load("res://assets/audio/dusk_patrol.wav")}
	music = AudioStreamPlayer.new()
	music.volume_db = -19.0
	add_child(music)
	_sync_music()

func _music_policy() -> Dictionary:
	var in_run := screen in ["arena", "pause", "cards", "results"]
	return {"context": "patrol" if in_run else "camp", "enabled": profile.music_enabled,
		"paused": _gameplay_suspended() or (in_run and (paused or screen != "arena"))}

func _sync_music() -> void:
	if not is_instance_valid(music): return
	var policy := _music_policy()
	if not policy.enabled:
		music.stop()
		return
	var wanted: String = policy.context
	if wanted != music_context:
		music.stop()
		music.stream = music_streams[wanted]
		music_context = wanted
	if not music.playing: music.play()
	music.stream_paused = policy.paused

func _sound(key: String) -> void:
	if profile.effects_enabled and audio.has(key): audio[key].play()

func _process(delta: float) -> void:
	_sync_music()
	clock += delta
	toast_left = maxf(0.0, toast_left - delta)
	for index in range(particles.size() - 1, -1, -1):
		particles[index].life = float(particles[index].life) - delta
		particles[index].pos += particles[index].vel * delta
		if float(particles[index].life) <= 0.0: particles.remove_at(index)
	var gameplay_suspended := _gameplay_suspended()
	if gameplay_suspended: _release_stick()
	if screen == "arena" and not paused and not gameplay_suspended:
		var vector := joystick
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): vector.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): vector.x += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): vector.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): vector.y += 1.0
		if Input.is_physical_key_pressed(KEY_SPACE): simulation.dash()
		if smoke:
			vector = Vector2(sin(float(smoke_frames) * 0.035), cos(float(smoke_frames) * 0.027))
			simulation.invulnerability = 999.0
		simulation.movement = vector.limit_length(1.0)
		if capture_screen.is_empty() or capture_frames < 8: simulation.step(1.0 / 30.0 if smoke else delta)
		_consume_events()
		_refresh_hud()
		if not simulation.alive: _show_results()
		elif simulation.pending_cards > 0:
			if smoke: simulation.choose_card("power")
			else: _show_cards()
		save_clock += delta
		if save_clock > 15.0:
			save_clock = 0.0
			_save_profile(true)
	if smoke:
		smoke_frames += 1
		if smoke_frames >= 420:
			var passed: bool = simulation.elapsed > 10.0 and simulation.kills > 0 and simulation.hp > 0.0
			print("MONSTER_DUSK_RUNTIME_PASS seconds=", simulation.elapsed, " kills=", simulation.kills) if passed else print("MONSTER_DUSK_RUNTIME_FAIL")
			get_tree().quit(0 if passed else 1)
	if not capture_screen.is_empty():
		capture_frames += 1
		if capture_frames == 45: _capture()
	queue_redraw()

func _consume_events() -> void:
	for event in simulation.events:
		match str(event.type):
			"shot": _sound("shot")
			"hurt":
				_sound("hit")
				_burst(event.pos, CORAL, 9)
			"kill":
				_burst(event.pos, Color(str(event.color)), 7)
			"pickup":
				_sound("pickup")
				_burst(event.pos, GOLD, 15)
			"dash": _burst(event.pos, SKY, 12)
			"hex": _burst(event.pos, Color("c59ee7"), 20)
			"notice": _toast(str(event.text))
	simulation.events.clear()

func _burst(position: Vector2, color: Color, count: int) -> void:
	for index in range(count):
		var angle := TAU * float(index) / count
		particles.append({"pos": position, "vel": Vector2.from_angle(angle) * randf_range(30, 100), "life": 0.45, "color": color})

func _new_ui() -> void:
	if is_instance_valid(menu_scroll):
		menu_scroll.hide()
		menu_scroll.queue_free()
	ui = Control.new()
	ui.name = "UI"
	ui.size = Vector2(540, 960)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_scroll = ScrollContainer.new()
	menu_scroll.size = Vector2(540, 960)
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float): queue_redraw())
	add_child(menu_scroll)
	ui.custom_minimum_size = Vector2(540, 960)
	menu_scroll.add_child(ui)
	_apply_banner_layout()

func _apply_banner_layout(reserve_override: float = -1.0) -> void:
	if not is_instance_valid(menu_scroll): return
	var reserve := reserve_override
	if reserve < 0.0:
		reserve = float(services.call("menu_bottom_reserve", self)) if is_instance_valid(services) and services.has_method("menu_bottom_reserve") else 0.0
	if not menu_visible: reserve = 0.0
	reserve = clampf(reserve, 0.0, 400.0)
	menu_scroll.size = Vector2(540.0, 960.0 - reserve)
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if reserve > 0.0 else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	menu_scroll.mouse_filter = Control.MOUSE_FILTER_PASS if reserve > 0.0 else Control.MOUSE_FILTER_IGNORE
	if reserve <= 0.0: menu_scroll.scroll_vertical = 0
	queue_redraw()

func _menu_draw_offset() -> Vector2:
	return Vector2(0, -float(menu_scroll.scroll_vertical)) if is_instance_valid(menu_scroll) else Vector2.ZERO


func _label(text: String, position: Vector2, size_value: int = 22, color: Color = CREAM, width: float = 490) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(width, 42)
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(label)
	return label

func _style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0.0 else 0)
	style.content_margin_left = 13
	style.content_margin_right = 13
	return style

func _button(text: String, rectangle: Rect2, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_PASS if screen not in ["arena", "cards"] else Control.MOUSE_FILTER_STOP
	button.text = text
	button.position = rectangle.position
	button.size = rectangle.size
	button.add_theme_stylebox_override("normal", _style(GOLD if accent else Color("3c5362")))
	button.add_theme_stylebox_override("hover", _style(Color("ffd895") if accent else Color("4b6776")))
	button.add_theme_stylebox_override("pressed", _style(CORAL if accent else Color("628a8d")))
	button.add_theme_stylebox_override("disabled", _style(Color("3a4650")))
	button.add_theme_color_override("font_color", INK if accent else CREAM)
	button.add_theme_color_override("font_hover_color", INK if accent else CREAM)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(func() -> void:
		_sound("click")
		callback.call())
	ui.add_child(button)
	return button

func _header(title: String, subtitle: String) -> void:
	_label(title, Vector2(25, 32), 31)
	_label(subtitle, Vector2(27, 80), 17, Color("b6cecb"))

func _page(title: String, subtitle: String) -> VBoxContainer:
	_new_ui()
	_header(title, subtitle)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(25, 140)
	scroll.size = Vector2(490, 630)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 470
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	_button("Back to camp", Rect2(25, 795, 490, 54), _show_home)
	_set_menu(true)
	return column

func _card(column: VBoxContainer, title: String, detail: String, action: String = "", callback: Callable = Callable(), disabled: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _style(Color("344b59")))
	panel.custom_minimum_size.y = 94
	column.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", GOLD)
	box.add_child(heading)
	var body := Label.new()
	body.text = detail
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 420
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", CREAM)
	box.add_child(body)
	if not action.is_empty():
		var button := Button.new()
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.text = action
		button.custom_minimum_size.y = 44
		button.disabled = disabled
		button.add_theme_stylebox_override("normal", _style(Color("55767a")))
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void:
			_sound("click")
			callback.call())
		box.add_child(button)

func _show_home() -> void:
	screen = "home"
	paused = false
	_new_ui()
	_label("MONSTER DUSK", Vector2(31, 48), 42)
	_label("A P O C A L Y P S E", Vector2(34, 101), 20, GOLD)
	_label("One brave keeper. A very long night.", Vector2(34, 146), 18, Color("b6cecb"))
	_label("LEVEL %d  •  %d coins" % [profile.level(), profile.coins], Vector2(35, 453), 20, GOLD)
	_button("Enter the dusk", Rect2(30, 510, 480, 72), _start_run, true)
	_button("Armory", Rect2(30, 600, 233, 62), _show_armory)
	_button("Daily camp", Rect2(277, 600, 233, 62), _show_daily)
	_button("Field journal", Rect2(30, 680, 233, 62), _show_journal)
	_button("Records", Rect2(277, 680, 233, 62), _show_records)
	_button("Sound & privacy", Rect2(30, 765, 480, 53), _show_settings)
	_label("Drag to move  •  Fire automatically  •  Dash to escape", Vector2(35, 840), 15, Color("a9c2c0"))
	_set_menu(true)

func _start_run() -> void:
	simulation = Survival.new()
	simulation.start(profile, 73391 if smoke or not capture_screen.is_empty() else int(Time.get_ticks_usec()))
	finalized = false
	reward_pending = false
	run_receipt = {}
	paused = false
	joystick = Vector2.ZERO
	pointer_index = -1
	screen = "arena"
	_build_arena_ui()
	_set_menu(false)

func _build_arena_ui() -> void:
	_new_ui()
	hud_wave = _label("WAVE 1", Vector2(23, 28), 27)
	hud_status = _label("", Vector2(24, 68), 17, Color("b6cecb"), 400)
	_button("II", Rect2(460, 30, 56, 52), _show_pause)
	hud_hp = ProgressBar.new()
	hud_hp.position = Vector2(25, 110)
	hud_hp.size = Vector2(490, 17)
	hud_hp.show_percentage = false
	hud_hp.max_value = simulation.max_hp
	hud_hp.add_theme_stylebox_override("background", _style(Color("172b38")))
	hud_hp.add_theme_stylebox_override("fill", _style(CORAL))
	ui.add_child(hud_hp)
	dash_button = _button("DASH", Rect2(393, 815, 115, 70), _dash, true)
	_label("DRAG TO MOVE", Vector2(33, 906), 15, Color("adbfba"), 260)
	_label("AUTO-FIRE", Vector2(384, 905), 15, GOLD, 145)
	_refresh_hud()

func _refresh_hud() -> void:
	if not is_instance_valid(hud_wave): return
	hud_wave.text = "WAVE %d / %s" % [simulation.wave, DuskCycle.sample(simulation.elapsed).name]
	hud_status.text = "%02d:%02d  •  %d defeated  •  build rank %d" % [int(simulation.elapsed) / 60, int(simulation.elapsed) % 60, simulation.kills, simulation.rank]
	hud_hp.value = simulation.hp
	dash_button.text = "DASH" if simulation.dash_cooldown <= 0 else "%.1fs" % simulation.dash_cooldown
	dash_button.disabled = simulation.dash_cooldown > 0.0

func _dash() -> void:
	if _gameplay_suspended(): return
	simulation.dash()

func _gameplay_suspended() -> bool:
	return _application_suspended or (is_instance_valid(services) and services.has_method("fullscreen_ad_active") and bool(services.fullscreen_ad_active()))

func _show_pause() -> void:
	if screen != "arena": return
	_release_stick()
	paused = true
	screen = "pause"
	var column := _page("A quiet moment", "Your run is paused.")
	_card(column, "Keep your lantern lit", "Drag anywhere on the arena to steer. Your weapon aims at the nearest monster. Dash follows your last movement direction, even after you lift your thumb.")
	_card(column, "Resume the night", "Continue this run exactly where you left it.", "Resume", func() -> void:
		paused = false
		screen = "arena"
		_build_arena_ui()
		_set_menu(false))
	_card(column, "Bank this run", "Keep the coins and experience already earned, then return to camp.", "Bank & return", func() -> void:
		_bank_run()
		_show_home())
	# Replace generic back behavior so pausing cannot silently discard a run.
	for child in ui.get_children():
		if child is Button and child.text == "Back to camp":
			child.text = "Resume run"
			for connection in child.pressed.get_connections(): child.pressed.disconnect(connection.callable)
			child.pressed.connect(func() -> void:
				paused = false
				screen = "arena"
				_build_arena_ui()
				_set_menu(false))

func _show_cards() -> void:
	_release_stick()
	screen = "cards"
	_new_ui()
	_header("A brighter lantern", "Choose one run upgrade. The night is paused.")
	var options := ["power", "tempo", "spread", "speed", "mend"]
	var descriptions := {"power": "Bullets deal 22% more base damage.", "tempo": "Fire 14% faster.", "spread": "Add a bullet to each volley.", "speed": "Move 12 pixels/second faster.", "mend": "Restore 35% of your maximum health."}
	for index in range(3):
		var key: String = options[(simulation.rank + index) % options.size()]
		var button := _button(key.to_upper() + "\n" + str(descriptions[key]), Rect2(30, 205 + index * 180, 480, 145), func() -> void:
			simulation.choose_card(key)
			if simulation.pending_cards > 0: _show_cards()
			else:
				screen = "arena"
				_build_arena_ui(), index == 0)
		button.add_theme_font_size_override("font_size", 20)
	_set_menu(false)

func _show_results() -> void:
	_release_stick()
	screen = "results"
	_new_ui()
	_header("The camp remembers", "Another night. Another story.")
	_label("WAVE %d" % simulation.wave, Vector2(35, 205), 43, GOLD)
	_label("%d monsters defeated" % simulation.kills, Vector2(37, 275), 25)
	_label("%02d:%02d survived  •  %d dashes" % [int(simulation.elapsed) / 60, int(simulation.elapsed) % 60, simulation.dashes], Vector2(38, 323), 18, Color("b6cecb"))
	_label("Your earned progress is kept when you bank or retry.", Vector2(37, 400), 16, CREAM)
	var can_continue: bool = not simulation.continued and is_instance_valid(services) and services.can_reward()
	var revive := _button("Watch reward • revive once", Rect2(30, 480, 480, 62), _request_revive, true)
	revive.disabled = not can_continue
	_label("Revive is optional; an earned ad reward is required.", Vector2(34, 554), 15, Color("b6cecb"))
	_button("Bank run & retry", Rect2(30, 630, 480, 65), func() -> void:
		_bank_run()
		_start_run(), true)
	_button("Bank run & return to camp", Rect2(30, 715, 480, 58), func() -> void:
		_bank_run()
		_show_home())
	_save_profile(true)
	_set_menu(false)

func _request_revive() -> void:
	if reward_pending: return
	if not is_instance_valid(services) or simulation.continued:
		_toast("No rewarded ad is available. Your run can still be banked.")
		return
	reward_pending = true
	var requested_run: RefCounted = simulation
	services.reward_requested("A second lantern", func(granted: bool) -> void:
		if requested_run != simulation: return
		reward_pending = false
		if granted and screen == "results" and simulation.continue_run():
			screen = "arena"
			_build_arena_ui()
			_set_menu(false)
		else: _toast("No reward earned. You can retry or return normally."))

func _bank_run() -> void:
	if finalized: return
	finalized = true
	profile.roll_day(_today())
	run_receipt = profile.record_run(simulation.result())
	_check_achievements()
	_submit_scores()
	_save_profile(false)
	if bool(run_receipt.get("recorded", false)):
		_toast("+%d coins  +%d XP" % [int(run_receipt.coins), int(run_receipt.xp)])
		if is_instance_valid(services) and not simulation.alive: services.round_finished()

func _show_armory() -> void:
	screen = "armory"
	var column := _page("The little armory", "%d coins  •  Keeper level %d" % [profile.coins, profile.level()])
	var labels := {"power": "Bright powder", "vitality": "Sturdy coat", "tempo": "Quick hands", "magnet": "Lantern pull"}
	var details := {"power": "+2.7 base bullet damage each level.", "vitality": "+12 maximum health each level.", "tempo": "A shorter delay between volleys.", "magnet": "Collect lantern XP from farther away."}
	for key: String in Profile.UPGRADE_KEYS:
		var cost := profile.upgrade_cost(key)
		_card(column, "%s  %d/10" % [labels[key], int(profile.upgrades[key])], details[key], "MAXIMUM" if cost < 0 else "Upgrade • %d coins" % cost, func() -> void:
			if profile.purchase_upgrade(key):
				_check_achievements()
				_save_profile()
				_show_armory(), cost < 0 or profile.coins < cost)
	var names := {"repeater": "Camp repeater", "scatter": "Sunburst scatter", "lantern": "Moon lantern"}
	var info := {"repeater": "Reliable single shots. Yours from the start.", "scatter": "A close volley of three bullets. Requires level 3 and 250 coins.", "lantern": "Piercing moon shots hit two targets. Requires level 6 and 650 coins."}
	for key: String in Profile.WEAPONS:
		_card(column, names[key], info[key], "EQUIPPED" if profile.selected_weapon == key else ("Equip" if key in profile.owned_weapons else "Unlock"), func() -> void:
			if profile.unlock_weapon(key):
				_save_profile()
				_show_armory()
			else: _toast("A little more experience or coin is needed."), profile.selected_weapon == key)

func _show_daily() -> void:
	screen = "daily"
	profile.roll_day(_today())
	var column := _page("Daily campfire", "A small reason to light your lantern. Resets at UTC midnight.")
	var next_day: int = (profile.login_streak % 7) + 1 if profile.login_day == _today() - 1 else 1
	_card(column, "Seven-night welcome", "Gifts: 100 / 150 / 210 / 280 / 360 / 460 / 750 coins.\nCurrent streak: %d nights. Miss a day and the streak starts at one." % profile.login_streak, "Gift already claimed" if profile.login_day >= _today() else "Claim day %d • %d coins" % [next_day, Profile.LOGIN_REWARDS[next_day - 1]], func() -> void:
		var amount := profile.claim_login(_today())
		if amount > 0:
			_check_achievements()
			_save_profile()
			_sound("pickup")
			_show_daily()
			_toast("Camp gift: +%d coins" % amount), profile.login_day >= _today())
	var titles := {"kills": "Clear the trail", "survival": "Keep the light", "dashes": "Light on your feet"}
	for key in Profile.DAILY_GOALS:
		var count := int(profile.daily[key])
		var target := int(Profile.DAILY_GOALS[key])
		var claimed := bool(profile.daily_claimed.get(key, false))
		_card(column, titles[key], "%d / %d  •  Reward: 160 coins + 20 XP" % [mini(count, target), target], "Claimed" if claimed else "Claim quest", func() -> void:
			if profile.claim_quest(key) > 0:
				_check_achievements()
				_save_profile()
				_show_daily(), claimed or count < target)

func _show_journal() -> void:
	screen = "journal"
	var column := _page("The field journal", "%d / 200 creatures sighted  •  %d / %d milestones" % [profile.seen.size(), profile.achieved.size(), catalog.achievements.size()])
	_card(column, "Six kinds of trouble", "Shamblers follow. Rushers chase. Ironhides soak damage. Ember Fangs hit hard but fall fast. Spitters keep their distance. Hexlings mark the ground before casting.")
	for kind in Survival.PROFILES:
		var spec: Dictionary = Survival.PROFILES[kind]
		_card(column, "%s • %d defeated" % [spec.name, int(profile.kind_kills[kind])], "Speed %d  •  Base health %d  •  Touch damage %d" % [int(spec.speed), int(spec.hp), int(spec.damage)])
	for entry in catalog.achievements:
		var unlocked := bool(profile.achieved.get(entry.key, false))
		_card(column, ("★ " if unlocked else "○ ") + str(entry.name), str(entry.description) + "\n%d / %d" % [mini(profile.metric(str(entry.metric)), int(entry.threshold)), int(entry.threshold)])
	_card(column, "Online achievements", "Local milestones work offline. Connect Play Games when the online service is available.", "Open Play Games achievements", func() -> void:
		if is_instance_valid(services): services.open_achievements()
		_toast("Local achievements are always saved here."))

func _show_records() -> void:
	screen = "records"
	var column := _page("Stories by the fire", "Personal records are saved offline.")
	var labels := {"kills": "Monsters defeated", "best_wave": "Highest wave", "best_seconds": "Longest night", "player_level": "Keeper level", "seen": "Creatures sighted"}
	for entry in catalog.leaderboards:
		var key := str(entry.key)
		_card(column, "%s: %d" % [labels.get(key, entry.name), profile.metric(str(entry.metric))], str(entry.description), "Open online board", func() -> void:
			if is_instance_valid(services): services.open_leaderboards(key)
			_toast("Online boards need Play Games; your record stays local."))
	_card(column, "Connect Play Games", "Optional online leaderboards and achievements. Your game remains playable without sign-in.", "Connect", func() -> void:
		if is_instance_valid(services): services.sign_in()
		_toast("Online services may be unavailable in this build."))

func _show_settings() -> void:
	screen = "settings"
	var column := _page("Make yourself at home", "Sound, privacy, and local progress.")
	_card(column, "Camp & patrol music", "Two original looping scores follow camp and active watches.", "Music: ON" if profile.music_enabled else "Music: OFF", func() -> void:
		profile.music_enabled = not profile.music_enabled
		_sync_music()
		_save_profile()
		_show_settings())
	_card(column, "Sound effects", "Soft interface sounds and arcade combat feedback.", "Effects: ON" if profile.effects_enabled else "Effects: OFF", func() -> void:
		profile.effects_enabled = not profile.effects_enabled
		_save_profile()
		_show_settings())
	_card(column, "Advertising privacy", "Advertising is optional for rewards. The Android version provides applicable privacy options.", "Privacy options", func() -> void:
		if is_instance_valid(services): services.privacy_options()
		_toast("Advertising privacy options are available in the Android app."))
	_card(column, "Offline progress", "Coins, upgrades, daily rewards and records stay on this device. A recent unfinished run is banked after an interrupted session. Online boards do not replace local saves.")
	_card(column, "Credits", "Original game code: EthannYakabuski, Apache 2.0.\nCreature art: Kenney Creature Mixer (custom non-NFT/blockchain terms). Western art: Kenney (CC0). See accompanying license notices.\nAdditional Kenney sound assets retain their supplied notices. Godot Engine: MIT.")

func _set_menu(visible: bool) -> void:
	menu_visible = visible
	if is_instance_valid(services): services.set_menu_visible(visible)
	_apply_banner_layout()

func _check_achievements() -> void:
	for key in profile.check_achievements(catalog):
		if is_instance_valid(services): services.unlock(str(key))

func _submit_scores() -> void:
	if not is_instance_valid(services): return
	for board in catalog.leaderboards: services.submit(str(board.key), profile.metric(str(board.metric)))

func _load_profile() -> void:
	if qa or smoke or not capture_screen.is_empty(): return
	var value: Dictionary = SaveStore.read(SAVE_PATH, BACKUP_PATH)
	if value.is_empty(): return
	if not profile.load_data(value): return
	if value.get("pending_run", {}) is Dictionary and not value.get("pending_run", {}).is_empty():
		profile.roll_day(_today())
		profile.record_run(value.pending_run)
		_toast("Your interrupted run was safely banked.")
		_save_profile(false)

func _save_profile(pending: bool = false) -> void:
	if smoke or qa or not capture_screen.is_empty(): return
	var value := profile.to_data()
	if pending and not finalized: value["pending_run"] = simulation.result()
	if not SaveStore.write(SAVE_PATH, BACKUP_PATH, value):
		_toast("Progress could not be saved. Please check device storage.")

func _toast(text: String) -> void:
	toast_text = text
	toast_left = 3.5

func _release_stick() -> void:
	joystick = Vector2.ZERO
	pointer_index = -1
	simulation.movement = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if _gameplay_suspended():
		_release_stick()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if screen == "arena": _show_pause()
		elif screen == "pause":
			paused = false
			screen = "arena"
			_build_arena_ui()
			_set_menu(false)
		elif screen not in ["results", "cards"]: _show_home()
	if screen != "arena" or paused: return
	if event is InputEventScreenTouch:
		if event.pressed and pointer_index == -1:
			pointer_index = event.index
			stick_origin = event.position
			stick_current = event.position
		elif not event.pressed and event.index == pointer_index:
			pointer_index = -1
			joystick = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == pointer_index:
		stick_current = event.position
		joystick = (stick_current - stick_origin).limit_length(68.0) / 68.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and pointer_index == -1:
			pointer_index = -2
			stick_origin = event.position
			stick_current = event.position
		elif not event.pressed and pointer_index == -2:
			pointer_index = -1
			joystick = Vector2.ZERO
	elif event is InputEventMouseMotion and pointer_index == -2:
		stick_current = event.position
		joystick = (stick_current - stick_origin).limit_length(68.0) / 68.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_suspended = true
		_release_stick()
		if screen in ["arena", "cards", "pause", "results"]: _save_profile(true)
		else: _save_profile()
		if screen == "arena": _show_pause()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_suspended = false
		_release_stick()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _gameplay_suspended():
			_release_stick()
			return
		if screen == "arena": _show_pause()
		elif screen == "pause":
			paused = false
			screen = "arena"
			_build_arena_ui()
			_set_menu(false)
		elif screen not in ["results", "cards"]: _show_home()
	_sync_music()

func _exit_tree() -> void:
	for player in audio.values():
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	music_streams.clear()

func _creature(index: int) -> Texture2D:
	var key := "creature_%03d" % (index % 200)
	if not textures.has(key): textures[key] = load("res://assets/creatures/" + key + ".png")
	return textures[key]

func _draw_creature(index: int, position: Vector2, width: float, shade: Color = Color.WHITE) -> void:
	var texture := _creature(index)
	var frame := int(clock * 5.0 + index) % 4
	draw_texture_rect_region(texture, Rect2(position - Vector2(width, width) * 0.5, Vector2(width, width)), Rect2(frame * 96, 0, 96, 96), shade)

func _draw() -> void:
	var sky: Color = DuskCycle.sample(simulation.elapsed).sky if screen in ["arena", "pause", "cards", "results"] else DUSK
	draw_rect(Rect2(0, 0, 540, 960), sky)
	if screen in ["arena", "pause", "cards", "results"]:
		# Stable control panels preserve text contrast through bright dawn/day skies.
		draw_rect(Rect2(0, 0, 540, 142), DUSK)
		draw_rect(Rect2(0, 790, 540, 170), DUSK)
		_draw_arena()
	else:
		draw_set_transform(_menu_draw_offset())
		_draw_camp()
	draw_set_transform(Vector2.ZERO)
	if toast_left > 0.0:
		var toast_y := minf(865.0, menu_scroll.size.y - 60.0) if is_instance_valid(menu_scroll) else 865.0
		draw_style_box(_style(Color(0.10, 0.18, 0.24, 0.95), SKY), Rect2(25, toast_y, 490, 42))
		draw_string(font, Vector2(40, toast_y + 28), toast_text, HORIZONTAL_ALIGNMENT_LEFT, 460, 16, CREAM)

func _draw_camp() -> void:
	for index in range(34):
		var star := Vector2(fposmod(index * 97.4, 540.0), 170.0 + fposmod(index * 43.6, 270.0))
		draw_circle(star, 1.4 if index % 4 else 2.3, Color("7d929e"))
	draw_circle(Vector2(425, 245), 48, Color("f4da98"))
	draw_circle(Vector2(442, 230), 44, DUSK)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 415), Vector2(95, 275), Vector2(177, 389), Vector2(268, 252), Vector2(390, 421), Vector2(460, 335), Vector2(540, 418), Vector2(540, 960), Vector2(0, 960)]), Color("3d515b"))
	if screen == "home":
		draw_ellipse_shadow(Vector2(264, 420), Vector2(165, 28))
		_draw_creature(48, Vector2(122, 354), 100)
		_draw_creature(137, Vector2(432, 370), 100)
		draw_texture_rect(player_texture, Rect2(223, 320, 92, 92), false)
		for index in range(4):
			var glow := 17.0 + sin(clock * 4.0 + index) * 4.0
			draw_circle(Vector2(280, 403), glow + index * 5.0, Color(1, 0.75, 0.35, 0.06))
		draw_circle(Vector2(280, 403), 7, GOLD)

func draw_ellipse_shadow(position: Vector2, dimensions: Vector2) -> void:
	var offset := _menu_draw_offset() if screen not in ["arena", "pause", "cards", "results"] else Vector2.ZERO
	draw_set_transform(position + offset, 0, Vector2(1, dimensions.y / dimensions.x))
	draw_circle(Vector2.ZERO, dimensions.x * 0.5, Color(0.06, 0.1, 0.15, 0.4))
	draw_set_transform(offset)

func _draw_arena() -> void:
	var light := DuskCycle.sample(simulation.elapsed)
	var ground: Color = light.ground
	draw_style_box(_style(ground, ground.lightened(0.22)), Survival.ARENA)
	for item in terrain:
		var key := "tile_%d" % int(item.tile)
		if not textures.has(key): textures[key] = load("res://assets/terrain/" + key + ".png")
		draw_texture_rect(textures[key], Rect2(item.pos, Vector2(item.size, item.size)), false, Color(1, 1, 1, 0.65 - float(light.lantern) * 0.13))
	# The environment changes, while threats, pickups and the HUD stay readable.
	for radius in [80.0, 58.0, 36.0]:
		draw_circle(simulation.player, radius, Color(1.0, 0.78, 0.40, 0.035 * float(light.lantern)))
	for hazard in simulation.hazards:
		var pulse := 0.25 + 0.15 * sin(clock * 14.0)
		draw_circle(hazard.pos, float(hazard.radius), Color(0.75, 0.25, 0.9, pulse))
		draw_arc(hazard.pos, float(hazard.radius), 0, TAU, 40, Color("ecd1f9"), 2.5, true)
	for drop in simulation.drops:
		var colors := {"xp": SKY, "heal": CORAL, "haste": GOLD, "shield": Color("8cb9e1"), "nova": Color("d3a5ee")}
		var color: Color = colors.get(drop.kind, GOLD)
		draw_circle(drop.pos, 4 if drop.kind == "xp" else 10, color)
		if drop.kind != "xp": draw_arc(drop.pos, 14.0, 0, TAU, 20, color, 2, true)
	for enemy in simulation.enemies:
		var radius := float(enemy.radius)
		var color := Color(str(Survival.PROFILES[enemy.kind].color))
		draw_ellipse_shadow(enemy.pos + Vector2(0, radius * 0.7), Vector2(radius * 2.2, 10))
		if bool(enemy.elite): draw_arc(enemy.pos, radius + 8.0, 0, TAU, 28, GOLD, 3, true)
		_draw_creature(int(enemy.sprite), enemy.pos, radius * 2.3, Color(1.6, 1.6, 1.6) if float(enemy.flash) > 0.0 else Color.WHITE)
		draw_circle(enemy.pos + Vector2(radius * 0.7, -radius * 0.6), 4.5, color)
		if float(enemy.hp) < float(enemy.max_hp):
			draw_rect(Rect2(enemy.pos + Vector2(-radius, -radius - 8), Vector2(radius * 2, 4)), Color("453c45"))
			draw_rect(Rect2(enemy.pos + Vector2(-radius, -radius - 8), Vector2(radius * 2 * float(enemy.hp) / float(enemy.max_hp), 4)), color)
	for bullet in simulation.bullets:
		draw_circle(bullet.pos, float(bullet.radius), GOLD if bool(bullet.friendly) else Color("d3a5ee"))
		if bool(bullet.friendly): draw_line(bullet.pos, bullet.pos - bullet.vel.normalized() * 11.0, Color("fff0b0"), 2.5, true)
	if simulation.shield_left > 0.0 or simulation.invulnerability > 0.8:
		draw_arc(simulation.player, 29.0, 0, TAU, 32, SKY, 3.0, true)
	var player_shade := Color(1, 1, 1, 0.45) if simulation.invulnerability > 0.0 and int(clock * 13) % 2 else Color.WHITE
	draw_ellipse_shadow(simulation.player + Vector2(0, 21), Vector2(47, 13))
	draw_texture_rect(player_texture, Rect2(simulation.player - Vector2(28, 30), Vector2(56, 56)), false, player_shade)
	for particle in particles:
		var color: Color = particle.color
		color.a = clampf(float(particle.life) * 2.3, 0, 1)
		draw_circle(particle.pos, 3.5, color)
	if screen == "arena":
		var origin := stick_origin if pointer_index != -1 else Vector2(105, 852)
		draw_circle(origin, 48, Color(0.3, 0.5, 0.57, 0.25))
		draw_arc(origin, 48, 0, TAU, 32, Color("73989f"), 2, true)
		draw_circle(origin + joystick * 31.0, 19, Color("bad0ca"))
	elif screen in ["pause", "cards", "results"]:
		draw_rect(Rect2(0, 0, 540, 960), Color(0.11, 0.18, 0.25, 0.86))

func _capture_fixture() -> void:
	simulation.elapsed = 97.0
	simulation.wave = 5
	simulation.hp = 81
	simulation.kills = 47
	simulation.enemies.clear()
	var index := 0
	for kind in Survival.PROFILES:
		simulation.spawn_enemy(str(kind), Vector2(95 + (index % 3) * 170, 235 + int(index / 3) * 420), index == 2)
		index += 1
	simulation.drops.append({"pos": Vector2(330, 450), "kind": "shield", "value": 1, "life": 30.0})
	simulation.drops.append({"pos": Vector2(210, 530), "kind": "xp", "value": 4, "life": 30.0})
	simulation.hazards.append({"pos": Vector2(395, 425), "left": 1.35, "radius": 58.0, "damage": 20.0})
	_refresh_hud()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		print("MONSTER_DUSK_CAPTURE_FAIL headless renderer cannot capture pixels")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(capture_path if not capture_path.is_empty() else "user://monster-dusk-capture.png")
	print("MONSTER_DUSK_CAPTURE ", capture_screen, " result=", result)
	get_tree().quit(0 if result == OK else 1)
