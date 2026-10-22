extends RefCounted
## Durable local progression. Currency is never granted merely for opening an ad.

const UPGRADE_KEYS := ["power", "vitality", "tempo", "magnet", "magazine"]
const WEAPONS := ["repeater", "scatter", "lantern"]
const DAILY_GOALS := {"kills": 40, "survival": 120, "dashes": 8}
const LOGIN_REWARDS := [100, 150, 210, 280, 360, 460, 750]
var coins: int = 180
var xp: int = 0
var kills: int = 0
var seconds: int = 0
var runs: int = 0
var best_wave: int = 1
var best_seconds: int = 0
var dashes: int = 0
var elites: int = 0
var powerups: int = 0
var quests_claimed: int = 0
var selected_weapon: String = "repeater"
var upgrades: Dictionary = {"power": 0, "vitality": 0, "tempo": 0, "magnet": 0, "magazine": 0}
var owned_weapons: Array = ["repeater"]
var kind_kills: Dictionary = {"slow": 0, "fast": 0, "tank": 0, "glass": 0, "ranged": 0, "magical": 0}
var seen: Array = []
var achieved: Dictionary = {}
var daily_day: int = -1
var daily: Dictionary = {"kills": 0, "survival": 0, "dashes": 0}
var daily_claimed: Dictionary = {}
var login_day: int = -1
var login_streak: int = 0
var music_enabled: bool = true
var effects_enabled: bool = true

func level() -> int:
	return 1 + int(floor(sqrt(float(xp) / 80.0)))

func next_level_xp() -> int:
	return level() * level() * 80

func maximum_health() -> float:
	return 100.0 + 12.0 * int(upgrades.vitality)

func bullet_damage() -> float:
	return 13.0 + 2.7 * int(upgrades.power)

func fire_interval() -> float:
	return maxf(0.19, 0.46 - 0.022 * int(upgrades.tempo))

func magazine_capacity() -> int:
	return 20 + 2 * int(upgrades.magazine)

func pickup_radius() -> float:
	return 35.0 + 11.0 * int(upgrades.magnet)

func upgrade_cost(key: String) -> int:
	if key not in UPGRADE_KEYS or int(upgrades[key]) >= 10:
		return -1
	var value := int(upgrades[key])
	return 180 + value * 200 + value * value * 50

func purchase_upgrade(key: String) -> bool:
	var cost := upgrade_cost(key)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	upgrades[key] = int(upgrades[key]) + 1
	return true

func unlock_weapon(key: String) -> bool:
	if key not in WEAPONS:
		return false
	if key in owned_weapons:
		selected_weapon = key
		return true
	var requirement := 3 if key == "scatter" else 6
	var cost := 250 if key == "scatter" else 650
	if level() < requirement or coins < cost:
		return false
	coins -= cost
	owned_weapons.append(key)
	selected_weapon = key
	return true

func roll_day(day: int) -> bool:
	# Clock rollback never resets a completed day or makes an earlier gift claimable.
	if daily_day >= day:
		return false
	daily_day = day
	daily = {"kills": 0, "survival": 0, "dashes": 0}
	daily_claimed = {}
	return true

func claim_login(day: int) -> int:
	if day <= login_day:
		return 0
	if login_day >= 0 and day == login_day + 1:
		login_streak = (login_streak % 7) + 1
	else:
		login_streak = 1
	login_day = day
	var amount: int = LOGIN_REWARDS[login_streak - 1]
	coins += amount
	return amount

func claim_quest(key: String) -> int:
	if key not in DAILY_GOALS or bool(daily_claimed.get(key, false)):
		return 0
	if int(daily.get(key, 0)) < int(DAILY_GOALS[key]):
		return 0
	daily_claimed[key] = true
	coins += 160
	xp += 20
	quests_claimed += 1
	return 160

func record_run(result: Dictionary) -> Dictionary:
	var duration := safe_int(result.get("seconds", 0), 0, 86400)
	var defeated := safe_int(result.get("kills", 0), 0, 100000)
	if duration < 5 and defeated == 0:
		return {"coins": 0, "xp": 0, "levels": 0, "recorded": false}
	var old_level := level()
	var earned_coins := defeated * 3 + int(duration / 6) + 20
	# Future rewards slow progression; existing XP/levels and purchases are unchanged.
	var earned_xp := defeated * 2 + int(duration / 7) + 5
	coins += earned_coins
	xp += earned_xp
	kills += defeated
	seconds += duration
	runs += 1
	best_wave = maxi(best_wave, safe_int(result.get("wave", 1), 1, 10000))
	best_seconds = maxi(best_seconds, duration)
	var run_dashes := safe_int(result.get("dashes", 0), 0, 100000)
	dashes += run_dashes
	elites += safe_int(result.get("elites", 0), 0, 100000)
	powerups += safe_int(result.get("powerups", 0), 0, 100000)
	if result.get("kind_kills", {}) is Dictionary:
		for key in kind_kills:
			kind_kills[key] = int(kind_kills[key]) + safe_int(result.get("kind_kills", {}).get(key, 0), 0, defeated)
	if result.get("seen", []) is Array:
		for item in result.get("seen", []):
			var creature := safe_int(item, -1, 199)
			if creature >= 0 and creature not in seen:
				seen.append(creature)
	daily.kills = int(daily.kills) + defeated
	daily.survival = int(daily.survival) + duration
	daily.dashes = int(daily.dashes) + run_dashes
	var levels := maxi(0, level() - old_level)
	coins += levels * 70
	return {"coins": earned_coins + levels * 70, "xp": earned_xp, "levels": levels, "recorded": true}

func metric(key: String) -> int:
	match key:
		"kills": return kills
		"seconds": return seconds
		"runs": return runs
		"best_wave": return best_wave
		"best_seconds": return best_seconds
		"dashes": return dashes
		"elites": return elites
		"powerups": return powerups
		"quests": return quests_claimed
		"player_level": return level()
		"seen": return seen.size()
		"login_streak": return login_streak
		"upgrades":
			var total := 0
			for value in upgrades.values(): total += int(value)
			return total
	return int(kind_kills.get(key, 0))

func check_achievements(catalog: Dictionary) -> Array:
	var result: Array = []
	for entry in catalog.get("achievements", []):
		var key := str(entry.get("key", ""))
		if not bool(achieved.get(key, false)) and metric(str(entry.get("metric", ""))) >= int(entry.get("threshold", 1)):
			achieved[key] = true
			result.append(key)
	return result

func to_data() -> Dictionary:
	return {"schema": 1, "coins": coins, "xp": xp, "kills": kills, "seconds": seconds, "runs": runs, "best_wave": best_wave, "best_seconds": best_seconds, "dashes": dashes, "elites": elites, "powerups": powerups, "quests_claimed": quests_claimed, "selected_weapon": selected_weapon, "upgrades": upgrades.duplicate(true), "owned_weapons": owned_weapons.duplicate(), "kind_kills": kind_kills.duplicate(true), "seen": seen.duplicate(), "achieved": achieved.duplicate(true), "daily_day": daily_day, "daily": daily.duplicate(true), "daily_claimed": daily_claimed.duplicate(true), "login_day": login_day, "login_streak": login_streak, "music_enabled": music_enabled, "effects_enabled": effects_enabled}

func load_data(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	coins = safe_int(value.get("coins", 180), 0, 2000000000)
	xp = safe_int(value.get("xp", 0), 0, 1000000000)
	kills = safe_int(value.get("kills", 0), 0, 1000000000)
	seconds = safe_int(value.get("seconds", 0), 0, 1000000000)
	runs = safe_int(value.get("runs", 0), 0, 100000000)
	best_wave = safe_int(value.get("best_wave", 1), 1, 10000)
	best_seconds = safe_int(value.get("best_seconds", 0), 0, 86400)
	dashes = safe_int(value.get("dashes", 0), 0, 1000000000)
	elites = safe_int(value.get("elites", 0), 0, 1000000000)
	powerups = safe_int(value.get("powerups", 0), 0, 1000000000)
	quests_claimed = safe_int(value.get("quests_claimed", 0), 0, 100000000)
	for key in UPGRADE_KEYS:
		if value.get("upgrades", {}) is Dictionary:
			upgrades[key] = safe_int(value.get("upgrades", {}).get(key, 0), 0, 10)
	owned_weapons = ["repeater"]
	if value.get("owned_weapons", []) is Array:
		for key in value.get("owned_weapons", []):
			if key in WEAPONS and key not in owned_weapons: owned_weapons.append(key)
	selected_weapon = str(value.get("selected_weapon", "repeater"))
	if selected_weapon not in owned_weapons: selected_weapon = "repeater"
	for key in kind_kills:
		if value.get("kind_kills", {}) is Dictionary: kind_kills[key] = safe_int(value.get("kind_kills", {}).get(key, 0), 0, kills)
	seen = []
	if value.get("seen", []) is Array:
		for item in value.get("seen", []):
			var creature := safe_int(item, -1, 199)
			if creature >= 0 and creature not in seen: seen.append(creature)
	achieved = {}
	if value.get("achieved", {}) is Dictionary:
		for key in value.get("achieved", {}):
			if key is String and bool(value.get("achieved", {})[key]): achieved[key] = true
	daily_day = safe_int(value.get("daily_day", -1), -1, 1000000)
	login_day = safe_int(value.get("login_day", -1), -1, 1000000)
	login_streak = safe_int(value.get("login_streak", 0), 0, 7)
	if value.get("daily", {}) is Dictionary:
		for key in DAILY_GOALS: daily[key] = safe_int(value.get("daily", {}).get(key, 0), 0, 1000000000)
	daily_claimed = {}
	if value.get("daily_claimed", {}) is Dictionary:
		for key in DAILY_GOALS: daily_claimed[key] = bool(value.get("daily_claimed", {}).get(key, false))
	music_enabled = bool(value.get("music_enabled", true))
	effects_enabled = bool(value.get("effects_enabled", true))
	return true

static func safe_int(value: Variant, minimum: int, maximum: int) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
		return minimum
	return int(clampf(float(value), float(minimum), float(maximum)))
