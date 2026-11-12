extends RefCounted
## Hero skills: the knight's mana and what each skill DOES when its button is pressed.
## The table (names, costs, cooldowns, the numbers in "p") is scripts/data/skills.gd.
## player.gd owns one of these (`skills`), calls tick() every physics frame and use(slot) when a
## skill button is pressed (Controls.skill_pressed).
## To add a skill: a row in skills.gd, a picture in tools/import_icons.py EXTRA, and a function
## here named in the `match` of _cast().
## Sword skills hit with the blow's own damage (and respect a boss's guard, like a swing);
## spells also grow with Spirit and pass a guard. Effects are code-drawn (rings, sparks, lines).

const Skills = preload("res://scripts/data/skills.gd")
const Shots = preload("res://scripts/run/shots.gd")

const FIRE := [Color(1.0, 0.85, 0.4), Color(1.0, 0.5, 0.15), Color(1, 1, 0.8)]
const ICE := [Color(0.75, 0.95, 1.0), Color(0.45, 0.75, 1.0), Color(1, 1, 1)]
const GOLD := [Color(1.0, 0.92, 0.55), Color(1, 1, 1)]

var p: Node                      ## the player
var mana := 0.0
var max_mana := 0.0
var cd: Array[float] = [0.0, 0.0]          ## seconds each button still rests
var cd_max: Array[float] = [1.0, 1.0]
var said := ""                   ## why the last press did nothing ("" = it worked): the HUD shows it
var _later: Array = []           ## [seconds from now, Callable]
var _dash_t := 0.0
var _dash_v := Vector2.ZERO
var _dash_hit := {}
var _dash_row := {}


func setup(player: Node) -> void:
	p = player
	Skills.fill_empty()
	max_mana = Skills.max_mana()
	mana = max_mana


## The stat points changed (Spirit): more mana at once.
func refresh() -> void:
	var grown := Skills.max_mana() - max_mana
	max_mana = Skills.max_mana()
	mana = clampf(mana + maxf(grown, 0.0), 0.0, max_mana)


func tick(delta: float) -> void:
	mana = minf(max_mana, mana + Skills.regen() * delta)
	for i in cd.size():
		cd[i] = maxf(cd[i] - delta, 0.0)
	for k in range(_later.size() - 1, -1, -1):
		_later[k][0] -= delta
		if _later[k][0] <= 0.0:
			var todo: Callable = _later[k][1]
			_later.remove_at(k)
			if not p.dead:
				todo.call()
	if _dash_t > 0.0:
		_dash_step(delta)


## 0..1: how far a button's rest is over.
func fill(slot: int) -> float:
	return 1.0 - clampf(cd[slot] / maxf(cd_max[slot], 0.01), 0.0, 1.0)


## Why this button would do nothing right now ("" = it would work).
func why_not(slot: int) -> String:
	var r := Skills.on_button(slot)
	if r.is_empty():
		return "No skill on this button"
	if cd[slot] > 0.0:
		return "%s is not ready yet" % String(r["name"])
	if mana < float(r["mana"]):
		return "Not enough mana for %s" % String(r["name"])
	return ""


func use(slot: int) -> bool:
	if p.dead or p.room == null or slot < 0 or slot >= Skills.SLOTS:
		return false
	said = why_not(slot)
	if said != "":
		Sfx.play("shop_deny", -10.0)
		return false
	var r := Skills.on_button(slot)
	mana -= float(r["mana"])
	cd[slot] = float(r["cd"])
	cd_max[slot] = float(r["cd"])
	_cast(r)
	G.hud_changed.emit()
	return true


func _cast(r: Dictionary) -> void:
	var n: Dictionary = r.get("p", {})
	match String(r["id"]):
		"whirl": _whirl(n)
		"firebolt": _firebolt(n)
		"lunge": _lunge(r)
		"mend": _mend(n)
		"cry": _cry(n)
		"frost": _frost(n)
		"slam": _slam(n)
		"storm": _storm(n)


# ------------------------------------------------------------------ helpers
func _foes() -> Array:
	var out: Array = []
	for e in p.room.enemies:
		if is_instance_valid(e) and not e.dead and e.hittable:
			out.append(e)
	return out


## Where a monster's body is, and how far its edge is from the knight.
func _mid_of(e: Node) -> Vector2:
	return (e.position as Vector2) - Vector2(0.0, float(e.hit_up) * 0.5)


func _gap(e: Node, from: Vector2) -> float:
	return _mid_of(e).distance_to(from) - float(e.radius) - float(e.hit_grow)


func _blow() -> float:
	return p.stats.v("damage")


func _spell() -> float:
	return p.stats.v("damage") * Skills.spell_power()


func _centre() -> Vector2:
	return (p.position as Vector2) - Vector2(0.0, 8.0)


func _is_boss(e: Node) -> bool:
	return "boss_id" in e


## A sword skill's blow: a boss's guard stops it, as it stops a swing.
func _sword_hit(e: Node, damage: float, shove: float) -> void:
	if e.get("shielded") == true:
		return
	var dir: Vector2 = (_mid_of(e) - (p.position as Vector2)).normalized()
	p._strike(e, damage, dir, shove)


func _spell_hit(e: Node, damage: float, shove: float, sparks: Array) -> void:
	var dir: Vector2 = (_mid_of(e) - (p.position as Vector2)).normalized()
	e.hurt(damage, dir, shove)
	p.run.fx.burst((e.position as Vector2) - Vector2(0, float(e.hit_up)), sparks, 6, 70.0, 0.3, 2.0, dir)


## Enemy shots inside the circle are cut down (as a swing does).
func _clear_shots(radius: float) -> void:
	var shots: Node = p.run.shots
	for i in shots.count:
		if shots.side[i] != Shots.SIDE_ENEMY or shots.left[i] <= 0.0:
			continue
		if (shots.pos[i] - Vector2(0.0, 7.0)).distance_to(p.position) <= radius:
			shots.left[i] = 0.0
			p.run.fx.burst(shots.pos[i] - Vector2(0.0, 7.0), [Color(1, 1, 1)], 3, 50.0, 0.18, 2.0)


# ------------------------------------------------------------------ the skills
## Whirlwind: everything around him takes a double blow.
func _whirl(n: Dictionary) -> void:
	var reach: float = p.melee_reach() + float(n.get("reach", 12.0))
	for e in _foes():
		if _gap(e, p.position) <= reach:
			_sword_hit(e, _blow() * float(n.get("damage", 2.0)), 1.8)
	_clear_shots(reach)
	p.run.fx.ring(_centre(), 6.0, reach, 0.2, Color(1, 1, 1, 0.9), 2.5)
	p.run.fx.ring(_centre(), 4.0, reach * 0.7, 0.26, Color(0.75, 0.9, 1.0, 0.7), 1.5)
	p.run.shake(0.12)
	Sfx.play("player_shoot_blade", -1.0, 0.05, 0.7)


## Fire Bolt: one fast, heavy shot the way he aims.
func _firebolt(n: Dictionary) -> void:
	var dir: Vector2 = p.aim_dir
	p.run.shots.fire((p.position as Vector2) + dir * 8.0, dir * float(n.get("speed", 230.0)), Shots.SIDE_PLAYER,
		_spell() * float(n.get("damage", 3.0)), float(n.get("range", 210.0)), "firebolt", {"knock": 1.6, "size": 1.0, "bits": Shots.B_HERO})
	p.run.fx.burst(_centre() + dir * 10.0, FIRE, 6, 60.0, 0.25, 2.0, dir)
	Sfx.play("player_shoot_magic", -1.0, 0.05, 0.8)


## Lunge: a short dash the way he aims; whatever he passes through is cut; nothing hurts him.
func _lunge(r: Dictionary) -> void:
	var n: Dictionary = r.get("p", {})
	_dash_row = n
	_dash_t = 0.16
	_dash_v = (p.aim_dir as Vector2) * float(n.get("dist", 62.0)) / _dash_t
	_dash_hit = {}
	p.invuln = maxf(p.invuln, float(n.get("safe", 0.4)))
	p.run.fx.dust(p.position, -(p.aim_dir as Vector2), 1.4)
	Sfx.play("player_shoot_blade", -2.0, 0.05, 1.6)


func _dash_step(delta: float) -> void:
	_dash_t -= delta
	p.position = p.room.move_circle(p.position, p.radius, _dash_v * delta, false, true)
	for e in _foes():
		if _dash_hit.has(e.get_instance_id()) or _gap(e, p.position) > 12.0:
			continue
		_dash_hit[e.get_instance_id()] = true
		_sword_hit(e, _blow() * float(_dash_row.get("damage", 1.6)), 1.2)
	p.run.fx.burst(_centre(), [Color(1, 1, 1, 0.8), Color(0.75, 0.9, 1.0, 0.8)], 2, 20.0, 0.2, 2.0)


## Mend: one heart back.
func _mend(n: Dictionary) -> void:
	p.hp = mini(p.max_hp, p.hp + int(n.get("hp", 2)))
	p.run.fx.ring(_centre(), 16.0, 4.0, 0.35, Color(0.6, 1.0, 0.6, 0.9), 2.0)
	p.run.fx.burst(_centre(), [Color(0.6, 1.0, 0.6), Color(1, 1, 0.8)], 10, 40.0, 0.6, 2.0, Vector2.UP, -30.0)
	p.run.fx.sparkle(_centre(), Color(0.7, 1.0, 0.7))
	Sfx.play("heart_pickup", -2.0)


## War Cry: monsters near him are shoved back and stunned; a boss only flinches.
func _cry(n: Dictionary) -> void:
	var radius := float(n.get("radius", 70.0))
	for e in _foes():
		if _gap(e, p.position) > radius:
			continue
		e.hurt(0.01, (_mid_of(e) - (p.position as Vector2)).normalized(), 2.6)
		if not e.dead:
			e.stun = maxf(e.stun, 0.3 if _is_boss(e) else float(n.get("stun", 1.8)))
	p.run.fx.ring(_centre(), 8.0, radius, 0.3, Color(1.0, 0.92, 0.55, 0.9), 2.5)
	p.run.fx.ring(_centre(), 8.0, radius * 0.6, 0.4, Color(1, 1, 1, 0.6), 1.5)
	p.run.shake(0.2)
	Sfx.play("boss_roar", -7.0, 0.0, 1.5)


## Frost Ring: a burst of ice around him that hurts and freezes.
func _frost(n: Dictionary) -> void:
	var radius := float(n.get("radius", 62.0))
	for e in _foes():
		if _gap(e, p.position) > radius:
			continue
		_spell_hit(e, _spell() * float(n.get("damage", 1.5)), 0.6, ICE)
		if is_instance_valid(e) and not e.dead:
			e.stun = maxf(e.stun, 0.25 if _is_boss(e) else float(n.get("stun", 1.3)))
	_clear_shots(radius)
	p.run.fx.ring(_centre(), 6.0, radius, 0.28, Color(0.7, 0.92, 1.0, 0.95), 3.0)
	p.run.fx.ring(_centre(), 4.0, radius * 0.75, 0.36, Color(1, 1, 1, 0.7), 1.5)
	for k in 12:
		var a := TAU * float(k) / 12.0
		p.run.fx.burst(_centre() + Vector2(cos(a), sin(a) * 0.8) * radius * 0.8, ICE, 2, 25.0, 0.5, 2.0)
	Sfx.play("rock_break", -3.0, 0.05, 1.6)


## Ground Slam: a short wind-up (a pale ring closes in), then a very heavy blow all around.
func _slam(n: Dictionary) -> void:
	var radius := float(n.get("radius", 46.0))
	var wait := float(n.get("windup", 0.35))
	p.run.fx.ring(_centre(), radius, 6.0, wait, Color(1, 1, 1, 0.7), 1.5, true)
	_later.append([wait, func() -> void:
		for e in _foes():
			if _gap(e, p.position) <= radius:
				_sword_hit(e, _blow() * float(n.get("damage", 3.5)), 2.8)
		_clear_shots(radius)
		p.run.fx.ring(_centre(), 6.0, radius, 0.25, Color(1.0, 0.9, 0.6, 0.95), 3.0, true)
		p.run.fx.burst(p.position, [Color(0.8, 0.75, 0.65), Color(0.5, 0.45, 0.4)], 14, 90.0, 0.45, 2.5, Vector2.UP, 160.0)
		p.run.shake(0.35)
		Sfx.play("explosion", -6.0)])
	Sfx.play("player_shoot_blade", -3.0, 0.0, 0.5)


## Chain Lightning: the nearest few monsters are struck, the bolt leaping from one to the next.
func _storm(n: Dictionary) -> void:
	var radius := float(n.get("radius", 125.0))
	var near: Array = []
	for e in _foes():
		if _gap(e, p.position) <= radius:
			near.append(e)
	near.sort_custom(func(a: Node, b: Node) -> bool: return _gap(a, p.position) < _gap(b, p.position))
	var from := _centre()
	for e: Node in near.slice(0, int(n.get("targets", 5))):
		var to := _mid_of(e)
		p.run.fx.bolt(from, to)
		_spell_hit(e, _spell() * float(n.get("damage", 2.5)), 0.4, GOLD)
		from = to
	if near.is_empty():
		p.run.fx.bolt(from, from + (p.aim_dir as Vector2) * 40.0)      # nothing in reach: it cracks into the air
	p.run.fx.flash(Color(1, 1, 0.85, 0.12), 0.1)
	Sfx.play("player_shoot_magic", 0.0, 0.05, 1.8)
