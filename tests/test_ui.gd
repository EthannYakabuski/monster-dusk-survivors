extends SceneTree

class ServicesStub extends Node:
	var menu_visible := false
	var completed_rounds := 0
	var reward_calls := 0
	var earned := false
	var deferred := false
	var pending_callback := Callable()
	var unlocked: Array[String] = []
	var boards: Dictionary = {}
	func set_menu_visible(value: bool) -> void: menu_visible = value
	func round_finished() -> void: completed_rounds += 1
	func can_reward() -> bool: return true
	func reward_requested(_context: String, callback: Callable) -> void:
		reward_calls += 1
		if deferred: pending_callback = callback
		else: callback.call(earned)
	func unlock(key: String) -> void: unlocked.append(key)
	func submit(key: String, value: int) -> void: boards[key] = value
	func open_achievements() -> void: pass
	func open_leaderboards(_key: String) -> void: pass
	func sign_in() -> void: pass
	func privacy_options() -> void: pass
	func status() -> String: return "QA"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button: found.append(child)
		found.append_array(buttons(child))
	return found

func press(game: Node, text: String) -> bool:
	for button in buttons(game.ui):
		if button.text == text and not button.disabled:
			button.pressed.emit()
			return true
	return false

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game = scene.instantiate()
	game.qa = true
	root.add_child(game)
	game.set_process(false)
	var services := ServicesStub.new()
	root.add_child(services)
	game.services = services
	game._show_home()
	check(game.screen == "home" and services.menu_visible, "Camp opens with the menu banner enabled")
	check(press(game, "Armory") and game.screen == "armory", "Camp armory button opens permanent upgrades")
	await process_frame
	check(buttons(game.ui).size() == 8, "Armory exposes four upgrades, three weapons and a return path")
	var upgraded := false
	for button in buttons(game.ui):
		if button.text.begins_with("Upgrade ") and not button.disabled:
			button.pressed.emit()
			upgraded = game.profile.upgrades.power == 1
			break
	check(upgraded, "An actual upgrade button spends coins and rebuilds the screen")
	press(game, "Back to camp")
	check(press(game, "Daily camp") and game.screen == "daily", "Daily menu is reachable through actual controls")
	await process_frame
	var gift_found := false
	for button in buttons(game.ui):
		if button.text.begins_with("Claim day"):
			button.pressed.emit()
			gift_found = true
			break
	check(gift_found and game.profile.login_streak == 1, "Daily gift control awards the first welcome gift")
	check(not press(game, "Gift already claimed"), "The claimed daily gift control is disabled")
	press(game, "Back to camp")
	check(press(game, "Field journal") and game.screen == "journal", "Bestiary and milestone journal can be opened")
	await process_frame
	check(game.ui.get_child_count() >= 4, "Journal builds its scrollable content and navigation")
	press(game, "Back to camp")
	check(press(game, "Records") and game.screen == "records", "Offline records can be opened")
	await process_frame
	check(buttons(game.ui).size() == 7, "Records include all five online boards, connect and back")
	game._show_settings()
	check(press(game, "Music: ON") and not game.profile.music_enabled, "Music preference toggles through the real button")
	check(press(game, "Effects: ON") and not game.profile.effects_enabled, "Effects preference toggles through the real button")
	game._show_home()
	check(press(game, "Enter the dusk") and game.screen == "arena" and not services.menu_visible, "Starting a run hides the menu banner")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(100, 600)
	game._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(160, 600)
	game._unhandled_input(drag)
	check(game.joystick.x > 0.8 and game.pointer_index == 0, "One-thumb dragging sets the movement vector")
	touch.pressed = false
	game._unhandled_input(touch)
	check(game.joystick == Vector2.ZERO and game.pointer_index == -1, "Lifting the thumb stops movement")
	game.simulation.movement = Vector2.RIGHT
	game.simulation.step(0.01)
	game.simulation.movement = Vector2.ZERO
	game._dash()
	check(game.simulation.dashes == 1 and game.simulation.dash_direction == Vector2.RIGHT, "One thumb can release movement and dash in its last direction")
	game.joystick = Vector2.RIGHT
	game.pointer_index = 0
	check(press(game, "II") and game.screen == "pause" and game.paused, "Pause button pauses the actual run")
	check(game.joystick == Vector2.ZERO and game.pointer_index == -1, "Pausing clears held touch state to prevent phantom movement")
	check(press(game, "Resume run") and game.screen == "arena" and not game.paused, "Pause back action resumes without discarding progress")
	game._show_pause()
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.screen == "arena" and not game.paused and not game.finalized, "Android back from pause resumes the same unbanked run")
	game.simulation.pending_cards = 1
	game._show_cards()
	check(game.screen == "cards" and buttons(game.ui).size() == 3 and not services.menu_visible, "Rank upgrade pauses to offer exactly three build choices")
	buttons(game.ui)[0].pressed.emit()
	check(game.screen == "arena" and game.simulation.pending_cards == 0, "Selecting a build card returns to combat")
	game.simulation.elapsed = 31
	game.simulation.kills = 12
	game.simulation.alive = false
	game.simulation.hp = 0
	game._show_results()
	check(game.screen == "results" and not services.menu_visible, "Death results are a distinct banner-free screen")
	services.earned = false
	game._request_revive()
	check(not game.simulation.alive and game.screen == "results", "An unearned ad callback cannot grant a continue")
	services.earned = true
	game._request_revive()
	check(game.simulation.alive and game.simulation.continued and game.screen == "arena", "An earned callback grants the single continue")
	game.simulation.alive = false
	game.simulation.hp = 0
	game._show_results()
	game._request_revive()
	check(services.reward_calls == 2 and not game.simulation.alive, "The second death cannot request another rewarded continue")
	check(press(game, "Bank run & return to camp") and game.screen == "home", "Death can bank earned progress and return to camp")
	var banked_coins: int = game.profile.coins
	game._bank_run()
	check(game.profile.runs == 1 and game.profile.kills == 12 and game.profile.coins == banked_coins, "Banking is idempotent at the presentation boundary")
	check(services.completed_rounds == 1 and services.boards.size() == 5, "Finished death reports one round and all five real score metrics")
	game._start_run()
	game.simulation.elapsed = 6
	game._bank_run()
	check(services.completed_rounds == 1, "Leaving a living run does not count as a death for interstitial cadence")
	game._start_run()
	game.simulation.elapsed = 10
	game.simulation.alive = false
	game._show_results()
	services.deferred = true
	game._request_revive()
	game._request_revive()
	check(services.reward_calls == 3, "Repeated taps cannot launch duplicate pending reward requests")
	game._bank_run()
	game._start_run()
	game.simulation.alive = false
	game._show_results()
	services.pending_callback.call(true)
	check(not game.simulation.alive and not game.simulation.continued, "A delayed ad callback cannot revive a different, later run")
	game.queue_free()
	services.queue_free()
	await process_frame
	print("MONSTER_DUSK_UI %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
