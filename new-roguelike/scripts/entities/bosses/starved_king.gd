extends RefCounted
## THE FINAL BOSS "The Starved King" (floor 4, sprite boss_demon): a winged, skull-faced giant.
## It does not chase. It hovers in the upper middle of the room, wings over the back wall, and
## sways slowly from side to side. Only its lower body is solid; the hero fights it from below
## and from the sides. The toolkit is listed at the top of scripts/entities/boss.gd.
##
## THE ATTACKS (name: the warning -> what the player does about it)
##   SKULL VOLLEY    one of the two chained skulls it holds flares (an orange ring closes on it)
##                   and a thin red lane runs from that skull through the hero; then three shots
##                   fly down the lane. The skulls take turns.          -> step off the lane
##                   Phase 2: both skulls at once, the second aimed where the hero is walking.
##   FALLING EMBERS  it flares its wings ("attack"); red circles appear under and round the hero
##                   and a fireball (the pack's) drops into each. The last is a GREAT EMBER: one
##                   wide circle that bursts with the pack's orange fire.  -> walk out; the
##                   circles never close a ring. Phase 2: the great ember also throws a ring of shots.
##   BLUE BREATH     ("attack2") it turns AWAY from the hero and draws breath: a cyan ring closes
##                   on its skull and a red fan fills that half of the room. It burns that half
##                   blue; meanwhile the OTHER half fills red, then it turns and burns that too.
##                   It rears up off the floor for all of this, so nothing of it can be touched.
##                   -> wait near the King on your side; when the blue fire dies, run under
##                   it to the burnt side. Afterwards it is winded: THE BREATHER (a stagger).
##   GUARDS          at two thirds and at one third of its health it calls two royal guards (a
##                   soldier who chases and an archer who keeps away and shoots) and
##                   only watches while they stand ("watch" seconds at most)  -> cut them down first
## PHASE 2 (half health): the room darkens a little, the attacks come in PAIRS (volley + embers,
##   breath + embers, embers + volley, breath + volley) and the Hungry Curse is drawn into the
##   fight: its lunge timer fills in "curse_fill" seconds instead of 6 (more danger, and more
##   chances to feed it the King).
## LAST STAND (a fifth of its health): it stops swaying and repeats two things:
##   RIPPLE          three red bands spread out from it, one after another  -> step inward,
##                   behind each band as it goes off
##   BLUE BREATH x3  left, right and back again, a skull firing while each half burns
## In a pair with the breath, the second attack only comes while a half burns (the hero stands
## and waits then), never in the moments he has to run under the King.
## DEATH (the pack drew none): its wings burn away from the tips inward, the chained skulls
##   burst, the body fades, its own skull hangs in the air a moment longer, then shatters in a
##   white-out. Made by the helper node "Court" at the bottom of this file, on top of the base's
##   slow motion, shakes and shockwaves.
## Also made by "Court": a thin cyan rim round the dark body (it flashes white when a shot lands,
## the body itself only pales a little), the sprite turning half see-through while the hero stands
## behind it, and the darker room of phase 2.
##
## params (bosses.gd): home_y px (where its feet hover), sway px to each side, volley_warn s,
##   volley_speed px/s, ember_radius px, ember_warn s, great_radius px, great_warn s,
##   rest s (the pause after a volley or the embers; phase 2 takes four fifths of it),
##   breath_warn s (the first inhale), turn_warn s (the turn between two breaths), winded s,
##   ripple_warn s, guard / guard2 (enemy ids, called in turn), guards (how many per call), watch s, curse_fill s,
##   dark (0..1, how much light phase 2 leaves)
const CAST := 0             # timers run the attack; the next one is picked when e.t runs out
const BREATH := 1           # the breath's own callbacks move the fight on
const FAN := 1.5            # half-angle of one breath fan (radians): a fan is one half of the room
const TIP_BACK := 6.0       # a fan starts this far behind the King's middle, so the two overlap under it
const RISE := 7.0           # px it lifts off the floor while it breathes (from 6 px up a boss cannot be touched)
const LANE_HALF := 4.0
const FALL := 0.36          # seconds a fireball takes to drop into its circle
const FALL_FROM := Vector2(-34.0, -72.0)
const RIPPLE := [25.0, 56.0, 92.0, 152.0]
const RIPPLE_GAP := 0.55
## The test bot reads a cone as a narrow wedge; a fan as wide as half the room is handed to it
## as one very wide lane instead (it then walks toward the King's middle, the right way out).
const BOT_HW := 320.0
const BOT_SOFT := 64.0      # until the first half is out, the bot is only asked to come this close to the middle
const CYAN := Color(0.30, 0.90, 1.0)
const BLUE := Color(0.10, 0.70, 1.0)
const BLUES := [Color(0.0, 0.87, 0.96), Color(0.0, 0.69, 0.85), Color(0.75, 0.97, 1.0)]
const FIRE := [Color(1.0, 0.62, 0.10), Color(0.92, 0.30, 0.10), Color(1.0, 0.86, 0.40)]
## px from the feet point, facing right (read off the frames): the two chained skulls it holds
## (standing, and with its arms thrown up in "attack" / "attack2") and its own skull
const HANDS_IDLE := [Vector2(-47, -57), Vector2(35, -72)]
const HANDS_CAST := [Vector2(-67, -64), Vector2(35, -70)]
const SKULL := Vector2(2, -89)
const FX_FIRE := "boss_fx_demon_fireball"            # frame 0 a falling fireball, 1-4 its burst
const FX_BLUE := "boss_fx_demon_fireball_blue"


func start(e) -> void:
	e.state = CAST
	e.t = 1.6
	e.mem = {"home": Vector2(G.ROOM_W * 0.5, _p(e, "home_y", 66.0)), "sway": 0.0, "hold": 0.0, "step": 0, "guards": 0,
		"side": 1.0, "breaths": 0, "burn_t": 0.0, "burn_side": 1.0, "burn_fx": 0.0, "next_half": null, "falls": [], "watch": 0.0}
	var court := Court.new()
	court.setup(e, _p(e, "curse_fill", 3.5), _p(e, "dark", 0.78))
	e.room.ysort.add_child(court)


func phase_changed(e, _phase: int) -> void:
	# the base has already taken back the marks and the timers
	e.mem["burn_t"] = 0.0
	e.mem["next_half"] = null
	e.mem["breaths"] = 0
	e.mem["hold"] = 0.0
	e.mem["step"] = 0
	_clear_falls(e)
	e.state = CAST
	e.t = 1.0


func tick(e, delta: float) -> void:
	e.t -= delta
	e.mem["hold"] = maxf(float(e.mem["hold"]) - delta, 0.0)
	e.mem["watch"] = maxf(float(e.mem["watch"]) - delta, 0.0)
	_tick_falls(e, delta)
	# it rears up off the floor for the breath: nothing of it can be touched then, the way under it is open
	e.lift = move_toward(e.lift, RISE if e.state == BREATH else 0.0, delta * 30.0)
	if float(e.mem["burn_t"]) > 0.0:
		_tick_burn(e, delta)
	if e.state == CAST:
		if not e.busy() and float(e.mem["hold"]) <= 0.0:
			_sway(e, delta)
		# while the guards it called still stand, it only watches (for a few seconds at most)
		if e.t <= 0.0 and not e.busy() and (float(e.mem["watch"]) <= 0.0 or e.minion_count() == 0):
			_pick(e)


func _p(e, key: String, fallback: float) -> float:
	return float(e.p.get(key, fallback))


## It hangs over one spot and drifts from side to side (in the last stand it holds the middle).
func _sway(e, delta: float) -> void:
	var looks: float = e.facing
	var to: Vector2 = e.mem["home"]
	if e.phase < 3:
		e.mem["sway"] = float(e.mem["sway"]) + delta * 0.55
		to += Vector2(sin(float(e.mem["sway"])) * _p(e, "sway", 44.0), 0.0)
	e.move_toward(to, delta)
	# it looks at the hero, but does not flip back and forth while he stands right under it
	var dx: float = e.player.position.x - e.position.x
	e.face(Vector2(dx if absf(dx) > 18.0 else looks, 0.0))


func _pick(e) -> void:
	var calls := int(e.mem["guards"])
	if calls < 2 and e.hp <= e.max_hp * (0.667 if calls == 0 else 0.333):
		e.mem["guards"] = calls + 1
		_call_guards(e)
		return
	var step := int(e.mem["step"])
	e.mem["step"] = step + 1
	if e.phase >= 3:
		if step % 2 == 0:
			_ripple(e)
		else:
			var warn3 := _p(e, "breath_warn", 1.4) * 0.8
			_breath(e, 3, warn3)
			_volley(e, 3, false, _beat(e), warn3 + 0.1)      # one burst while each half burns
		return
	var pairs: bool = e.phase >= 2
	match step % 4:
		0:
			e.t = _volley(e, 3 if pairs else 4, pairs, 1.0 if pairs else 0.8) + _p(e, "rest", 1.5) * (0.8 if pairs else 1.0)
			if pairs:
				_embers(e, 3, false, 0.5)
		1, 3:
			# the second attack of a pair only comes while a half burns (the hero stands and waits
			# then), never in the moments he has to run under the King
			var warn2 := _p(e, "breath_warn", 1.4) * (0.85 if pairs else 1.0)
			_breath(e, 2, warn2)
			if pairs and step % 4 == 1:
				e.after(warn2 - 0.1, _ember_wave)
				e.after(warn2 - 0.1 + _beat(e), _ember_wave)
			elif pairs:
				_volley(e, 2, false, _beat(e), warn2 - 0.2)
		2:
			e.play("attack")
			e.tell(0.6)
			Sfx.play("boss_roar", -10.0, 0.0, 1.35)
			e.t = _embers(e, 4 if pairs else 3, true, 0.6) + _p(e, "rest", 1.5) * (0.8 if pairs else 1.0)
			if pairs:
				_volley(e, 3, false, 1.1, 0.9)


## Seconds from the start of one breath's fire to the start of the next one's.
func _beat(e) -> float:
	return _burn_time(e) + _tail_time(e) + _p(e, "turn_warn", 1.0)


# ------------------------------------------------------------------------------ SKULL VOLLEY
## Schedules `bursts` aimed bursts, `gap` seconds apart, and returns how long that takes.
func _volley(e, bursts: int, both: bool, gap: float, delay: float = 0.2) -> float:
	for k in bursts:
		e.after(delay + gap * float(k), _aim.bind(-1 if both else k % 2))
	return delay + gap * float(bursts - 1) + _p(e, "volley_warn", 0.6) + 0.4


## Where a chained skull is on screen (0 = the one behind its back, 1 = the one in front).
func _hand(e, which: int) -> Vector2:
	var hands: Array = HANDS_IDLE if e.sprite.animation == e.idle_anim else HANDS_CAST
	return e.at_feet(hands[which])


func _aim(e, which: int) -> void:
	var warn := _p(e, "volley_warn", 0.6)
	e.mem["hold"] = warn + 0.4           # it hangs still while it aims, so the shots leave where the lane starts
	for s in ([0, 1] if which < 0 else [which]):
		var px := _hand(e, s)
		var from: Vector2 = px + Vector2(0, e.SHOT_PLANE)
		var at: Vector2 = e.player.position
		if which < 0 and s == 1:
			at += e.player.vel * 0.45       # the second lane cuts off the way he is walking
		var d := (at - from).normalized()
		e.mark_lane(from, from + d * 360.0, LANE_HALF, warn)
		e.run.fx.ring(px, 13.0, 3.0, warn, FIRE[0], 2.0)
		e.after(warn, _burst.bind(from, d, px))
	Sfx.play("ui_click", -8.0, 0.0, 0.6)


func _burst(e, from: Vector2, d: Vector2, px: Vector2) -> void:
	for k in 3:
		e.after(0.11 * float(k), _shot.bind(from, d))
	e.run.fx.burst(px, FIRE, 6, 50.0, 0.3, 2.0)
	Sfx.play("enemy_shoot", -3.0, 0.05, 0.75)


func _shot(e, from: Vector2, d: Vector2) -> void:
	e.shoot_from(from, d, _p(e, "volley_speed", 105.0))


# ------------------------------------------------------------------------------ FALLING EMBERS
## Schedules `waves` of small embers (and the great ember after them) and returns how long that takes.
func _embers(e, waves: int, great: bool, delay: float) -> float:
	var gap := 0.75
	for k in waves:
		e.after(delay + gap * float(k), _ember_wave)
	if not great:
		return delay + gap * float(waves - 1) + _p(e, "ember_warn", 0.85) + 0.3
	e.after(delay + gap * float(waves), _great_mark)
	return delay + gap * float(waves) + _p(e, "great_warn", 1.0) + 0.3


func _in_room(at: Vector2) -> Vector2:
	return Vector2(clampf(at.x, 10.0, G.ROOM_W - 10.0), clampf(at.y, 10.0, G.ROOM_H - 8.0))


## One circle under the hero and two beside him, never touching (there is always a way out).
func _ember_wave(e) -> void:
	var r := _p(e, "ember_radius", 13.0)
	var warn := _p(e, "ember_warn", 0.85)
	var hero: Vector2 = e.player.position
	var spots: Array = [_in_room(hero + e.player.vel * 0.2)]
	var turn: float = e.rng.randf() * TAU
	for k in 2:
		turn += e.rng.randf_range(2.0, 3.0)
		var at := _in_room(hero + Vector2.RIGHT.rotated(turn) * e.rng.randf_range(30.0, 44.0))
		var free := true
		for other: Vector2 in spots:
			if other.distance_to(at) < r * 2.0 + 12.0:
				free = false
		if free:
			spots.append(at)
	for at: Vector2 in spots:
		e.mark_circle(at, r, warn)
		e.after(maxf(warn - FALL, 0.0), _drop.bind(at))
		e.after(warn, _land.bind(at, r))


## The pack's falling fireball (frame 0 of the effect) drops into the circle at `at`.
func _drop(e, at: Vector2) -> void:
	var ball: Node2D = e.fx_sprite(FX_FIRE, at + FALL_FROM, {"from": 0, "to": 0, "loop": true, "life": FALL + 1.5,
		"flip": false, "anchor": Vector2(52, 33)})
	if ball != null:
		(e.mem["falls"] as Array).append([ball, at, FALL])


func _tick_falls(e, delta: float) -> void:
	for row: Array in e.mem["falls"]:
		row[2] = maxf(float(row[2]) - delta, 0.0)
		if is_instance_valid(row[0]):
			(row[0] as Node2D).position = (row[1] as Vector2) + FALL_FROM * (float(row[2]) / FALL)


## Takes the fireballs that were falling toward `at` off the screen (they have landed).
func _clear_falls(e, at: Vector2 = Vector2.INF) -> void:
	var falls: Array = e.mem["falls"]
	for k in range(falls.size() - 1, -1, -1):
		if at == Vector2.INF or (falls[k][1] as Vector2).distance_to(at) < 16.0:
			if is_instance_valid(falls[k][0]):
				(falls[k][0] as Node).queue_free()
			falls.remove_at(k)


func _land(e, at: Vector2, r: float) -> void:
	_clear_falls(e, at)
	e.strike_circle(at, r)
	e.run.fx.burst(at, FIRE, 9, 70.0, 0.4, 2.2)
	e.run.fx.ring(at, 3.0, r, 0.2, FIRE[1], 2.0, true)
	e.run.shake(0.12)
	Sfx.play("explosion", -13.0, 0.08, 1.7)


func _great_mark(e) -> void:
	var r := _p(e, "great_radius", 30.0)
	var warn := _p(e, "great_warn", 1.0)
	var at := _in_room(e.player.position)
	e.mark_circle(at, r, warn)
	for k in 3:
		e.after(maxf(warn - FALL - 0.07 * float(k), 0.0), _drop.bind(at + Vector2(-9.0 + 9.0 * float(k), 0.0)))
	e.after(warn, _great_land.bind(at, r))


func _great_land(e, at: Vector2, r: float) -> void:
	_clear_falls(e, at)
	e.strike_circle(at, r)
	# the pack's own burst, standing on the spot and sorted against the hero like a character
	var fire: Node2D = e.fx_sprite(FX_FIRE, at, {"from": 1, "to": 4, "fps": 11.0, "flip": e.rng.randf() < 0.5, "anchor": Vector2(67, 64)})
	if fire != null:
		fire.z_index = 0
	e.run.fx.burst(at, FIRE, 22, 110.0, 0.5, 2.6)
	e.run.fx.ring(at, 4.0, r, 0.25, FIRE[1], 3.0, true)
	e.run.shake(0.45)
	Sfx.play("explosion", -5.0, 0.05, 0.95)
	if e.phase >= 2:
		e.ring_from(at, 8, 52.0, "", e.rng.randf() * TAU)


# ------------------------------------------------------------------------------ BLUE BREATH
## `sides` breaths in a row, the first on the half the hero is NOT in.
func _breath(e, sides: int, warn: float) -> void:
	e.state = BREATH
	e.mem["breaths"] = sides
	e.mem["next_half"] = null
	var side := -signf(e.player.position.x - e.position.x)
	if side == 0.0:
		side = 1.0
	_mark_half(e, side, warn, 0.0)
	_inhale(e, side, warn)
	# the half the hero stands in is next. A player who knows the fight walks to the King at the
	# inhale; the test bot is told the same (a row for the bot only, nothing is drawn)
	e.mem["next_half"] = _bot_half(e, -side, warn + _burn_time(e) + _tail_time(e) + _p(e, "turn_warn", 1.0) + 0.1, BOT_SOFT)


func _inhale(e, side: float, warn: float) -> void:
	e.mem["side"] = side
	e.face(Vector2(side, 0.0))
	e.strike("attack2", warn, _burn_begin, _breath_done)
	e.run.fx.ring(e.at_feet(SKULL), 46.0, 6.0, warn, CYAN, 2.0)
	Sfx.play("boss_roar", -9.0, 0.0, 1.6)


## The point a fan opens from: a little behind the King's middle.
func _tip(e, side: float) -> Vector2:
	return e.position - Vector2(side * TIP_BACK, 0.0)


## How long the fire of one breath burns (the frames of "attack2" that show it), and the rest of the animation.
func _burn_time(e) -> float:
	return Art.frame_time(e._sprite_id, "attack2", 16) - e.hit_time("attack2")


func _tail_time(e) -> float:
	return e.anim_time("attack2") - Art.frame_time(e._sprite_id, "attack2", 16)


## Draws the fan over the half of the room on `side` (+1 right, -1 left): red = a warning, blue = it burns.
func _fan(e, side: float, seconds: float, color: Color) -> void:
	var tip := _tip(e, side)
	var corner := Vector2(G.ROOM_W if side > 0.0 else 0.0, 0.0 if tip.y > G.ROOM_H * 0.5 else G.ROOM_H)
	e.mark_cone(tip, Vector2(side, 0.0), tip.distance_to(corner) + 4.0, FAN, seconds, color)
	e.run.fx.hazards.pop_back()          # the cone the mark just told the bot about (see BOT_HW)


## The red fan, and the bot's row for it (returned).
func _mark_half(e, side: float, seconds: float, soft: float) -> Array:
	_fan(e, side, seconds, e.RED)
	return _bot_half(e, side, seconds + 0.1, soft)


func _bot_half(e, side: float, seconds: float, soft: float) -> Array:
	var x: float = _tip(e, side).x + side * (soft + BOT_HW)
	var row: Array = [1, Vector2(x, -80.0), Vector2(x, G.ROOM_H + 80.0), BOT_HW, seconds, e.get_instance_id(), 0.0]
	e.run.fx.hazards.append(row)
	return row


## The hit frame of "attack2": the fire is out. It burns as long as the animation shows it.
func _burn_begin(e, _frame: int) -> void:
	var side: float = e.mem["side"]
	var burn := _burn_time(e)
	e.mem["burn_side"] = side
	e.mem["burn_t"] = burn
	e.mem["burn_fx"] = 0.0
	_bot_half(e, side, burn, 0.0)
	# the red fan has just run out: the same fan in the breath's own blue shows what burns, as long as it burns
	_fan(e, side, burn, BLUE)
	e.run.shake(0.5)
	e.run.fx.flash(Color(0.45, 0.9, 1.0, 0.16), 0.2)
	Sfx.play("explosion", -5.0, 0.0, 0.55)
	if int(e.mem["breaths"]) > 1:
		# the other half is next: it fills while this one burns and while the King turns
		var wait: float = burn + _tail_time(e) + _p(e, "turn_warn", 1.0)
		_fan(e, -side, wait, e.RED)
		if e.mem["next_half"] == null:
			e.mem["next_half"] = _bot_half(e, -side, wait + 0.1, BOT_SOFT)


func _tick_burn(e, delta: float) -> void:
	var side: float = e.mem["burn_side"]
	var tip := _tip(e, side)
	e.mem["burn_t"] = float(e.mem["burn_t"]) - delta
	e.strike_cone(tip, Vector2(side, 0.0), 420.0, FAN)
	e.mem["burn_fx"] = float(e.mem["burn_fx"]) - delta
	if float(e.mem["burn_fx"]) <= 0.0:
		e.mem["burn_fx"] = 0.14
		# the pack's blue burst, here and there on the burning half, sorted like a character
		var width: float = (G.ROOM_W - tip.x) if side > 0.0 else tip.x
		var at := Vector2(tip.x + side * e.rng.randf_range(66.0, maxf(70.0, width - 24.0)), e.rng.randf_range(36.0, G.ROOM_H - 2.0))
		var fire: Node2D = e.fx_sprite(FX_BLUE, at, {"from": 1, "to": 4, "fps": 10.0, "flip": side < 0.0, "anchor": Vector2(67, 66)})
		if fire != null:
			fire.z_index = 0
		e.run.fx.burst(e.muzzle_px("attack2"), BLUES, 4, 80.0, 0.4, 2.2, Vector2(side, 0.5))
	if float(e.mem["burn_t"]) <= 0.0 and e.mem["next_half"] != null:
		# this half is out: now the bot is told the whole truth about the other one
		var row: Array = e.mem["next_half"]
		var x: float = _tip(e, -side).x - side * BOT_HW
		row[1] = Vector2(x, -80.0)
		row[2] = Vector2(x, G.ROOM_H + 80.0)
		e.mem["next_half"] = null


func _breath_done(e) -> void:
	var left := int(e.mem["breaths"]) - 1
	e.mem["breaths"] = left
	if left > 0:
		_inhale(e, -float(e.mem["side"]), _p(e, "turn_warn", 1.0))
		return
	# out of breath: the breather
	e.state = CAST
	e.t = 0.5
	e.stagger(_p(e, "winded", 2.0))


# ------------------------------------------------------------------------------ GUARDS
func _call_guards(e) -> void:
	e.play("attack")
	e.tell(0.6)
	e.t = 2.2
	e.mem["watch"] = _p(e, "watch", 5.0) if e.phase < 3 else 0.0     # no pause in the last stand
	Sfx.play("boss_roar", -4.0, 0.0, 1.25)
	e.after(0.6, _guards_rise)


func _guards_rise(e) -> void:
	# a pair: every second one is the row's "guard2" (a soldier and an archer)
	for k in int(_p(e, "guards", 2.0)):
		var id := String(e.p.get("guard", "pit_guard")) if k % 2 == 0 else String(e.p.get("guard2", e.p.get("guard", "pit_guard")))
		e.summon_minions(id, 1, {"delay": 1.0, "far": 50.0})
	e.run.shake(0.3)
	Sfx.play("door_open", -4.0, 0.0, 0.7)


# ------------------------------------------------------------------------------ RIPPLE (last stand)
func _ripple(e) -> void:
	var warn := _p(e, "ripple_warn", 0.9)
	e.play("attack")
	e.tell(0.6)
	Sfx.play("boss_roar", -8.0, 0.0, 0.8)
	for k in 3:
		e.after(RIPPLE_GAP * float(k), _ripple_mark.bind(k, e.position, warn))
	e.t = RIPPLE_GAP * 2.0 + warn + 0.7


func _ripple_mark(e, k: int, at: Vector2, warn: float) -> void:
	e.mark_ring(at, RIPPLE[k], RIPPLE[k + 1], warn)
	e.after(warn, _ripple_hit.bind(k, at))


func _ripple_hit(e, k: int, at: Vector2) -> void:
	e.strike_ring(at, RIPPLE[k], RIPPLE[k + 1])
	e.run.fx.ring(at, RIPPLE[k], RIPPLE[k + 1], 0.22, FIRE[1], 4.0, true)
	for n in 10:
		var d := Vector2.RIGHT.rotated(e.rng.randf() * TAU)
		e.run.fx.burst(_in_room(at + d * (RIPPLE[k] + RIPPLE[k + 1]) * 0.5), FIRE, 2, 40.0, 0.35, 2.2, d * 0.6)
	e.run.shake(0.3)
	Sfx.play("explosion", -8.0, 0.05, 1.0 + 0.2 * float(k))


# =============================================================================== the Court
## A helper node that lives beside the King (it must outlive him: the skull falls last).
## It never deals damage. It makes: the cyan rim, the see-through body while the hero is behind
## it, the darker room and the hungrier Curse of phase 2, and the death.
class Court extends Node2D:
	const CurseScript = preload("res://scripts/entities/curse.gd")
	## A 1 px line round the artist's own silhouette, nothing else.
	const RIM_SHADER := "shader_type canvas_item;\nrender_mode unshaded;\nuniform vec4 rim : source_color = vec4(0.3, 0.9, 1.0, 0.6);\nvoid fragment() {\n\tvec2 px = TEXTURE_PIXEL_SIZE;\n\tfloat a = texture(TEXTURE, UV).a;\n\tfloat n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a + texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;\n\tCOLOR = vec4(rim.rgb, (a < 0.5 && n > 0.5) ? rim.a : 0.0);\n}\n"
	## Keeps only the skull's own pixels (its blues) of the piece cut out of the frame, and can whiten them.
	const SKULL_SHADER := "shader_type canvas_item;\nrender_mode unshaded;\nuniform float glow = 0.0;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat keep = step(0.3, c.b) * step(c.r, 0.15);\n\tCOLOR = vec4(mix(c.rgb, vec3(1.0), glow), c.a * keep);\n}\n"
	## Its hit flash: the base turns a boss nearly white, and a giant going white several times a
	## second hides the fight. The King only pales a little; its rim flashes white instead.
	const SOFT_HIT_SHADER := "shader_type canvas_item;\nrender_mode unshaded;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = vec4(mix(c.rgb, vec3(1.0), 0.22), c.a);\n}\n"
	const RIM_COLOR := Color(0.3, 0.9, 1.0, 0.6)
	const SKULL_RECT := Rect2(86, 68, 33, 30)        # its skull in frame 0 of "idle" (canvas px)
	const WING_TIPS := [Vector2(-86, -122), Vector2(40, -128)]
	const WING_ROOTS := [Vector2(-18, -84), Vector2(12, -86)]
	const HANDS := [Vector2(-47, -57), Vector2(35, -72)]
	const WING_COLORS := [Color(0.80, 0.22, 0.20), Color(0.33, 0.11, 0.12), Color(1.0, 0.62, 0.10)]
	const BONE := [Color(0.0, 0.87, 0.96), Color(0.75, 0.97, 1.0), Color(1, 1, 1)]
	const BLOWS := [0.10, 0.28, 0.46, 0.58, 0.66]  # shares of the death where a big piece goes
	const HANG := 1.1                                # seconds the skull hangs alone before it shatters

	var boss: Node2D
	var run: Node
	var room: Node
	var rim: AnimatedSprite2D
	var soft_hit: ShaderMaterial
	var skull: Sprite2D
	var skull_at := Vector2.ZERO
	var lit := Color(1, 1, 1)
	var dim := Color(1, 1, 1)
	var dark := 0.0
	var hunger := 3.5
	var hungry := false
	var stage := -1
	var puff := 0.0
	var gone := -1.0

	func setup(the_boss: Node2D, curse_fill: float, light_left: float) -> void:
		boss = the_boss
		run = boss.run
		room = boss.room
		hunger = curse_fill
		z_index = 3
		lit = run.ambient.color
		dim = Color(lit.r * light_left, lit.g * light_left * 0.97, lit.b * minf(light_left * 1.12, 1.0))
		var s: AnimatedSprite2D = boss.sprite
		rim = AnimatedSprite2D.new()
		rim.sprite_frames = s.sprite_frames
		rim.centered = s.centered
		rim.offset = s.offset
		rim.show_behind_parent = true
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = RIM_SHADER
		rim.material = mat
		s.add_child(rim)
		soft_hit = ShaderMaterial.new()
		soft_hit.shader = Shader.new()
		soft_hit.shader.code = SOFT_HIT_SHADER

	func _exit_tree() -> void:
		if run != null and is_instance_valid(run) and run.ambient != null:
			run.ambient.color = lit

	func _physics_process(delta: float) -> void:
		if gone >= 0.0:
			_last_of_it(delta)
			return
		if not is_instance_valid(boss):
			if skull == null:
				queue_free()
			else:
				gone = 0.0
				run.fx.ring(skull_at, 40.0, 5.0, HANG, BONE[0], 2.0)
			return
		if boss.dying > 0.0:
			_falling_apart(delta)
			return
		if boss.dead:
			return
		var s: AnimatedSprite2D = boss.sprite
		if rim.animation != s.animation:
			rim.animation = s.animation
		rim.frame = s.frame
		var hit: bool = s.material != null and s.material == boss.hit_material()
		if hit:
			s.material = soft_hit
		(rim.material as ShaderMaterial).set_shader_parameter("rim", Color(1, 1, 1, 1) if hit else RIM_COLOR)
		# the hero behind the King would be hidden by it: the body goes half see-through
		var p: Node2D = boss.player
		if p == null or not is_instance_valid(p):
			return
		var along: float = (p.position.x - boss.position.x) * boss.facing
		var behind: bool = p.position.y < boss.position.y - 3.0 and along > -96.0 and along < 50.0
		s.modulate.a = move_toward(s.modulate.a, 0.42 if behind else 1.0, delta * 5.0)
		# phase 2: the room darkens a little and the Curse grows hungrier
		var want := 1.0 if boss.phase >= 2 else 0.0
		if dark != want:
			dark = move_toward(dark, want, delta * 0.7)
			run.ambient.color = lit.lerp(dim, dark)
		if boss.phase >= 2:
			var c: Node2D = room.curse
			if c != null and is_instance_valid(c) and c.state == CurseScript.CREEP:
				if c.fill_time > hunger:
					c.fill_time = hunger
				if not hungry:
					hungry = true
					run.fx.burst(c.position, [Color(0.98, 0.93, 0.66), Color(0.05, 0.04, 0.06)], 16, 60.0, 0.6, 2.4)
					Sfx.play("curse_whisper", -4.0, 0.0, 0.8)

	## The death, on top of what boss.gd does (slow motion, shakes, shockwaves, the fade):
	## the wings burn from the tips inward, the big pieces go one by one, the skull stays.
	func _falling_apart(delta: float) -> void:
		var k: float = clampf(1.0 - boss.dying / maxf(boss._death_total, 0.01), 0.0, 1.0)
		var s: AnimatedSprite2D = boss.sprite
		if stage < 0:
			stage = 0
			rim.visible = false
			s.modulate.a = 1.0
			s.animation = "idle"             # wings spread, whatever it was doing when it fell
			s.frame = 0
		dark = move_toward(dark, 0.0, delta * 0.6)
		run.ambient.color = lit.lerp(dim, dark)
		puff -= delta
		if puff <= 0.0 and k < 0.7:
			puff = 0.11
			var u := clampf(k / 0.6, 0.0, 1.0)
			for w in 2:
				var at: Vector2 = boss.at_feet((WING_TIPS[w] as Vector2).lerp(WING_ROOTS[w], u)) + Vector2(randf_range(-5, 5), randf_range(-5, 5))
				run.fx.burst(at, WING_COLORS, 7, 65.0, 0.55, 2.6)
				run.fx.ring(at, 2.0, 13.0, 0.22, WING_COLORS[2], 1.5)
		while stage < BLOWS.size() and k >= float(BLOWS[stage]):
			_blow(stage)
			stage += 1
		if skull == null and k >= 0.72:
			_keep_skull()
		if skull != null:
			skull.position = skull_at + Vector2(randf_range(-1.0, 1.0), 0.0)

	## 0, 1: the pack's orange burst on each wing. 2: its blue burst on the chest. 3, 4: the chained skulls.
	func _blow(n: int) -> void:
		if n < 2:
			var fire: Node2D = boss.fx_sprite("boss_fx_demon_fireball", boss.at_feet(WING_TIPS[n] * 0.8), {"from": 1, "to": 4, "fps": 9.0, "anchor": Vector2(67, 40)})
			if fire != null:
				fire.z_index = 2
		elif n == 2:
			var blue: Node2D = boss.fx_sprite("boss_fx_demon_fireball_blue", boss.at_feet(Vector2(0, -50)), {"from": 1, "to": 4, "fps": 9.0, "anchor": Vector2(67, 40)})
			if blue != null:
				blue.z_index = 2
		else:
			var at: Vector2 = boss.at_feet(HANDS[n - 3])
			run.fx.burst(at, [Color(1.0, 0.62, 0.10), Color(1.0, 0.86, 0.40), Color(1, 1, 1)], 16, 90.0, 0.5, 2.6)
			run.fx.ring(at, 2.0, 20.0, 0.3, Color(1.0, 0.62, 0.10), 2.0)
			Sfx.play("enemy_die", -4.0, 0.05, 0.7)
		run.shake(0.5)

	## Cuts its skull out of the frame it is dying in and hangs it where it is drawn.
	func _keep_skull() -> void:
		var piece := AtlasTexture.new()
		piece.atlas = boss.sprite.sprite_frames.get_frame_texture("idle", 0)
		piece.region = SKULL_RECT
		var feet: Array = boss.meta.get("feet", [100, 171])
		var mid := SKULL_RECT.get_center() - Vector2(float(feet[0]), float(feet[1]))
		skull = Sprite2D.new()
		skull.texture = piece
		skull.flip_h = boss.facing < 0.0
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = SKULL_SHADER
		skull.material = mat
		skull_at = boss.position + Vector2(mid.x * boss.facing, boss.sprite.position.y + mid.y)
		skull.position = skull_at
		add_child(skull)

	## The King is gone; the skull hangs a moment, whitens, and shatters in a white-out.
	func _last_of_it(delta: float) -> void:
		gone += delta
		run.ambient.color = lit
		var k := clampf(gone / HANG, 0.0, 1.0)
		skull.position = skull_at + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (0.5 + 1.5 * k)
		(skull.material as ShaderMaterial).set_shader_parameter("glow", k * k)
		puff -= delta
		if puff <= 0.0:
			puff = 0.09
			run.fx.burst(skull_at, BONE, 2, 30.0 + 50.0 * k, 0.4, 2.0)
		if gone < HANG:
			return
		run.fx.burst(skull_at, BONE, 70, 210.0, 1.0, 3.0)
		run.fx.ring(skull_at, 4.0, 200.0, 0.8, Color(1, 1, 1), 5.0)
		run.fx.flash(Color(1, 1, 1, 1.0), 1.4)
		run.shake(1.0)
		Sfx.play("explosion", 0.0, 0.0, 0.7)
		Sfx.play("enemy_die_big", -2.0, 0.0, 1.4)
		queue_free()
