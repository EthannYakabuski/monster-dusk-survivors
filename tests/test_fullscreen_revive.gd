extends SceneTree
## Isolated presentation regression with explicit fake lifecycle events.
## No SDK reward, normal profile, capture imagery or native acceptance is claimed.

class ServicesStub extends Node:
	var active := false
	var callback := Callable()
	var last_callback := Callable()
	var reward_calls := 0
	func fullscreen_ad_active() -> bool: return active
	func can_reward() -> bool: return not active
	func reward_requested(_context: String, supplied: Callable) -> void:
		reward_calls += 1
		active = true
		callback = supplied
		last_callback = supplied
	func earn() -> void:
		var earned_callback := callback
		callback = Callable()
		if earned_callback.is_valid(): earned_callback.call(true)
	func close() -> void:
		active = false
		var unearned_callback := callback
		callback = Callable()
		if unearned_callback.is_valid(): unearned_callback.call(false)
	func set_menu_visible(_visible: bool) -> void: pass
	func round_finished() -> void: pass
	func unlock(_key: String) -> void: pass
	func submit(_key: String, _value: int) -> void: pass

var checks := 0
var failures: Array[String] = []
var game: Node
var services: ServicesStub

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func dead_run() -> void:
	game._start_run()
	game.simulation.elapsed = 61.0
	game.simulation.kills = 53
	game.simulation.wave = 3
	game.simulation.alive = false
	game.simulation.hp = 0.0
	game._show_results()

func combat_snapshot() -> Dictionary:
	var sim = game.simulation
	return {"result": sim.result(), "hp": sim.hp, "protection": sim.invulnerability,
		"cooldown": sim.dash_cooldown, "spawn": sim.spawn_clock, "fire": sim.fire_clock,
		"position": sim.player, "enemies": sim.enemies.duplicate(true),
		"bullets": sim.bullets.duplicate(true), "hazards": sim.hazards.duplicate(true),
		"drops": sim.drops.duplicate(true), "save_clock": game.save_clock}

func _run() -> void:
	print("MONSTER_FULLSCREEN_TEST_USER_DIR ", OS.get_user_data_dir())
	var original_services := root.get_node_or_null("Services")
	if is_instance_valid(original_services): original_services.name = "ServicesFullscreenTestOriginal"
	services = ServicesStub.new()
	services.name = "Services"
	root.add_child(services) # Installed before game._ready: no live Services/profile writes.
	game = load("res://main.tscn").instantiate()
	game.qa = true
	root.add_child(game)
	game.set_process(false)
	check(game.services == services and game.qa, "Private fixture binds its no-persistence Services before ready")
	var adapter = load("res://platform/services.gd").new()
	check(not adapter.fullscreen_ad_active(), "Adapter is inactive with neither fullscreen presentation")
	adapter._reward_showing = true
	check(adapter.fullscreen_ad_active(), "Rewarded presentation reports active independent of load availability")
	adapter._reward_showing = false
	adapter._interstitial_showing = true
	check(adapter.fullscreen_ad_active(), "Interstitial presentation also suspends live combat")
	adapter._interstitial_showing = false
	check(not adapter.fullscreen_ad_active(), "Both close flags release the adapter gate")
	adapter.free() # Never added: its persistence/native initialization never runs.
	dead_run()
	game._request_revive()
	game._request_revive()
	check(services.reward_calls == 1 and game.reward_pending, "Repeated taps cannot request a second pending revive")
	services.earn()
	check(game.simulation.alive and game.simulation.continued and game.screen == "arena", "Earned event applies the revive once to its requested run")
	check(services.active and is_equal_approx(game.simulation.invulnerability, 3.5), "Revive keeps full protection while fullscreen presentation remains open")
	var before := combat_snapshot()
	game.joystick = Vector2.RIGHT
	game.pointer_index = 2
	game.simulation.movement = Vector2.RIGHT
	for frame in range(3000): game._process(1.0 / 60.0)
	check(combat_snapshot() == before, "Fifty seconds of covered frames change no combat/protection/cooldown or pending-summary state")
	check(game.joystick == Vector2.ZERO and game.pointer_index == -1, "Covered frames discard held movement")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(90, 700)
	game._unhandled_input(touch)
	game.simulation.movement = Vector2.RIGHT
	game._dash()
	check(game.pointer_index == -1 and game.simulation.dashes == 0, "Covered touch and DASH cannot move or spend a cooldown")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.screen == "arena" and not game.paused, "Covered Android back does not overwrite user pause state")
	services.last_callback.call(true)
	check(game.simulation.continued and is_equal_approx(game.simulation.invulnerability, 3.5), "Duplicate earned delivery cannot reset or consume the single revive")
	services.close()
	var elapsed: float = game.simulation.elapsed
	game._process(45.0)
	check(game.simulation.elapsed > elapsed and game.simulation.elapsed <= elapsed + 0.051, "Close resumes normal capped simulation without replaying covered time")
	check(game.simulation.alive and game.simulation.invulnerability >= 3.44, "Player returns alive with valuable revive protection")
	game._show_pause()
	services.active = true
	services.close()
	game._process(0.05)
	check(game.paused and game.screen == "pause", "Closing a fullscreen ad never clears the user's pause")
	dead_run()
	game._request_revive()
	services.close()
	check(not game.simulation.alive and not game.simulation.continued and game.screen == "results", "Unearned dismiss/show-failure grants nothing and leaves retry/bank available")
	dead_run()
	game._request_revive()
	services.earn()
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	services.close()
	before = combat_snapshot()
	game._process(30.0)
	check(combat_snapshot() == before and game.paused, "App background remains blocked even after fullscreen close")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game._process(0.05)
	check(combat_snapshot() == before and game.paused, "Foreground preserves the ordinary background pause until explicit resume")
	dead_run()
	game._request_revive()
	var stale := services.last_callback
	game._bank_run()
	game._start_run()
	game.simulation.alive = false
	game.simulation.hp = 0.0
	game._show_results()
	stale.call(true)
	services.close()
	check(not game.simulation.alive and not game.simulation.continued, "Late prior-run earned/close cannot revive a different run")
	game.queue_free()
	services.queue_free()
	await process_frame
	if is_instance_valid(original_services): original_services.name = "Services"
	print("MONSTER_FULLSCREEN_REVIVE checks=", checks, " failures=", failures.size(), " (isolated lifecycle stubs; no native SDK claim)")
	quit(0 if failures.is_empty() else 1)
