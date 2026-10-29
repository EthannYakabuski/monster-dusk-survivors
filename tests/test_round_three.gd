extends SceneTree
## Synthetic source regression only. No native gameplay, SDK reward or save claim.

const Profile = preload("res://game/profile.gd")
const Survival = preload("res://game/survival.gd")
var checks := 0
var failures: Array[String] = []

class ServicesStub extends Node:
	var active := false
	func fullscreen_ad_active() -> bool: return active
	func set_menu_visible(_value: bool) -> void: pass
	func unlock(_key: String) -> void: pass
	func submit(_key: String, _value: int) -> void: pass
	func round_finished() -> void: pass

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func arena(p = null):
	var s = Survival.new()
	s.start(Profile.new() if p == null else p, 70531)
	s.enemies.clear()
	s.spawn_clock = 999.0
	s.invulnerability = 999.0
	return s

func target(s, kind: String = "tank") -> void:
	s.spawn_enemy(kind, s.player + Vector2(130, 0))
	s.enemies[-1].hp = 100000.0
	s.enemies[-1].max_hp = 100000.0

func _run() -> void:
	_test_balance()
	_test_ammo()
	_test_migration()
	await _test_input()
	await _test_viewports()
	print("MONSTER_ROUND_THREE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_balance() -> void:
	for wave in [1, 5, 20, 100]:
		for kind in Survival.PROFILES:
			for elite in [false, true]:
				var s = arena()
				s.wave = wave
				s.spawn_enemy(kind, Vector2(100, 200), elite)
				var enemy: Dictionary = s.enemies[0]
				var base: Dictionary = Survival.PROFILES[kind]
				var old_hp: float = float(base.hp) * (1 + (wave - 1) * .11) * (3.4 if elite else 1.0)
				var old_speed := float(base.speed) * minf(1.7, 1 + wave * .017)
				check(is_equal_approx(enemy.hp, old_hp + 29.25) and enemy.max_hp == enemy.hp, "Three extra baseline hits added after wave/elite HP: %s/%d/%s" % [kind, wave, elite])
				check(is_equal_approx(enemy.speed, old_speed * 1.25 * .90), "Round Four retains the prior buff then reduces speed ten percent: %s/%d/%s" % [kind, wave, elite])
	for rank in [0, 5, 10]:
		var p = Profile.new()
		p.upgrades.power = rank
		p.upgrades.tempo = rank
		for weapon in Profile.WEAPONS:
			p.selected_weapon = weapon
			var s = arena(p)
			target(s)
			s.cards.power = 2
			s.cards.tempo = 3
			s.haste_left = 7.0
			s._fire(0.0, true)
			var damage: float = (13.0 + 2.7 * rank) * .75 * (1.0 + 2 * .22)
			var interval := maxf(.19, .46 - .022 * rank) / (1 + 3 * .14) * .52
			if weapon == "scatter": damage *= .65; interval *= 1.32
			if weapon == "lantern": damage *= 1.25; interval *= 1.22
			check(is_equal_approx(s.bullets[0].damage, damage), "Projectile nerf precedes card and weapon effects: %s/%d" % [weapon, rank])
			check(is_equal_approx(s.fire_clock, interval), "Restored rate preserves tempo, haste and weapon cadence: %s/%d" % [weapon, rank])
			s.bullets.clear()
			s.enemies[0].pos = s.player + Vector2(100, 0)
			var before := float(s.enemies[0].hp)
			s._apply_pickup("nova")
			check(is_equal_approx(before - s.enemies[0].hp, (13.0 + 2.7 * rank) * 5), "Nova retains pre-nerf damage independent of cards/weapon: %s/%d" % [weapon, rank])
	for kind in Survival.PROFILES:
		var s = arena()
		s.invulnerability = 0
		s.wave = 5
		s.spawn_enemy(kind, s.player + Vector2(1, 0))
		s.enemies[0].timer = 999.0
		s._move_enemies(0.0)
		check(is_equal_approx(s.hp, 100.0 - (float(Survival.PROFILES[kind].damage) + 2.5) * 1.2), "Contact damage scaled once centrally: " + kind)
	var s = arena()
	s.invulnerability = 0
	s.bullets.append({"pos":s.player, "vel":Vector2.ZERO, "friendly":false, "damage":19.0, "radius":7.0, "life":1.0, "pierce":0})
	s._move_bullets(.01)
	check(is_equal_approx(s.hp, 77.2) and s.bullets.is_empty(), "Enemy projectile receives exactly one incoming multiplier")
	s.invulnerability = 0
	s.hazards.append({"pos":s.player,"left":0.0,"radius":58.0,"damage":25.0})
	s._update_hazards(.01)
	check(is_equal_approx(s.hp, 47.2) and s.hazards.is_empty(), "Hex damage receives exactly one incoming multiplier")
	var hp: float = s.hp
	s.take_damage(20.0)
	check(s.hp == hp, "Hit recovery still suppresses repeated incoming hits")
	s.invulnerability = 0
	s.shield_left = 1
	s.take_damage(1000)
	check(s.hp == hp and s.alive, "Shield guards before damage scaling")
	var ranged = arena()
	ranged.spawn_enemy("ranged", ranged.player + Vector2(70, 0))
	ranged.enemies[0].timer = 0
	ranged._move_enemies(.05)
	check(ranged.enemies[0].pos.x > ranged.player.x + 70 and ranged.bullets.size() == 1, "Spitter still retreats and fires hostile bullets")
	var hex = arena()
	hex.spawn_enemy("magical", Vector2(80, 250))
	hex.enemies[0].timer = 0
	hex._move_enemies(.01)
	check(hex.hazards.size() == 1 and is_equal_approx(hex.hazards[0].left, 1.35), "Hexling still telegraphs its ground attack")

func _test_ammo() -> void:
	var s = arena()
	target(s)
	for tick in range(60): s.step(.05)
	check(s.ammo == 20 and s.bullets.is_empty() and s.kills == 0, "No deliberate input means no shots or ammo use")
	s.fire_clock = 0
	s._fire(0.0, true)
	check(s.ammo == 19 and s.bullets.size() == 1, "One deliberate repeater volley consumes one round")
	s._fire(0.0, true)
	check(s.ammo == 19, "Held input cannot bypass cadence")
	s._fire(2.0, false)
	check(s.ammo == 19, "Release advances cooldown without another shot")
	s.enemies.clear()
	s._fire(1.0, true)
	check(s.ammo == 19, "No target means no volley and no ammo use")
	target(s)
	s.ammo = 1
	s._fire(0.0, true)
	check(s.ammo == 0 and is_equal_approx(s.reload_left, 1.65), "Final round starts exactly a 1.65 second reload")
	var bullets: int = s.bullets.size()
	s._fire(1.64, true)
	check(s.ammo == 0 and s.reload_left > 0 and s.bullets.size() == bullets, "Reload cannot complete early or fire during reload")
	s._fire(.01, false)
	check(s.ammo == 20 and s.reload_left == 0 and s.bullets.size() == bullets, "Reload completes at its boundary without an automatic shot")
	s._fire(0.0, true)
	check(s.ammo == 19 and s.bullets.size() == bullets + 1, "Fresh held input can fire after reload")
	var timed = arena()
	target(timed)
	timed.ammo = 1
	timed.step(0.0, true)
	for tick in range(32): timed.step(.05, false)
	check(timed.ammo == 0 and timed.reload_left > 0, "Active step reload remains empty at 1.60 seconds")
	timed.step(.05, false)
	check(timed.ammo == 20 and timed.reload_left == 0, "Capped simulation steps complete reload at 1.65 seconds")
	check(s.request_reload() and not s.request_reload(), "Manual partial reload is accepted only once")
	var left: float = s.reload_left
	s.pending_cards = 1
	s.step(.05, true)
	check(s.reload_left == left and s.ammo == 19, "Rank card selection freezes ammo and reload")
	s.pending_cards = 0
	s.alive = false
	s.step(.05, true)
	check(s.reload_left == left, "Death freezes reload")
	for weapon in Profile.WEAPONS:
		var p = Profile.new()
		p.selected_weapon = weapon
		s = arena(p)
		target(s)
		s.cards.spread = 4
		s._fire(0.0, true)
		check(s.ammo == 19 and s.bullets.size() == (7 if weapon == "scatter" else 5), "Every multi-projectile volley costs one round: " + weapon)

func _test_migration() -> void:
	var p = Profile.new()
	check(p.upgrades.magazine == 0 and p.magazine_capacity() == 20, "New profiles start with a twenty-round magazine")
	p.coins = 1000000
	for rank in range(10):
		check(p.magazine_capacity() == 20 + rank * 2 and p.upgrade_cost("magazine") == 180 + rank * 200 + rank * rank * 50, "Magazine capacity and existing cost curve at rank %d" % rank)
		check(p.purchase_upgrade("magazine"), "Magazine rank can be purchased: %d" % rank)
	check(p.upgrades.magazine == 10 and p.magazine_capacity() == 40 and not p.purchase_upgrade("magazine"), "Magazine rank caps at ten and forty rounds")
	p.daily_claimed = {"kills":false,"survival":false,"dashes":false}
	var restored = Profile.new()
	check(restored.load_data(JSON.parse_string(JSON.stringify(p.to_data()))) and restored.to_data() == p.to_data(), "New magazine rank survives the complete save roundtrip")
	var s = arena(restored)
	check(s.ammo == 40 and s.magazine_capacity == 40, "A new run equips the saved expanded magazine")
	restored.load_data({"upgrades":{"magazine":999}})
	check(restored.upgrades.magazine == 10, "Malformed high rank remains bounded")
	restored.load_data({"upgrades":{"magazine":-4}})
	check(restored.upgrades.magazine == 0, "Malformed negative rank is normalized")

func touch(game, index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	game._input(event)

func drag(game, index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	game._input(event)

func _test_input() -> void:
	var services := ServicesStub.new()
	root.add_child(services)
	var game = load("res://main.tscn").instantiate()
	game.qa = true
	root.add_child(game)
	game.set_process(false)
	game.services = services
	game._start_run()
	game._process(0.0) # Neutral keyboard observation, no combat delta.
	check(game.fire_button.icon != null and game.fire_button.focus_mode == Control.FOCUS_NONE, "Gun control has a real icon and cannot inherit keyboard focus activation")
	check(not game.fire_button.get_rect().intersects(game.dash_button.get_rect()) and not game.fire_button.get_rect().intersects(game.reload_button.get_rect()), "Fire, dash and reload hit areas remain separate")
	var fire: Vector2 = game.fire_button.get_global_rect().get_center()
	touch(game, 0, Vector2(80, 650), true)
	drag(game, 0, Vector2(145, 650))
	touch(game, 1, fire, true)
	check(game.pointer_index == 0 and game.fire_index == 1 and game.joystick.x > .9 and game._fire_input(), "Independent left movement and right fire fingers can remain held together")
	game._process(.01)
	check(game.simulation.ammo == 19 and not game.simulation.bullets.is_empty(), "Holding the gun through a gameplay frame emits an actual volley")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.position = fire
	event.pressed = false
	game._input(event)
	game._unhandled_input(event)
	check(game.fire_index == 1 and game.pointer_index == 0 and game.fire_held, "Synthetic mouse release cannot release either native finger")
	touch(game, 2, fire, true)
	touch(game, 2, fire, false)
	check(game.fire_index == 1 and game.pointer_index == 0, "An unrelated finger cannot replace or release an active owner")
	touch(game, 1, Vector2(530, 700), false)
	check(not game._fire_input() and game.joystick.x > .9 and game.pointer_index == 0, "Fire release outside its button stops fire and preserves movement")
	game.simulation.fire_clock = 0.0
	game._process(.05)
	check(game.simulation.ammo == 19, "Released fire never leaks a later volley even with a ready cooldown")
	touch(game, 1, fire, true)
	touch(game, 0, Vector2(145, 650), false, true)
	check(game.pointer_index == -1 and game.joystick == Vector2.ZERO and game.fire_held, "Movement cancellation does not release fire")
	touch(game, 1, fire, true, true)
	check(game.fire_index == -1 and not game._fire_input(), "Canceled fire touch clears held and queued firing")
	touch(game, 1, fire, true)
	touch(game, 1, fire, false)
	game._process(0.0)
	check(game.simulation.ammo == 19 and not game.fire_request, "A sub-frame tap intentionally does not fire: control requires a held frame")
	touch(game, 1, fire, true)
	game._show_pause()
	check(not game.fire_held and game.fire_index == -1 and game.pointer_index == -1, "Pause clears all held touch state")
	game.screen = "arena"
	game.paused = false
	game._build_arena_ui()
	game.simulation.reload_left = 1.2
	game.simulation.ammo = 0
	services.active = true
	var before := {"elapsed":game.simulation.elapsed, "ammo":game.simulation.ammo,"reload":game.simulation.reload_left,"fire":game.simulation.fire_clock,"hp":game.simulation.hp}
	for frame in range(120): game._process(.05)
	var after := {"elapsed":game.simulation.elapsed, "ammo":game.simulation.ammo,"reload":game.simulation.reload_left,"fire":game.simulation.fire_clock,"hp":game.simulation.hp}
	check(before == after and not game.fire_held, "Fullscreen cover freezes combat, ammo and reload while dropping input")
	services.active = false
	game._process(40.0)
	check(game.simulation.reload_left == 1.2, "First uncovered delta is discarded instead of consuming reload")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game._process(3.0)
	check(game.paused and game.screen == "pause" and game.simulation.reload_left == 1.2, "Background return preserves explicit pause and reload")
	check(game._waiting_for_neutral_fire and game._waiting_for_neutral_movement and game._waiting_for_neutral_dash, "Lifecycle return requires neutral keyboard fire/movement/dash before rearming")
	game.screen = "arena"
	game.paused = false
	game._build_arena_ui()
	game._process(0.0)
	check(not game._waiting_for_neutral_fire and not game._waiting_for_neutral_movement and not game._waiting_for_neutral_dash, "Neutral released keyboard rearms all three input paths")
	check(game._fire_keyboard_input(true) and game._movement_from_keyboard(Vector2.LEFT, true).x < 0 and game._dash_keyboard_input(true), "Fresh keyboard state deliberately requests fire, movement and dash")
	game._release_stick()
	check(not game._fire_keyboard_input(true) and game._movement_from_keyboard(Vector2.LEFT, true) == Vector2.ZERO and not game._dash_keyboard_input(true), "Keys held across a pause cannot rearm fire, movement or dash")
	game._fire_keyboard_input(false)
	game._movement_from_keyboard(Vector2.ZERO, false)
	game._dash_keyboard_input(false)
	check(not game._waiting_for_neutral_fire and not game._waiting_for_neutral_movement and not game._waiting_for_neutral_dash, "Releasing held keys clears the neutral latch")
	check(game._fire_keyboard_input(true), "A fresh J state fires after neutral rearm")
	game.fire_button.button_down.emit()
	check(game.fire_index == -2 and game.fire_held, "Real mouse button-down deliberately owns fire")
	event.device = 0
	game._input(event)
	check(game.fire_index == -1 and not game.fire_held, "Real mouse release outside the button stops fire")
	game.pointer_index = -2
	game.joystick = Vector2.RIGHT
	game._input(event)
	check(game.pointer_index == -1 and game.joystick == Vector2.ZERO, "Real mouse release clears movement before GUI can consume it")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.screen == "pause" and not game.fire_held, "Focus loss neutralizes input and pauses the run")
	game.queue_free()
	services.queue_free()
	await process_frame

func _test_viewports() -> void:
	var original_size := root.size
	var original_aspect := root.content_scale_aspect
	var original_canvas := root.content_scale_size
	# Headless physical resizes keep the original logical canvas. Configure
	# this test Window's real logical viewport explicitly, not a fake layout
	# helper argument. This does not prove Android aspect behavior or modify
	# project.godot; all Window settings are restored below.
	for physical in [Vector2i(1080,1920), Vector2i(1200,1920), Vector2i(1600,2560)]:
		var expected_height := 960.0 if physical.x == 1080 else 864.0
		root.content_scale_size = Vector2i(540, int(expected_height))
		root.size = physical
		await process_frame
		var actual := root.get_visible_rect()
		check(is_equal_approx(actual.size.x, 540.0) and is_equal_approx(actual.size.y, expected_height), "Configured actual root logical viewport is exposed for profile " + str(physical))
		var services := ServicesStub.new()
		root.add_child(services)
		var game = load("res://main.tscn").instantiate()
		game.qa = true
		root.add_child(game)
		game.set_process(false)
		game.services = services
		game._start_run()
		game._process(0.0)
		check(game.menu_scroll.size.y == expected_height, "Arena input container fits actual viewport height")
		for button in [game.fire_button, game.reload_button, game.dash_button, game.pause_button]:
			check(actual.encloses(button.get_global_rect()), "Combat control remains fully reachable: " + button.text)
		check(game.fire_button.size == Vector2(160,64) and game.reload_button.size == Vector2(132,47) and game.dash_button.size == Vector2(160,64), "Short viewports retain full-size touch targets")
		check(not game.fire_button.get_rect().intersects(game.reload_button.get_rect()) and not game.fire_button.get_rect().intersects(game.dash_button.get_rect()) and not game.reload_button.get_rect().intersects(game.dash_button.get_rect()), "Responsive fire/reload/dash hit areas do not overlap")
		check(game.dash_button.get_rect().end.x + 12.0 == game.fire_button.position.x and game.dash_button.position.y == game.fire_button.position.y and game.dash_button.size == game.fire_button.size, "Round Five DASH is immediately left of FIRE with matching large touch targets")
		check(not game.fire_hint.get_rect().intersects(game.dash_button.get_rect()) and not game.fire_hint.get_rect().intersects(game.reload_button.get_rect()), "Fire hint stays clear of moved DASH and RELOAD touch targets")
		check(actual.encloses(game.ammo_label.get_global_rect()), "Ammo and reload HUD stays inside actual viewport")
		var world: Transform2D = game._arena_world_transform()
		var mapped: Rect2 = world * Survival.ARENA
		check(is_equal_approx(world.x.length(), world.y.length()) and is_equal_approx(mapped.position.y, 145.0) and mapped.end.y <= expected_height - 174.99, "Entire world uses a uniform fit above the full-size footer")
		check(Survival.ARENA == Rect2(20,145,500,640) and actual.encloses(mapped), "World fit changes no simulation bounds and clips no arena edge")
		for entry in [{"kind":"player","point":Vector2(502,767)}, {"kind":"enemy","point":Vector2(20,145)}, {"kind":"projectile","point":Vector2(520,145)}, {"kind":"hazard","point":Vector2(270,600)}, {"kind":"pickup","point":Vector2(520,785)}]:
			var point: Vector2 = entry.point
			var screen_point := world * point
			check(actual.has_point(screen_point) and (world.affine_inverse() * screen_point).is_equal_approx(point), "Shared world mapping preserves %s at its arena edge" % entry.kind)
		var start := Vector2(80, expected_height - 120.0)
		touch(game, 0, start, true)
		drag(game, 0, start + Vector2(65,0))
		touch(game, 1, game.fire_button.get_global_rect().get_center(), true)
		game._process(.01)
		check(game.pointer_index == 0 and game.fire_index == 1 and game.joystick.x > .9 and game.simulation.ammo == 19, "Actual viewport gun hit test and independent movement emit a volley")
		touch(game, 1, game.fire_button.get_global_rect().get_center(), false)
		touch(game, 2, game.reload_button.get_global_rect().get_center(), true)
		check(is_equal_approx(game.simulation.reload_left,1.65) and game.pointer_index == 0, "Actual viewport RELOAD hit test preserves movement owner")
		touch(game, 3, game.dash_button.get_global_rect().get_center(), true)
		check(game.simulation.dashes == 1 and game.pointer_index == 0, "Actual viewport DASH hit test preserves movement owner")
		touch(game, 4, game.pause_button.get_global_rect().get_center(), true)
		check(game.screen == "pause" and game.pointer_index == -1 and game.fire_index == -1, "Actual viewport pause hit test clears both control owners")
		print("MONSTER_VIEWPORT physical=",physical," logical=",actual.size," fire=",game.fire_button.get_rect()," reload=",game.reload_button.get_rect()," dash=",game.dash_button.get_rect()," world=",mapped)
		game.queue_free()
		services.queue_free()
		await process_frame
	root.content_scale_aspect = original_aspect
	root.content_scale_size = original_canvas
	root.size = original_size
	await process_frame
