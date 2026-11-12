extends SceneTree
## SDK-free typed client doubles. Run only with process-isolated user data.
## These tests establish routing and recovery, not native/backend acceptance.

var Adapter: GDScript
var Main: GDScript
const Store = preload("res://game/save_store.gd")

# Compile typed doubles after autoload registration, as with the real clients.
const FAKE_SOURCE := """
extends RefCounted
class FakeSignIn extends PlayGamesSignInClient:
	var calls := 0
	func _ready() -> void: pass
	func sign_in() -> void: calls += 1
	func is_authenticated() -> void: pass

class FakeAchievements extends PlayGamesAchievementsClient:
	var calls: Array[String] = []
	var opened := 0
	func _ready() -> void: pass
	func unlock_achievement(id: String) -> void: calls.append(id)
	func show_achievements() -> void: opened += 1

class FakeBoards extends PlayGamesLeaderboardsClient:
	var calls: Array[Dictionary] = []
	var opened: Array[String] = []
	var all_opened := 0
	func _ready() -> void: pass
	func submit_score(id: String, score: int) -> void: calls.append({"id": id, "value": score})
	func show_leaderboard(id: String) -> void: opened.append(id)
	func show_all_leaderboards() -> void: all_opened += 1

"""

var checks := 0
var failures: Array[String] = []
var config: Dictionary
var catalog: Dictionary
var service: Node
var auth: Node
var achievements: Node
var boards: Node

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("MONSTER_PGS_TEST_USER_DIR ", OS.get_user_data_dir())
	config = JSON.parse_string(FileAccess.get_file_as_string("res://platform/config.json"))
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	Adapter = load("res://platform/services.gd")
	Main = load("res://game/main.gd")
	service = root.get_node("Services")
	_test_mapping()
	_test_fallback()
	_install_fakes()
	await _test_uploads()
	await _test_main()
	_test_persistence()
	await process_frame
	print("MONSTER_PLAY_GAMES_TESTS checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _test_mapping() -> void:
	var pgs: Dictionary = config.play_games
	check(pgs.enabled == true and pgs.game_id == "844390891698", "owner game ID is enabled")
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "export preset can be read")
	check(str(presets.get_value("preset.0.options", "godot_play_game_services/game_id", "")) == pgs.game_id, "Android export game ID matches runtime")
	var ids: Dictionary = {}
	var expected := {
		"achievements": ["first_light", "trail_keeper", "dusk_defender", "night_legend", "endless_lantern", "beyond_gate", "first_elite_wave", "ten_bells", "twenty_bells", "two_minute_watch", "five_minute_watch", "ten_minute_watch", "nimble_keeper", "dust_dancer", "elite_hunter", "elite_veteran", "bright_pockets", "walking_sunrise", "keeper_three", "keeper_six", "keeper_twelve", "naturalist", "field_scholar", "helping_hands", "camp_regular", "seven_lanterns", "well_equipped"],
		"leaderboards": ["best_wave", "best_seconds", "kills", "player_level", "seen"],
	}
	var suffixes := ["AQ", "Ag", "Aw", "BA", "BQ", "Bg", "Bw", "CA", "CQ", "Cg", "Cw", "DA", "DQ", "Dg", "Dw", "EA", "EQ", "Eg", "Ew", "FA", "FQ", "Fg", "Fw", "GA", "GQ", "Gg", "Gw", "HA", "HQ", "Hg", "Hw", "IA"]
	var index := 0
	for group in ["achievements", "leaderboards"]:
		check(pgs[group].size() == expected[group].size() and catalog[group].size() == expected[group].size(), "exact catalog/map count: " + group)
		var keys: Dictionary = {}
		for entry in catalog[group]: keys[entry.key] = true
		for key in expected[group]:
			check(keys.has(key) and pgs[group].has(key), "catalog and mapping contain " + key)
			var id: String = pgs[group].get(key, "")
			check(id == "CgkIsoH6zMkYEAIQ" + suffixes[index], "exact owner ID for " + key)
			check(not ids.has(id), "unique remote ID for " + key)
			ids[id] = true
			index += 1

func _test_fallback() -> void:
	check(not service._pgs_ready and not service._signed_in, "desktop never starts native Play Games")
	service.settings = config.duplicate(true)
	service.settings.play_games.enabled = false
	service._start_play_games()
	check(not service._pgs_ready and "saved locally" in service.status(), "disabled config retains local fallback")
	service.settings = config.duplicate(true)
	service._start_play_games()
	check(not service._pgs_ready, "missing native singleton does not initialize")
	service.sign_in()
	check("Local progress" in service.status(), "unavailable sign-in explains local fallback")
	service.open_achievements()
	check("Local achievements" in service.status(), "offline achievements explain fallback")
	service.open_leaderboards("best_wave")
	check("Local records" in service.status(), "offline board explains fallback")

func _install_fakes() -> void:
	var doubles := GDScript.new()
	doubles.source_code = FAKE_SOURCE
	check(doubles.reload() == OK, "typed test clients compile after autoloads")
	auth = doubles.FakeSignIn.new()
	achievements = doubles.FakeAchievements.new()
	boards = doubles.FakeBoards.new()
	service.add_child(auth)
	service.add_child(achievements)
	service.add_child(boards)
	service._sign_in_client = auth
	service._achievements_client = achievements
	service._leaderboards_client = boards
	auth.user_authenticated.connect(service._authentication_changed)
	achievements.achievement_unlocked.connect(service._achievement_uploaded)
	boards.score_submitted.connect(service._score_uploaded)
	service._pgs_ready = true
	service._pending_unlocks.clear()
	service._pending_scores.clear()

func _test_uploads() -> void:
	for key in config.play_games.achievements: service.unlock(key)
	for key in config.play_games.leaderboards:
		service.submit(key, 123)
		service.submit(key, 120)
	service.unlock("unknown")
	service.submit("unknown", 999)
	service.submit("kills", -1)
	await process_frame
	check(achievements.calls.is_empty() and boards.calls.is_empty(), "offline changes never dispatch")
	check(service._pending_unlocks.size() == 27 and service._pending_scores.size() == 5, "unknown keys and negative scores rejected")
	service.sign_in()
	check(auth.calls == 1 and "Connecting" in service.status(), "manual sign-in delegates and updates status")
	auth.user_authenticated.emit(false)
	await process_frame
	check(boards.calls.is_empty() and "safe" in service.status(), "failed auth preserves local progress")
	auth.user_authenticated.emit(true)
	check(boards.calls.is_empty(), "authentication dispatch is deferred")
	await process_frame
	check(achievements.calls.size() == 27 and boards.calls.size() == 5, "one coalesced dispatch covers every mapping")
	for key in config.play_games.achievements:
		check(achievements.calls.count(config.play_games.achievements[key]) == 1, "unlock routed once: " + key)
	for key in config.play_games.leaderboards:
		var value := 123000 if key == "best_seconds" else 123
		check({"id": config.play_games.leaderboards[key], "value": value} in boards.calls, "score routed in correct units: " + key)
		check(service._pending_scores[key] == 123, "pending stores unconverted monotonic value: " + key)
	service._flush_pending()
	check(achievements.calls.size() == 27 and boards.calls.size() == 5, "in-flight dispatches are suppressed")
	for id in achievements.calls.duplicate(): achievements.achievement_unlocked.emit(true, id)
	for call in boards.calls.duplicate(): boards.score_submitted.emit(true, call.id)
	service._flush_pending()
	check(achievements.calls.size() == 27 and boards.calls.size() == 5, "successful callbacks suppress repeats")
	check(service._pending_unlocks.size() == 27 and service._pending_scores.size() == 5, "success retains durable history")
	auth.user_authenticated.emit(true)
	await process_frame
	check(achievements.calls.size() == 27 and boards.calls.size() == 5, "same-session resume suppresses successful repeats")
	check(Adapter._remote_score_value("best_seconds", 0) == 0 and Adapter._remote_score_value("best_seconds", 86400) == 86400000, "Duration conversion handles zero and maximum gameplay duration")
	var wave_id: String = config.play_games.leaderboards.best_wave
	service.submit("best_wave", 124)
	await process_frame
	service.submit("best_wave", 130)
	await process_frame
	check(boards.calls.size() == 6 and boards.calls.back().value == 124, "newer in-flight record waits for original callback")
	boards.score_submitted.emit(true, wave_id)
	await process_frame
	check(boards.calls.size() == 7 and boards.calls.back().value == 130, "newer score dispatches after successful callback")
	boards.score_submitted.emit(false, wave_id)
	await process_frame
	check(boards.calls.size() == 7 and "retry" in service.status(), "failed score does not hot-loop")
	service._flush_pending()
	check(boards.calls.size() == 8 and boards.calls.back().value == 130, "next flush retries failed record")
	boards.score_submitted.emit(true, wave_id)
	for key in config.play_games.leaderboards:
		service.open_leaderboards(key)
		check(boards.opened.back() == config.play_games.leaderboards[key], "specific board opens: " + key)
	service.open_leaderboards()
	service.open_leaderboards("unknown")
	service.open_achievements()
	check(boards.all_opened == 2 and achievements.opened == 1, "all boards and achievement UI route correctly")
	auth.user_authenticated.emit(false)
	achievements.achievement_unlocked.emit(true, "unrelated")
	boards.score_submitted.emit(true, wave_id)
	check(service._uploaded_scores.is_empty(), "signed-out callbacks ignored")
	auth.user_authenticated.emit(true)
	await process_frame
	check(achievements.calls.size() == 54 and boards.calls.size() == 13, "new session reconciles complete durable history")
	var achievement_id: String = config.play_games.achievements.first_light
	achievements.achievement_unlocked.emit(false, achievement_id)
	await process_frame
	check(achievements.calls.size() == 54, "failed achievement does not hot-loop")
	service._flush_pending()
	check(achievements.calls.size() == 55 and achievements.calls.back() == achievement_id, "failed achievement retries on next sync")
	auth.user_authenticated.emit(false)
	service._pending_unlocks.clear()
	service._pending_scores.clear()

func _test_main() -> void:
	var game: Node = Main.new()
	game.qa = true
	game.profile.achieved = {"night_legend": true, "unknown": true}
	game.profile.kills = 10
	game.profile.best_seconds = 321
	game.profile.xp = 310
	root.add_child(game)
	game.set_process(false)
	check(service._pending_unlocks.has("night_legend"), "startup reconciles historical achievement below current threshold")
	check(service._pending_unlocks.has("first_light") and not service._pending_unlocks.has("unknown"), "startup reconciles new achievements but ignores unknown history")
	for entry in catalog.leaderboards:
		check(service._pending_scores.get(entry.key) == game.profile.metric(entry.metric), "startup syncs current profile score: " + str(entry.key))
	service._set_notice("Test service notice")
	check(game.toast_text == "Test service notice", "native status signal reaches game toast")
	game.profile.daily.kills = game.profile.DAILY_GOALS.kills
	game._show_daily()
	var claimed := false
	for node in game.find_children("*", "Button", true, false):
		if node.text == "Claim quest" and not node.disabled:
			node.pressed.emit()
			claimed = true
			break
	check(claimed and game.profile.level() == 3, "real daily quest button crosses keeper level threshold")
	check(service._pending_scores.get("player_level") == 3 and service._pending_unlocks.has("keeper_three"), "daily quest immediately syncs level board and achievement")
	check(not FileAccess.file_exists(Main.SAVE_PATH), "QA fixture never writes gameplay save")
	game.queue_free()
	await process_frame

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "fixture opens isolated file")
	if file:
		file.store_string(content)
		file.close()

func _load_fixture(primary: String, backup: String = "null") -> Node:
	_write(Adapter.PENDING_PATH, primary)
	_write(Adapter.PENDING_BACKUP_PATH, backup)
	var fixture: Node = Adapter.new()
	fixture.settings = config.duplicate(true)
	fixture._load_pending()
	return fixture

func _test_persistence() -> void:
	var legacy := {"unlocks": {"first_light": true, "trail_keeper": false, "unknown": true, "dusk_defender": "true"}, "scores": {"best_seconds": 321, "best_wave": 12.9, "kills": -2, "seen": "90", "player_level": 1.0e20, "unknown": 42}}
	var fixture := _load_fixture(JSON.stringify(legacy))
	check(fixture._pending_unlocks == {"first_light": true}, "legacy load filters invalid and unknown achievements")
	check(fixture._pending_scores == {"best_seconds": 321, "best_wave": 12}, "legacy load filters types/range and keeps integer seconds")
	fixture._save_pending()
	var saved: Dictionary = Store.decode(FileAccess.get_file_as_string(Adapter.PENDING_PATH))
	check(saved.schema == 1 and saved.scores.best_seconds == 321, "legacy queue migrates to schema without converting seconds")
	fixture._pending_scores.best_seconds = 400
	fixture._save_pending()
	var backup: Dictionary = Store.decode(FileAccess.get_file_as_string(Adapter.PENDING_BACKUP_PATH))
	check(backup.scores.best_seconds == 321, "SaveStore preserves previous valid snapshot")
	fixture.free()
	var valid := JSON.stringify({"schema": 1, "unlocks": {"first_light": true}, "scores": {"best_seconds": 77}})
	for malformed in ["{broken", "null", "[]", "42", '{"unlocks": [], "scores": {}}', '{"unlocks": {}, "scores": "bad"}']:
		fixture = _load_fixture(malformed, valid)
		check(fixture._pending_scores.get("best_seconds") == 77 and fixture._pending_unlocks.has("first_light"), "malformed primary recovers backup: " + malformed)
		fixture.free()
	fixture = _load_fixture("{broken", "{also broken")
	check(fixture._pending_scores.is_empty() and fixture._pending_unlocks.is_empty(), "two invalid files safely produce empty queue")
	fixture.free()
	fixture = _load_fixture(valid, JSON.stringify({"scores": {"best_seconds": 999}}))
	check(fixture._pending_scores.best_seconds == 77, "valid primary has precedence over backup")
	fixture.free()
