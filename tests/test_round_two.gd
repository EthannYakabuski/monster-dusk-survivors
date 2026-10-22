extends SceneTree
## Synthetic regression, isolated from genuine saves/native SDK evidence.

const Profile = preload("res://game/profile.gd")
const Cycle = preload("res://game/dusk_cycle.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var original = Profile.new()
	original.coins = 12345
	original.xp = 7654
	original.upgrades = {"power":9,"vitality":7,"tempo":5,"magnet":10}
	original.owned_weapons = ["repeater","scatter","lantern"]
	original.selected_weapon = "lantern"
	original.achieved = {"keeper_six":true,"well_equipped":true}
	original.daily_day = 200
	original.daily_claimed = {"kills":true,"survival":false,"dashes":false}
	original.login_day = 200
	original.login_streak = 6
	original.music_enabled = false
	var old_data: Dictionary = original.to_data()
	var restored = Profile.new()
	check(restored.load_data(old_data), "Legacy schema remains loadable")
	var migrated_data := old_data.duplicate(true)
	migrated_data.upgrades.magazine = 0
	check(restored.to_data() == migrated_data, "Legacy coins, XP, equipment, ranks, achievements and claims remain exact")
	check(restored.level() == original.level(), "Existing keeper level is not reduced by new reward pace")
	var fresh = Profile.new()
	check(fresh.purchase_upgrade("power") and fresh.coins == 0, "Starting allowance still buys one chosen first upgrade")
	for rank in range(10):
		fresh.upgrades.power = rank
		var historical := 80 + rank*90 + rank*rank*18
		check(fresh.upgrade_cost("power") >= historical * 2.25, "Future upgrade prices are materially slower at rank %d" % rank)
	var receipt: Dictionary = restored.record_run({"seconds":125,"kills":42,"wave":6})
	check(receipt.xp == 106 and receipt.xp < 219 * .5, "Representative future run earns under half the original XP")
	check(restored.xp == 7654+106 and restored.upgrades == migrated_data.upgrades, "Banking adds future XP without modifying legacy purchases")
	check(restored.claim_login(200) == 0 and restored.claim_quest("kills") == 0, "New pacing cannot reopen previously claimed rewards")
	for second in [0.0,30.0,60.0,90.0]:
		check(Cycle.sample(second).name == ["Dusk","Night","Dawn","Day"][int(second/30)], "Cycle shows distinct phase at %d seconds" % second)
	check(Cycle.sample(0) == Cycle.sample(120) and Cycle.sample(7.5) == Cycle.sample(127.5), "Cycle loops deterministically")
	check(Cycle.sample(30).lantern > Cycle.sample(90).lantern, "Lantern presentation strengthens at night")
	check(Cycle.sample(29.999).ground.is_equal_approx(Cycle.sample(30).ground), "Phase boundary interpolates continuously")
	_test_music_files()
	var game = load("res://main.tscn").instantiate()
	game.qa = true
	root.add_child(game)
	game.set_process(false)
	check(game._music_policy().context == "camp" and game._music_policy().enabled, "Menu policy enables music with its saved preference")
	game._show_armory()
	game._sync_music()
	check(game._music_policy().context == "camp", "Menu navigation retains one camp track")
	game._start_run()
	game._sync_music()
	check(game._music_policy().context == "patrol" and not game._music_policy().paused, "Gameplay selects the distinct patrol score")
	game.simulation.elapsed = 31.0
	game._refresh_hud()
	check("Night" in game.hud_wave.text, "Gameplay HUD communicates the real simulation phase")
	game._show_pause()
	game._sync_music()
	var before: float = game.simulation.elapsed
	game._process(20.0)
	check(game._music_policy().paused and game.simulation.elapsed == before, "Pause freezes cycle and suspends gameplay music")
	game.profile.music_enabled = false
	game._sync_music()
	check(not game._music_policy().enabled, "Music preference disables the playback policy")
	game.profile.music_enabled = true
	game._show_home()
	game._sync_music()
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game._music_policy().paused, "Application backgrounding suspends even menu music")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not game._music_policy().paused, "Menu music resumes after foreground return")
	game.queue_free()
	await process_frame
	game = null
	print("MONSTER_ROUND_TWO checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_music_files() -> void:
	for file in ["camp_watch.wav","dusk_patrol.wav"]:
		var stream = load("res://assets/audio/"+file)
		check(stream is AudioStreamWAV and stream.get_length() >= 39.9, "Composed BGM has complete 40-second arrangement: "+file)
		check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "BGM loops natively without restart callback: "+file)
