extends SceneTree

const Profile = preload("res://game/profile.gd")
const Survival = preload("res://game/survival.gd")
const SaveStore = preload("res://game/save_store.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func arena(seed_value: int = 993) -> RefCounted:
	var result = Survival.new()
	result.start(Profile.new(), seed_value)
	result.enemies.clear()
	result.spawn_clock = 999.0
	result.fire_clock = 999.0
	return result

func _run() -> void:
	_test_progression()
	_test_daily()
	_test_validation()
	_test_storage()
	_test_combat()
	_test_weapons()
	_test_spawning()
	_test_catalog()
	print("MONSTER_DUSK_MODELS %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_progression() -> void:
	var p = Profile.new()
	check(p.level() == 1 and p.coins == 180, "A new keeper has a usable starting allowance")
	check(not p.purchase_upgrade("unknown"), "Unknown purchases are rejected")
	check(p.purchase_upgrade("power"), "First upgrade can be purchased")
	check(p.coins == 0 and p.upgrades.power == 1, "Purchase deducts its price once")
	check(p.bullet_damage() > 13.0, "Permanent powder improves actual bullet damage")
	check(not p.purchase_upgrade("power") and p.coins == 0, "Insufficient funds cannot buy a second level")
	check(not p.unlock_weapon("scatter"), "Weapon level gates cannot be skipped")
	p.xp = 320
	p.coins = 1000
	check(p.level() == 3, "Keeper level uses permanent XP thresholds")
	check(p.unlock_weapon("scatter") and p.selected_weapon == "scatter", "Scatter unlocks at level three")
	check(p.coins == 750, "Scatter unlock charges 250 coins")
	check(p.unlock_weapon("repeater") and p.unlock_weapon("scatter") and p.coins == 750, "Equipping an owned weapon is free")
	check(not p.unlock_weapon("lantern"), "Moon lantern remains locked before level six")
	p.xp = 2000
	check(p.level() == 6 and p.unlock_weapon("lantern"), "Moon lantern becomes usable at level six")
	p.coins = 200000
	for index in range(15): p.purchase_upgrade("vitality")
	check(p.upgrades.vitality == 10 and p.upgrade_cost("vitality") == -1, "Permanent upgrades have a real maximum")
	check(p.maximum_health() == 220.0, "Health upgrades affect the run loadout")
	var empty = Profile.new()
	var receipt: Dictionary = empty.record_run({"seconds": 2, "kills": 0})
	check(not receipt.recorded and empty.coins == 180 and empty.runs == 0, "Immediate abandoned runs cannot farm currency")
	empty.roll_day(50)
	receipt = empty.record_run({"seconds": 125, "kills": 42, "wave": 6, "dashes": 9, "elites": 1, "powerups": 2, "kind_kills": {"slow": 30, "fast": 12}, "seen": [4, 4, 99]})
	check(receipt.recorded and empty.runs == 1 and empty.kills == 42, "Banking records earned combat progress")
	check(empty.best_wave == 6 and empty.best_seconds == 125, "Banking records survival personal bests")
	check(empty.daily.kills == 42 and empty.daily.survival == 125 and empty.daily.dashes == 9, "Run results advance all three daily quests")
	check(empty.kind_kills.slow == 30 and empty.kind_kills.fast == 12 and empty.seen.size() == 2, "Run banking retains enemy mastery and unique sightings")
	check(receipt.coins == 166 + receipt.levels * 70 and receipt.xp == 106, "Coin, XP and level rewards match the published economy")
	var records_before := int(empty.best_seconds)
	empty.record_run({"seconds": 5, "kills": 1, "wave": 1})
	check(empty.best_seconds == records_before and empty.best_wave == 6, "Short later runs do not lower personal records")

func _test_daily() -> void:
	var p = Profile.new()
	check(p.roll_day(100), "First UTC day initializes daily quests")
	p.daily.kills = 40
	check(p.claim_quest("kills") == 160 and p.quests_claimed == 1, "Completed quests award currency and count")
	check(p.claim_quest("kills") == 0 and p.claim_quest("missing") == 0, "Quest rewards cannot be repeated or invented")
	check(not p.roll_day(99) and p.claim_quest("kills") == 0, "Clock rollback cannot reopen a daily reward")
	check(not p.roll_day(100) and p.daily.kills == 40, "Opening daily camp repeatedly preserves daily progress")
	check(p.roll_day(101) and p.daily.kills == 0 and p.daily_claimed.is_empty(), "Next UTC day resets quest progress and claims")
	check(p.claim_login(100) == 100 and p.claim_login(100) == 0, "Daily login gift is claimable once")
	check(p.claim_login(99) == 0, "Backdating the device clock cannot create another gift")
	for day in range(101, 107): p.claim_login(day)
	check(p.login_streak == 7 and p.coins == 2650, "Seven consecutive gifts reach the 750-coin final day")
	check(p.claim_login(107) == 100 and p.login_streak == 1, "The gift track wraps after day seven")
	check(p.claim_login(110) == 100 and p.login_streak == 1, "A missed day restarts the gift track")

func _test_validation() -> void:
	var p = Profile.new()
	check(not p.load_data(null) and not p.load_data([]) and not p.load_data("bad"), "Malformed save roots are rejected")
	check(p.load_data({"coins": -50, "xp": 1.0e100, "upgrades": {"power": 999, "tempo": -4}, "selected_weapon": "invented", "owned_weapons": ["bad", "scatter"], "seen": [1, 1, "bad", -4], "daily": "bad", "kind_kills": []}), "Partially malformed dictionaries are safely normalized")
	check(p.coins == 0 and p.xp == 1000000000 and p.upgrades.power == 10 and p.upgrades.tempo == 0, "Numeric save inputs are clamped before conversion")
	check(p.selected_weapon == "repeater" and p.seen == [1], "Unknown equipment and malformed sightings cannot enter the profile")
	check(Profile.safe_int(INF, 0, 10) == 0 and Profile.safe_int(NAN, 0, 10) == 0, "Non-finite values cannot contaminate progression")
	check(Profile.safe_int("99", 0, 10) == 0, "Strings are not silently accepted as numbers")
	var original = Profile.new()
	original.claim_login(987)
	original.roll_day(987)
	original.record_run({"seconds": 91, "kills": 35, "dashes": 7, "seen": [2, 17, 19]})
	var loaded = Profile.new()
	check(loaded.load_data(JSON.parse_string(JSON.stringify(original.to_data()))), "JSON roundtrip loads successfully")
	check(loaded.kills == 35 and loaded.seconds == 91 and loaded.coins == original.coins and loaded.seen == [2, 17, 19], "JSON float normalization preserves earned progress")
	check(loaded.daily == original.daily and loaded.login_day == 987 and loaded.selected_weapon == original.selected_weapon, "Daily and equipment state survive a save roundtrip")
	loaded.record_run({"seconds": 8, "kills": 1, "kind_kills": "bad", "seen": 7})
	check(loaded.runs == 2, "Malformed optional result fields cannot crash banking")

func _test_storage() -> void:
	var temporary_directory := OS.get_environment("TEMP")
	if temporary_directory.is_empty(): temporary_directory = "/tmp"
	var prefix := temporary_directory.path_join("monster_dusk_qa_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var primary := prefix + ".json"
	var backup := prefix + ".backup.json"
	var p = Profile.new()
	check(SaveStore.read(primary, backup).is_empty(), "Missing saves return an empty profile source")
	check(SaveStore.write(primary, backup, p.to_data()), "First save commits a complete primary file")
	p.coins = 321
	p.kills = 5
	check(SaveStore.write(primary, backup, p.to_data()), "Replacing an existing primary succeeds on this host")
	check(SaveStore.read(primary, backup).coins == 321, "Latest committed progress is read first")
	check(JSON.parse_string(FileAccess.get_file_as_string(backup)).coins == 180, "Previous valid save is retained as a backup")
	var broken := FileAccess.open(primary, FileAccess.WRITE)
	broken.store_string("{interrupted")
	broken.close()
	check(SaveStore.read(primary, backup).coins == 180, "A truncated primary recovers from the last valid backup")
	check(SaveStore.write(primary, backup, p.to_data()), "Recovery can replace the invalid primary")
	check(JSON.parse_string(FileAccess.get_file_as_string(backup)).coins == 180, "Invalid data never overwrites the valid backup")
	check(not FileAccess.file_exists(primary + ".tmp"), "A successful commit leaves no uncommitted temporary file")
	for path in [primary, backup, primary + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _test_combat() -> void:
	var s = arena()
	s.movement = Vector2(100, -100)
	for tick in range(300): s.step(1.0 / 30.0)
	check(Survival.ARENA.has_point(s.player) and s.player.y >= 163, "Long thumb input cannot leave the arena")
	s = arena()
	check(not s.dash(), "Dash cannot trigger without a movement direction")
	s.movement = Vector2.RIGHT
	check(s.dash() and not s.dash() and s.dashes == 1, "Dash triggers once and respects cooldown")
	var before: float = s.hp
	s.take_damage(99)
	check(s.hp == before, "Dash invulnerability protects the keeper")
	s.invulnerability = 0
	s.shield_left = 1
	s.take_damage(20)
	check(s.hp == before, "Shield powerup blocks combat damage")
	s.shield_left = 0
	s.take_damage(20)
	s.take_damage(20)
	check(is_equal_approx(s.hp, before - 24.0), "Hit recovery prevents same-frame damage stacking")
	s.invulnerability = 0
	s.take_damage(1000)
	check(not s.alive and s.hp == 0, "Lethal damage ends the run cleanly")
	check(s.continue_run() and s.hp == s.max_hp * 0.65, "Earned continue restores the advertised health")
	check(not s.continue_run(), "An active run cannot consume a second continue")
	s.invulnerability = 0
	s.take_damage(1000)
	check(not s.continue_run(), "A second death cannot receive another revive")
	s = arena()
	s.spawn_enemy("ranged", s.player + Vector2(70, 0))
	s.enemies[0].timer = 0.0
	var previous: float = s.enemies[0].pos.x
	s._move_enemies(0.05)
	check(s.enemies[0].pos.x > previous and s.bullets.size() == 1 and not s.bullets[0].friendly, "Spitters retreat and fire hostile shots")
	s = arena()
	s.spawn_enemy("magical", Vector2(80, 250))
	s.enemies[0].timer = 0.0
	s._move_enemies(0.01)
	check(s.hazards.size() == 1 and s.hazards[0].pos == s.player and s.hp == 100, "Hexlings telegraph a target before damage")
	s._update_hazards(1.0)
	check(s.hp == 100 and s.hazards.size() == 1, "A warning circle is harmless before its fuse expires")
	s._update_hazards(0.4)
	check(s.hp < 100 and s.hazards.is_empty(), "Expired hex warnings damage once and clear")
	s = arena()
	s.bullets.append({"pos": s.player, "vel": Vector2.ZERO, "damage": 13.0, "friendly": false, "life": 1.0, "radius": 7.0, "pierce": 0})
	s._move_bullets(0.01)
	check(is_equal_approx(s.hp, 84.4) and s.bullets.is_empty(), "Hostile projectiles damage the keeper and are consumed")
	s = arena()
	s.hp = 50
	s._apply_pickup("heal")
	s._apply_pickup("haste")
	s._apply_pickup("shield")
	check(s.hp == 78 and s.haste_left == 7 and s.shield_left == 4 and s.powerups_collected == 3, "Combat powerups apply meaningful, distinct effects")
	s._apply_pickup("xp", 60)
	check(s.rank == 3 and s.pending_cards == 2 and s.run_xp == 6, "XP can earn multiple rank choices without losing overflow")
	var frozen: float = s.elapsed
	s.step(0.05)
	check(s.elapsed == frozen, "Upgrade selection pauses combat and survival time")
	check(s.choose_card("spread") and s.cards.spread == 1 and s.pending_cards == 1, "A run choice consumes one earned selection")
	check(not s.choose_card("invented"), "Unknown cards cannot consume an upgrade choice")
	s.choose_card("mend")
	check(s.hp == 100 and s.pending_cards == 0, "Mend restores health up to the maximum")
	s = arena()
	s.spawn_enemy("slow", s.player + Vector2(25, 0))
	s.spawn_enemy("tank", s.player + Vector2(400, 0))
	s._apply_pickup("nova")
	check(s.kills == 1 and s.enemies.size() == 1 and s.kind_kills.slow == 1, "Nova defeats nearby vulnerable enemies but preserves distant enemies")
	check(s.drops.size() >= 1 and s.drops[0].kind == "xp", "Defeating monsters creates collectible run XP")

func _test_weapons() -> void:
	var s = arena()
	s.spawn_enemy("slow", s.player + Vector2(100, 0))
	s.fire_clock = 0
	s._fire(0.01, true)
	check(s.bullets.size() == 1 and s.bullets[0].vel.x > 0, "A deliberately fired repeater aims at the nearest monster")
	for tick in range(30):
		s._move_bullets(1.0 / 60.0)
	check(s.enemies.size() == 1 and s.enemies[0].hp < s.enemies[0].max_hp, "Friendly bullets deal actual collision damage")
	s = arena()
	s.weapon = "scatter"
	s.spawn_enemy("slow", s.player + Vector2(100, 0))
	s.fire_clock = 0
	s._fire(0.01, true)
	check(s.bullets.size() == 3 and s.bullets[0].vel != s.bullets[1].vel, "Scatter creates three divergent projectiles")
	s = arena()
	s.weapon = "lantern"
	s.spawn_enemy("slow", s.player + Vector2(100, 0))
	s.fire_clock = 0
	s._fire(0.01, true)
	check(s.bullets.size() == 1 and s.bullets[0].pierce == 1 and is_equal_approx(s.bullets[0].damage, 13 * .75 * 1.25), "Moon lantern supplies stronger piercing shots")
	s.bullets.clear()
	s.cards.spread = 3
	s.fire_clock = 0
	s._fire(0.01, true)
	check(s.bullets.size() == 4, "Run spread cards change the actual weapon build")

func _test_spawning() -> void:
	check(Survival.PROFILES.size() == 6, "Six mechanical enemy profiles exist")
	check(Survival.PROFILES.fast.speed > Survival.PROFILES.slow.speed and Survival.PROFILES.tank.hp > Survival.PROFILES.slow.hp, "Fast and tank enemies differ mechanically")
	check(Survival.PROFILES.glass.damage > Survival.PROFILES.tank.damage and Survival.PROFILES.glass.hp < Survival.PROFILES.slow.hp, "Glass cannons trade health for threatening contact damage")
	var s = arena(88)
	var kinds: Dictionary = {}
	for index in range(200): kinds[s.choose_kind()] = true
	check(kinds.size() == 2 and kinds.has("slow") and kinds.has("fast"), "Opening waves introduce only the first two enemy families")
	s.wave = 5
	kinds.clear()
	for index in range(200): kinds[s.choose_kind()] = true
	check(kinds.size() == 6, "All six enemy families enter the wave-five spawn pool")
	s.elapsed = 88
	s.step(0.01)
	check(s.wave == 5 and s.enemies.size() == 1 and s.enemies[0].elite, "Every fifth wave introduces a stronger elite")
	s.step(0.01)
	check(s.enemies.size() == 1, "The elite wave does not spawn a new elite every frame")
	for index in range(200): s.spawn_enemy("slow")
	check(s.enemies.size() == 90, "Enemy population remains bounded during endless survival")
	var a = Survival.new()
	var b = Survival.new()
	a.start(Profile.new(), 45912)
	b.start(Profile.new(), 45912)
	a.invulnerability = 999
	b.invulnerability = 999
	# The slower, tougher Round Three balance needs a longer full-session fixture.
	for frame in range(4000):
		var direction := Vector2(sin(frame * 0.03), cos(frame * 0.02))
		a.movement = direction
		b.movement = direction
		if a.pending_cards > 0: a.choose_card("power")
		if b.pending_cards > 0: b.choose_card("power")
		a.step(1.0 / 30.0, true)
		b.step(1.0 / 30.0, true)
		a.events.clear()
		b.events.clear()
	print("MONSTER_DETERMINISTIC seconds=", a.elapsed, " kills=", a.kills, " rank=", a.rank)
	check(a.result() == b.result() and a.player == b.player and a.enemies == b.enemies, "Fixed seed and inputs produce identical combat, drops and spawning")
	check(a.elapsed > 120 and a.wave >= 6 and a.kills > 10 and a.rank > 1, "A complete deterministic session progresses through waves, combat and upgrades")
	check(a.enemies.size() <= 90 and a.bullets.size() < 200 and a.drops.size() < 400, "Sustained combat keeps active object counts bounded")

func _test_catalog() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	check(catalog.achievements.size() == 27 and catalog.leaderboards.size() == 5, "All documented achievements and boards are packaged")
	var keys: Dictionary = {}
	for item in catalog.achievements:
		check(not keys.has(item.key) and int(item.threshold) > 0, "Achievement key is unique and has a real threshold: " + str(item.key))
		keys[item.key] = true
	var p = Profile.new()
	p.kills = 100
	p.best_wave = 5
	var earned: Array = p.check_achievements(catalog)
	check("first_light" in earned and "trail_keeper" in earned and "first_elite_wave" in earned and "night_legend" not in earned, "Only achieved thresholds unlock")
	check(p.check_achievements(catalog).is_empty(), "Achievement unlocks are emitted once")
	for index in [0, 48, 137, 199]:
		check(ResourceLoader.exists("res://assets/creatures/creature_%03d.png" % index), "Creature source is available: " + str(index))
