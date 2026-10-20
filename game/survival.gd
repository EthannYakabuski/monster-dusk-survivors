extends RefCounted
## Deterministic arena simulation, independent from the presentation and native SDKs.

const ARENA := Rect2(20, 145, 500, 640)
const PROFILES := {
	"slow": {"name": "Shambler", "speed": 40.0, "hp": 24.0, "damage": 10.0, "radius": 19.0, "color": "a5be77"},
	"fast": {"name": "Rusher", "speed": 94.0, "hp": 14.0, "damage": 8.0, "radius": 15.0, "color": "f4bc63"},
	"tank": {"name": "Ironhide", "speed": 25.0, "hp": 80.0, "damage": 18.0, "radius": 26.0, "color": "8cb4c6"},
	"glass": {"name": "Ember Fang", "speed": 110.0, "hp": 9.0, "damage": 24.0, "radius": 16.0, "color": "eb816a"},
	"ranged": {"name": "Spitter", "speed": 38.0, "hp": 28.0, "damage": 13.0, "radius": 19.0, "color": "b5b5e9"},
	"magical": {"name": "Hexling", "speed": 32.0, "hp": 40.0, "damage": 20.0, "radius": 21.0, "color": "d58ed3"}
}
var rng := RandomNumberGenerator.new()
var player := Vector2(270, 495)
var movement := Vector2.ZERO
var last_direction := Vector2.ZERO
var dash_direction := Vector2.ZERO
var hp: float = 100.0
var max_hp: float = 100.0
var elapsed: float = 0.0
var wave: int = 1
var kills: int = 0
var dashes: int = 0
var elites: int = 0
var powerups_collected: int = 0
var run_xp: int = 0
var rank: int = 1
var pending_cards: int = 0
var cards: Dictionary = {"power": 0, "tempo": 0, "spread": 0, "speed": 0, "mend": 0}
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var events: Array[Dictionary] = []
var kind_kills: Dictionary = {"slow": 0, "fast": 0, "tank": 0, "glass": 0, "ranged": 0, "magical": 0}
var seen: Array = []
var alive := true
var dash_cooldown: float = 0.0
var dash_left: float = 0.0
var invulnerability: float = 0.0
var haste_left: float = 0.0
var shield_left: float = 0.0
var spawn_clock: float = 0.4
var fire_clock: float = 0.0
var last_elite_wave: int = 0
var damage: float = 13.0
var base_fire_interval: float = 0.46
var pickup_radius: float = 35.0
var weapon: String = "repeater"
var continued := false
var lantern_clock: float = 0.0

func start(profile: RefCounted, seed_value: int) -> void:
	rng.seed = seed_value
	max_hp = profile.maximum_health()
	hp = max_hp
	damage = profile.bullet_damage()
	base_fire_interval = profile.fire_interval()
	pickup_radius = profile.pickup_radius()
	weapon = profile.selected_weapon
	for index in range(3): spawn_enemy("slow", Vector2(65 + index * 205, 160))

func spawn_enemy(kind: String, position: Vector2 = Vector2.INF, elite: bool = false) -> void:
	if kind not in PROFILES or enemies.size() >= 90:
		return
	var spec: Dictionary = PROFILES[kind]
	var place := position
	if place == Vector2.INF:
		match rng.randi_range(0, 3):
			0: place = Vector2(ARENA.position.x, rng.randf_range(ARENA.position.y, ARENA.end.y))
			1: place = Vector2(ARENA.end.x, rng.randf_range(ARENA.position.y, ARENA.end.y))
			2: place = Vector2(rng.randf_range(ARENA.position.x, ARENA.end.x), ARENA.position.y)
			3: place = Vector2(rng.randf_range(ARENA.position.x, ARENA.end.x), ARENA.end.y)
	var scaling := 1.0 + (wave - 1) * 0.11
	var health := float(spec.hp) * scaling * (3.4 if elite else 1.0)
	var sprite := rng.randi_range(0, 199)
	enemies.append({"kind": kind, "pos": place, "hp": health, "max_hp": health, "speed": float(spec.speed) * minf(1.7, 1.0 + wave * 0.017), "radius": float(spec.radius) * (1.35 if elite else 1.0), "timer": rng.randf_range(0.3, 2.0), "flash": 0.0, "elite": elite, "sprite": sprite})
	if sprite not in seen: seen.append(sprite)

func choose_kind() -> String:
	var available := ["slow", "fast"]
	if wave >= 2: available.append("glass")
	if wave >= 3: available.append("tank")
	if wave >= 4: available.append("ranged")
	if wave >= 5: available.append("magical")
	return str(available[rng.randi_range(0, available.size() - 1)])

func dash() -> bool:
	if not alive or dash_cooldown > 0.0 or (movement.length() < 0.1 and last_direction.length() < 0.1):
		return false
	dash_direction = movement.normalized() if movement.length() >= 0.1 else last_direction
	dash_left = 0.18
	dash_cooldown = 3.3
	invulnerability = maxf(invulnerability, 0.32)
	dashes += 1
	events.append({"type": "dash", "pos": player})
	return true

func take_damage(amount: float) -> void:
	if not alive or invulnerability > 0.0 or shield_left > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	invulnerability = 0.65
	events.append({"type": "hurt", "pos": player})
	if hp <= 0.0:
		alive = false
		events.append({"type": "death", "pos": player})

func continue_run() -> bool:
	if alive or continued:
		return false
	continued = true
	alive = true
	hp = max_hp * 0.65
	invulnerability = 3.5
	for enemy in enemies:
		if enemy.pos.distance_to(player) < 140.0: enemy.pos += (enemy.pos - player).normalized() * 150.0
	bullets = bullets.filter(func(item: Dictionary) -> bool: return bool(item.friendly))
	hazards.clear()
	return true

func choose_card(key: String) -> bool:
	if pending_cards <= 0 or key not in cards:
		return false
	cards[key] = int(cards[key]) + 1
	pending_cards -= 1
	if key == "mend": hp = minf(max_hp, hp + max_hp * 0.35)
	return true

func step(delta: float) -> void:
	if not alive or pending_cards > 0:
		return
	var dt := clampf(delta, 0.0, 0.05)
	elapsed += dt
	wave = 1 + int(elapsed / 22.0)
	dash_cooldown = maxf(0.0, dash_cooldown - dt)
	dash_left = maxf(0.0, dash_left - dt)
	invulnerability = maxf(0.0, invulnerability - dt)
	haste_left = maxf(0.0, haste_left - dt)
	shield_left = maxf(0.0, shield_left - dt)
	var velocity := movement.limit_length(1.0) * (165.0 + 12.0 * int(cards.speed))
	if movement.length() >= 0.1: last_direction = movement.normalized()
	if dash_left > 0.0: velocity = dash_direction * (165.0 + 12.0 * int(cards.speed)) * 3.5
	player += velocity * dt
	player.x = clampf(player.x, ARENA.position.x + 18.0, ARENA.end.x - 18.0)
	player.y = clampf(player.y, ARENA.position.y + 18.0, ARENA.end.y - 18.0)
	spawn_clock -= dt
	if spawn_clock <= 0.0:
		spawn_enemy(choose_kind())
		spawn_clock = maxf(0.16, 1.1 - wave * 0.065)
	if wave % 5 == 0 and wave != last_elite_wave:
		last_elite_wave = wave
		spawn_enemy("tank" if wave % 10 == 0 else "magical", Vector2.INF, true)
		_events_text("ELITE AT THE GATE")
	_move_enemies(dt)
	_fire(dt)
	_move_bullets(dt)
	_update_hazards(dt)
	_update_drops(dt)

func _move_enemies(dt: float) -> void:
	for enemy in enemies:
		var direction: Vector2 = (player - enemy.pos).normalized()
		var distance: float = enemy.pos.distance_to(player)
		var kind := str(enemy.kind)
		enemy.timer = float(enemy.timer) - dt
		enemy.flash = maxf(0.0, float(enemy.flash) - dt)
		if kind == "ranged":
			if distance > 210.0: enemy.pos += direction * float(enemy.speed) * dt
			elif distance < 140.0: enemy.pos -= direction * float(enemy.speed) * dt
			if float(enemy.timer) <= 0.0:
				enemy.timer = maxf(1.1, 2.7 - wave * 0.04)
				bullets.append({"pos": enemy.pos, "vel": direction * 145.0, "damage": 13.0 + wave * 0.6, "friendly": false, "life": 5.0, "radius": 7.0, "pierce": 0})
		elif kind == "magical":
			if distance > 190.0: enemy.pos += direction * float(enemy.speed) * dt
			if float(enemy.timer) <= 0.0:
				enemy.timer = 4.6
				hazards.append({"pos": player, "left": 1.35, "radius": 58.0, "damage": 20.0 + wave})
		else:
			enemy.pos += direction * float(enemy.speed) * dt
		enemy.pos.x = clampf(enemy.pos.x, ARENA.position.x, ARENA.end.x)
		enemy.pos.y = clampf(enemy.pos.y, ARENA.position.y, ARENA.end.y)
		if distance < float(enemy.radius) + 14.0:
			take_damage(float(PROFILES[kind].damage) + wave * 0.5)

func _fire(dt: float) -> void:
	fire_clock -= dt
	if fire_clock > 0.0 or enemies.is_empty(): return
	var nearest: Dictionary = enemies[0]
	var distance: float = player.distance_squared_to(nearest.pos)
	for enemy in enemies:
		var candidate: float = player.distance_squared_to(enemy.pos)
		if candidate < distance:
			nearest = enemy
			distance = candidate
	var direction: Vector2 = (nearest.pos - player).normalized()
	var interval := base_fire_interval / (1.0 + int(cards.tempo) * 0.14)
	if haste_left > 0.0: interval *= 0.52
	var shot_damage := damage * (1.0 + int(cards.power) * 0.22)
	var spread := 1 + mini(4, int(cards.spread))
	if weapon == "scatter":
		spread += 2
		shot_damage *= 0.65
		interval *= 1.32
	elif weapon == "lantern":
		interval *= 1.22
		shot_damage *= 1.25
	for index in range(spread):
		var angle := (float(index) - float(spread - 1) * 0.5) * 0.18
		bullets.append({"pos": player + direction * 20.0, "vel": direction.rotated(angle) * 510.0, "damage": shot_damage, "friendly": true, "life": 1.4, "radius": 5.5, "pierce": 1 if weapon == "lantern" else 0})
	fire_clock = interval
	events.append({"type": "shot", "pos": player})

func _move_bullets(dt: float) -> void:
	for index in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[index]
		bullet.pos += bullet.vel * dt
		bullet.life = float(bullet.life) - dt
		var remove := float(bullet.life) <= 0.0 or not ARENA.grow(70.0).has_point(bullet.pos)
		if bool(bullet.friendly):
			for enemy_index in range(enemies.size() - 1, -1, -1):
				var enemy: Dictionary = enemies[enemy_index]
				if bullet.pos.distance_to(enemy.pos) < float(enemy.radius) + float(bullet.radius):
					enemy.hp = float(enemy.hp) - float(bullet.damage)
					enemy.flash = 0.10
					if float(enemy.hp) <= 0.0: _defeat(enemy_index)
					if int(bullet.pierce) <= 0: remove = true
					else:
						bullet.pierce = int(bullet.pierce) - 1
						bullet.pos += bullet.vel.normalized() * 55.0
					break
		elif bullet.pos.distance_to(player) < 16.0 + float(bullet.radius):
			take_damage(float(bullet.damage))
			remove = true
		if remove: bullets.remove_at(index)

func _defeat(index: int) -> void:
	var enemy: Dictionary = enemies[index]
	kills += 1
	kind_kills[enemy.kind] = int(kind_kills[enemy.kind]) + 1
	if bool(enemy.elite): elites += 1
	drops.append({"pos": enemy.pos, "kind": "xp", "value": 16 if bool(enemy.elite) else 4, "life": 35.0})
	if rng.randf() < 0.10 or bool(enemy.elite):
		var pick: String = ["heal", "haste", "shield", "nova"][rng.randi_range(0, 3)]
		drops.append({"pos": enemy.pos + Vector2(14, 0), "kind": pick, "value": 1, "life": 18.0})
	events.append({"type": "kill", "pos": enemy.pos, "color": PROFILES[enemy.kind].color})
	enemies.remove_at(index)

func _update_hazards(dt: float) -> void:
	for index in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[index]
		hazard.left = float(hazard.left) - dt
		if float(hazard.left) <= 0.0:
			if player.distance_to(hazard.pos) < float(hazard.radius): take_damage(float(hazard.damage))
			events.append({"type": "hex", "pos": hazard.pos})
			hazards.remove_at(index)

func _update_drops(dt: float) -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[index]
		drop.life = float(drop.life) - dt
		var distance: float = player.distance_to(drop.pos)
		if distance < pickup_radius + 55.0:
			drop.pos = drop.pos.move_toward(player, 230.0 * dt)
		if distance < 22.0:
			_apply_pickup(str(drop.kind), int(drop.value))
			drops.remove_at(index)
		elif float(drop.life) <= 0.0: drops.remove_at(index)

func _apply_pickup(kind: String, value: int = 1) -> void:
	if kind == "xp":
		run_xp += value
		while run_xp >= rank * 18:
			run_xp -= rank * 18
			rank += 1
			pending_cards += 1
	else:
		powerups_collected += 1
		match kind:
			"heal": hp = minf(max_hp, hp + 28.0)
			"haste": haste_left = 7.0
			"shield": shield_left = 4.0
			"nova":
				for index in range(enemies.size() - 1, -1, -1):
					if enemies[index].pos.distance_to(player) < 180.0:
						enemies[index].hp = float(enemies[index].hp) - damage * 5.0
						if float(enemies[index].hp) <= 0.0: _defeat(index)
		events.append({"type": "pickup", "pos": player, "kind": kind})

func result() -> Dictionary:
	return {"seconds": int(elapsed), "wave": wave, "kills": kills, "dashes": dashes, "elites": elites, "powerups": powerups_collected, "kind_kills": kind_kills.duplicate(true), "seen": seen.duplicate()}

func _events_text(text: String) -> void:
	events.append({"type": "notice", "text": text, "pos": player})
