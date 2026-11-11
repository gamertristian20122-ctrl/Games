extends RefCounted
## Status: what items can do TO a monster for a while. Two exist: CHILL (Winter Nail) and BURN (Pyre Kindling).
## Use with:  const Status = preload("res://scripts/entities/status.gd")
##     Status.chill(enemy)                 one more chill; the third one freezes it
##     Status.burn(enemy, damage_per_tick) set it alight (a new hit restarts the fire)
## A monster only gets a Status object once something touches it with one (enemy.status stays null
## for everyone else, so this costs nothing in a normal room).
##
## What enemy.gd does with it (three small hooks, nothing else knows about statuses):
##   _physics_process  calls tick() every frame; a frozen monster is held with the usual `stun`
##   _step             multiplies every walking helper by `speed`
##   hurt              multiplies knockback by `knock` (a frozen monster slides twice as far)
## What the player sees: chill = blue tint, frozen = pale blue and stock-still, burn = orange tint and
## embers, chill meeting burn = a white steam ring that hurts everything close.
##
## BOSSES (scripts/entities/boss.gd extends enemy.gd, so all of this already runs for them): a boss
## never freezes, is slowed BOSS_SLOW at most and does not speed up while burning; the burn hurts it
## like anyone. A boss fight that moves the boss WITHOUT the walking helpers (writes position itself)
## should multiply that movement by  boss.status_speed()  (1.0 when nothing is on it).

const CHILL_SLOW := 0.25         ## slower per chill (two chills = half speed)
const CHILL_FADE := 2.5          ## seconds after the last hit before the chill is gone
const CHILLS_TO_FREEZE := 3
const FREEZE_TIME := 1.8
const FREEZE_TIME_BIG := 0.9     ## elites and "big" monsters
const THAW_GUARD := 3.0          ## seconds after thawing in which it cannot be chilled again
const FROZEN_KNOCK := 2.0
const BOSS_SLOW := 0.15

const BURN_TIME := 3.0
const BURN_TICK := 0.5
const BURN_HASTE := 0.30         ## burning monsters run this much faster (the item's curse)
const LEAP_REACH := 6.0          ## fire jumps to a monster whose body is this close
const RELIGHT_GUARD := 2.0       ## a monster that burned out cannot catch fire from a neighbour this long

const STEAM_RADIUS := 24.0
const STEAM_DAMAGE := 2.0        ## times the hero's damage
const STEAM_GUARD := 1.5         ## seconds after a steam burst in which that monster takes neither chill nor fire

const TINT_CHILL := Color(0.62, 0.80, 1.25)
const TINT_FROZEN := Color(0.80, 1.05, 1.5)
const TINT_BURN := Color(1.45, 0.78, 0.42)

var speed := 1.0                 ## read by enemy._step
var knock := 1.0                 ## read by enemy.hurt
var chills := 0
var chill_t := 0.0
var frozen := 0.0
var guard := 0.0
var burning := 0.0
var burn_damage := 0.0
var burn_tick := 0.0
var relight := 0.0
var steamed := 0.0
var _tinted := false


static func of(e: Node) -> RefCounted:
	if e.status == null:
		e.status = new()
	return e.status


static func is_boss(e: Node) -> bool:
	return e.has_method("bitten")


## One more chill on `e` (Winter Nail calls this for every hit).
static func chill(e: Node) -> void:
	if e.dead:
		return
	var s: RefCounted = of(e)
	if s.steamed > 0.0:
		return
	if s.burning > 0.0:
		s._steam(e)
		return
	if s.guard > 0.0 or s.frozen > 0.0:
		return
	s.chill_t = CHILL_FADE
	s.chills += 1
	if s.chills >= CHILLS_TO_FREEZE and not is_boss(e):
		s.chills = 0
		s.chill_t = 0.0
		s.frozen = FREEZE_TIME_BIG if (e.elite or e.data.get("big", false)) else FREEZE_TIME
		e.stun = maxf(e.stun, s.frozen)
		e.run.fx.ring(e.position - Vector2(0, 6), 3.0, e.radius + 9.0, 0.25, Color(0.8, 0.95, 1.0), 2.0)
		Sfx.play("shot_hit_wall", -6.0, 0.05, 1.8)
	s.chills = mini(s.chills, CHILLS_TO_FREEZE - 1)
	s._refresh(e)


## Sets `e` alight; every BURN_TICK seconds it loses `damage_per_tick`. `leaped` = the fire came from a neighbour.
static func burn(e: Node, damage_per_tick: float, leaped: bool = false) -> void:
	if e.dead:
		return
	var s: RefCounted = of(e)
	if s.steamed > 0.0:
		return
	if s.chills > 0 or s.frozen > 0.0:
		s.burn_damage = damage_per_tick
		s._steam(e)
		return
	if leaped and (s.burning > 0.0 or s.relight > 0.0):
		return
	if s.burning <= 0.0:
		s.burn_tick = BURN_TICK
	s.burning = BURN_TIME
	s.burn_damage = maxf(damage_per_tick, 0.5)
	s._refresh(e)


## Called by enemy.gd every physics frame while the monster lives.
func tick(e: Node, delta: float) -> void:
	guard = maxf(0.0, guard - delta)
	relight = maxf(0.0, relight - delta)
	steamed = maxf(0.0, steamed - delta)
	var dirty := false
	if frozen > 0.0:
		frozen -= delta
		if frozen <= 0.0:
			guard = THAW_GUARD
			dirty = true
	elif chills > 0:
		chill_t -= delta
		if chill_t <= 0.0:
			chills = 0
			dirty = true
	if burning > 0.0:
		burning -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick += BURN_TICK
			_burn_tick(e)
			if e.dead:
				return
		if burning <= 0.0:
			relight = RELIGHT_GUARD
			dirty = true
	if dirty:
		_refresh(e)


func _burn_tick(e: Node) -> void:
	e.run.fx.burst(e.position - Vector2(0, 7), [Color(1.0, 0.65, 0.2), Color(1.0, 0.9, 0.5), Color(0.9, 0.3, 0.1)], 4, 45.0, 0.4, 2.0, Vector2(0, -0.6))
	for o in e.room.enemies.duplicate():       # (a leap can end in steam, and steam can kill)
		if o != e and is_instance_valid(o) and not o.dead and o.hittable and (o.position as Vector2).distance_to(e.position) < o.radius + e.radius + LEAP_REACH:
			burn(o, burn_damage, true)
	e.hurt(burn_damage, Vector2.ZERO, 0.0)


## Chill and fire on one monster: both end in a burst of steam that hurts everything close.
func _steam(e: Node) -> void:
	chills = 0
	chill_t = 0.0
	burning = 0.0
	relight = RELIGHT_GUARD
	steamed = STEAM_GUARD
	_refresh(e)
	var damage: float = e.player.stats.v("damage") * STEAM_DAMAGE
	e.run.fx.ring(e.position - Vector2(0, 6), 4.0, STEAM_RADIUS, 0.3, Color(1, 1, 1), 2.5)
	e.run.fx.burst(e.position - Vector2(0, 6), [Color(1, 1, 1), Color(0.8, 0.9, 1.0)], 10, 70.0, 0.4, 2.0)
	Sfx.play("explosion", -12.0, 0.05, 1.8)
	for o in e.room.enemies.duplicate():
		if is_instance_valid(o) and o.hittable and (o.position as Vector2).distance_to(e.position) < STEAM_RADIUS + o.radius:
			o.hurt(damage, ((o.position as Vector2) - e.position).normalized(), 1.5)


## Works out `speed`, `knock` and the tint from what is on the monster right now.
func _refresh(e: Node) -> void:
	var boss := is_boss(e)
	speed = 1.0
	knock = 1.0
	var tint := Color(1, 1, 1)
	var any := true
	if frozen > 0.0:
		speed = 0.0
		knock = FROZEN_KNOCK
		tint = TINT_FROZEN
	elif chills > 0:
		speed = 1.0 - (minf(BOSS_SLOW, CHILL_SLOW * chills) if boss else CHILL_SLOW * chills)
		tint = TINT_CHILL
	elif burning > 0.0:
		speed = 1.0 if boss else 1.0 + BURN_HASTE
		tint = TINT_BURN
	else:
		any = false
	if (any or _tinted) and e.sprite != null and not e.dead:
		e.sprite.modulate = e._tint * tint
	_tinted = any
