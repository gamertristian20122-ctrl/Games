extends "res://scripts/entities/enemy.gd"
## Boss: the shared base for every boss. It is an enemy with extras: a name for the boss bar,
## two phases (it gets meaner under half health), an entrance, and a big slow-motion death.
## What a boss IS comes from scripts/data/bosses.gd; its ATTACKS are one file per boss in
## scripts/entities/bosses/<script>.gd, written exactly like an enemy AI file (see enemy.gd), plus:
##     func phase_changed(e, phase: int) -> void   # optional: called once when phase 2 starts
## Inside a boss file, e.phase is 1 or 2. The shell reads display_name, hp and max_hp.

const Bosses = preload("res://scripts/data/bosses.gd")

const DEATH_TIME := 1.3

var phase := 1
var boss_id := ""
var dying := 0.0
var _death_puff := 0.0


func _row(enemy_id: String) -> Dictionary:
	boss_id = enemy_id
	return Bosses.info(enemy_id)


func _hp_scale() -> float:
	return 1.0 + Bosses.HP_PER_FLOOR * run.floor_index


func _load_ai() -> RefCounted:
	return ai_for(String(data.get("script", "gravekeeper")), "bosses")


func setup(the_room: Node, enemy_id: String, opts: Dictionary = {}) -> void:
	super.setup(the_room, enemy_id, opts)
	mass = 40.0
	hit_grow = 1.0
	# a bigger warning than a normal enemy gets
	run.fx.warn_circle(position, radius * 2.2, appear)


func _appear() -> void:
	super._appear()
	run.boss = self
	run.shake(0.6)
	Sfx.play("boss_roar")
	Sfx.music(String(run.theme.get("boss_music", "boss")))
	G.boss_started.emit(self)
	G.toast.emit(display_name, "")


func _physics_process(delta: float) -> void:
	if dying > 0.0:
		_tick_death(delta)
		return
	super._physics_process(delta)
	if not dead and phase == 1 and hp <= max_hp * 0.5:
		phase = 2
		stun = 0.7
		lift = 0.0
		tell(0.7)
		run.shake(0.5)
		run.fx.ring(position - Vector2(0, 10), 6.0, 60.0, 0.5, Color(1.0, 0.3, 0.2), 3.0)
		Sfx.play("boss_roar", 0.0, 0.0)
		if ai.has_method("phase_changed"):
			ai.phase_changed(self, 2)


## The Hungry Curse took a bite (scripts/entities/curse.gd, where the numbers live): the boss
## loses `percent` of its full health, but never drops below `floor_share` of it, so the hero
## always lands the last hit. It flinches for `flinch` seconds. Returns the health really lost.
func bitten(percent: float, floor_share: float, flinch: float) -> float:
	if dead or not hittable:
		return 0.0
	var loss := clampf(max_hp * percent / 100.0, 0.0, maxf(hp - max_hp * floor_share, 0.0))
	hp -= loss
	_flash = 0.2
	stun = maxf(stun, flinch)
	Sfx.play("enemy_hit", -4.0, 0.05, 0.6)
	return loss


func die(_drops: bool = true) -> void:
	if dead:
		return
	dead = true
	hittable = false
	harmful = false
	dying = DEATH_TIME
	lift = 0.0
	run.fx.hazards.clear()
	run.shots.clear()
	run.slowmo(0.3, 0.3)
	run.hitstop(0.08)
	Sfx.play("boss_die")
	# its helpers fall with it
	for e in room.enemies.duplicate():
		if e != self and is_instance_valid(e):
			e.die(false)


func _tick_death(delta: float) -> void:
	dying -= delta
	_death_puff -= delta
	sprite.material = white_material() if fmod(dying * 14.0, 1.0) < 0.5 else null
	sprite.position.x = randf_range(-1.5, 1.5)
	if _death_puff <= 0.0:
		_death_puff = 0.12
		var at := position + Vector2(randf_range(-10, 10), randf_range(-24, 0))
		run.fx.burst(at, Art.palette(String(data["sprite"])), 8, 70.0, 0.5, 2.6)
		run.fx.ring(at, 2.0, 12.0, 0.2, Color(1, 0.9, 0.7), 1.5)
		run.shake(0.25)
	if dying <= 0.0:
		run.fx.burst(position - Vector2(0, 12), Art.palette(String(data["sprite"])), 70, 150.0, 0.9, 3.4)
		run.fx.ring(position - Vector2(0, 10), 6.0, 90.0, 0.5, Color(1, 1, 1), 4.0)
		run.fx.flash(Color(1, 1, 1, 0.5), 0.2)
		run.shake(1.0)
		Sfx.play("explosion")
		Sfx.play("enemy_die_big")
		for k in 5 + randi() % 4:
			room.drop("coin", position + Vector2(randf_range(-8, 8), randf_range(-6, 6)))
		room.drop("heart", position)
		room.enemy_died(self)
		run.boss_killed(self)
		queue_free()
