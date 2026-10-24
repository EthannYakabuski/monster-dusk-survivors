extends SceneTree
## Deterministic source fixtures only. No native or production-service claim.
const Profile = preload("res://game/profile.gd")
const Survival = preload("res://game/survival.gd")
var checks = 0
var failures = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("Assertion failed: "+label)
func arena() -> RefCounted:
	var s = Survival.new(); s.start(Profile.new(),70531)
	s.enemies.clear(); s.spawn_clock = 999
	return s
func _initialize() -> void:
	for rank in [0,5,10]:
		var p = Profile.new(); p.upgrades.tempo = rank
		for weapon in Profile.WEAPONS:
			p.selected_weapon = weapon
			var s = Survival.new(); s.start(p,70531)
			check(is_equal_approx(s.base_fire_interval,maxf(.19,.46-.022*rank)),"restored original tempo firing interval %d/%s"%[rank,weapon])
	for wave in [1,4,20,100]:
		for kind in Survival.PROFILES:
			for elite in [false,true]:
				var previous = float(Survival.PROFILES[kind].speed)*minf(1.7,1.0+wave*.017)*1.25
				var s = arena(); s.wave = wave
				s.spawn_enemy(kind,s.player+Vector2(250,0),elite)
				var b: Dictionary = s.enemies[0]
				check(is_equal_approx(b.speed,previous*.90),"every family/wave/elite moves ten percent slower than Round Three %s/%d/%s"%[kind,wave,elite])
				var before: Vector2 = b.pos; s._move_enemies(.02)
				check(absf(before.distance_to(b.pos)-previous*.90*.02)<.0001,"actual family movement uses reduced final speed %s/%d/%s"%[kind,wave,elite])
	var s = arena(); s.wave = 3
	var ranged_early = false
	for i in range(200): ranged_early = ranged_early or s.choose_kind() == "ranged"
	check(not ranged_early,"ranged enemies retain their introductory wave gate")
	s.wave = 4; var ranged_seen = false
	for i in range(200): ranged_seen = ranged_seen or s.choose_kind() == "ranged"
	check(ranged_seen,"normal wave-four spawn selection includes ranged Spitters")
	s.enemies.clear(); s.spawn_enemy("ranged",s.player+Vector2(180,0)); s.enemies[0].timer = 0
	s._move_enemies(.01)
	check(s.bullets.size() == 1 and not s.bullets[0].friendly and s.bullets[0].vel.x < 0,"Spitter fires hostile aimed projectile from range")
	var origin: Vector2 = s.bullets[0].pos; s._move_bullets(.05)
	check(s.bullets[0].pos.x < origin.x,"hostile projectile travels toward the player independently of contact")
	s.bullets[0].pos = s.player; s.bullets[0].vel = Vector2.ZERO
	var before_hp: float = s.hp; s._move_bullets(.01)
	check(s.hp < before_hp and s.bullets.is_empty(),"ranged projectile can actually damage the player once")
	s = arena(); s.spawn_enemy("ranged",s.player+Vector2(70,0)); s.enemies[0].timer = 999
	s._move_enemies(.02)
	check(s.enemies[0].pos.x > s.player.x+70,"Spitter still retreats when player is close")
	print("MONSTER ROUND FOUR CHECKS %d failures %d; deterministic source only"%[checks,failures])
	quit(1 if failures else 0)
