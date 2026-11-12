extends "res://scripts/entities/enemy.gd"
## Boss: the shared base for every boss. What a boss IS comes from its row in scripts/data/bosses.gd,
## how it LOOKS from assets/art/boss/boss_cast.json (feet point, hover height, body size, hit frames,
## where shots leave), and its FIGHT is one file in scripts/entities/bosses/<script>.gd.
##
## ------------------------------------------------------------------ writing a boss file
##     extends RefCounted
##     func start(e) -> void                      # once, when the boss has appeared
##     func tick(e, delta: float) -> void         # every physics frame (not while it is stunned or staggered)
##     func phase_changed(e, phase: int) -> void  # optional: phase 2 starts under half health (3 = the row's second "phases" number)
## ONE object of the file serves every boss that uses it: keep memory ON THE BOSS, exactly like an
## enemy AI file (e.state, e.t, e.t2, e.dir, e.target, e.mem, e.p = the row's "params", e.rng, e.phase).
## Everything enemy.gd offers still works (chase, move_toward, dash, shoot*, tell, summon, lift ...).
## A callback is a function of the boss file that takes the boss:  func _lands(e) -> void
## (an animation's hit callback also takes the frame:  func _hits(e, frame: int) -> void).
##
## THE TOOLKIT (all on `e`)
##   Animations (the boss never walks or flips in the middle of one)
##     e.play(anim, on_hit, on_end, speed, lead)   play an animation once; on_hit(e, frame) on each hit frame,
##                                                 on_end(e) when it is over; `lead` s holds frame 0 first
##     e.strike(anim, seconds, on_hit, on_end)     the same, timed so the FIRST hit frame comes exactly
##                                                 `seconds` after the call (= the time of your floor mark)
##     e.hit_time(anim) / e.anim_time(anim)        seconds from the start to the first hit frame / to the end
##     e.pose(anim, frame)   e.stop()              freeze on one frame / drop the animation (no on_end)
##     e.busy()                                    true while play() or strike() is running
##     e.set_loops(idle, run)                      which loops it stands and walks in ("idle_unarmed", "nofire" ...)
##     e.face_player()  e.face(dir)  e.facing      +1 = looks right, -1 = left (rows with "no_facing" never flip)
##   Places
##     e.muzzle(anim)        where a SHOT leaves in that animation (boss_cast.json, mirrored by the facing)
##     e.muzzle_px(anim)     the same spot on screen, for effects
##     e.at_feet(Vector2(forward, -up))            a spot on screen relative to the feet, mirrored
##     e.body_point()                              the middle of the body on screen
##   Shots (they refuse to fire once SHOT_CAP shots are on screen)
##     e.shoot_from(at, dir, speed, type, extra)   e.fan_from(at, dir, n, arc, speed, type)
##     e.ring_from(at, n, speed, type, angle)      e.shots_room()  how many more may be fired
##   Floor marks: red, they fill up over `seconds`, the test bot steps out of them. Mark first, strike after.
##     e.mark_circle(at, r, seconds)               e.strike_circle(at, r) -> bool   (true = the hero was hurt)
##     e.mark_lane(from, to, half_width, seconds)  e.strike_lane(from, to, half_width)
##     e.mark_charge(dir, length, seconds)         the lane its own BODY will sweep (touching it is what hurts)
##     e.mark_cone(tip, dir, length, half_angle, seconds)   e.strike_cone(tip, dir, length, half_angle)
##     e.mark_ring(at, r_inner, r_outer, seconds)  e.strike_ring(at, r_inner, r_outer)
##     e.in_circle / in_lane / in_cone / in_ring   the same tests without the damage
##     e.burn_ground(at, r, seconds, arm)          ground that keeps hurting (armed after `arm` s)
##   Time and rhythm
##     e.after(seconds, callback)                  call callback(e) later (frozen while the boss is stunned)
##     e.stagger(seconds, anim)                    THE BREATHER: it stands dazed and the fight file is not
##                                                 ticked; shots hurt it "stagger_dmg" times as much
##     e.cancel()                                  stop the animation, forget the timers, take back its marks
##   Helpers and effects
##     e.summon_minions(enemy_id, count, opts)     marked spots away from the hero, never more than opts.max (4)
##     e.fx_sprite(id, at, opts)                   play a boss_fx_* animation; returns the sprite node
##     e.cut_sprite(anim, frame, rect)             a piece cut out of one of its own frames (a thrown weapon)
## Hit flash, phase roar and death are made here: the pack's own "hit" / "death" frames where it
## has them, otherwise code effects (white flash, shake, bursts in its own colours, fade).
## Test flags: --boss=<row key> (this boss on any floor), --bosshp=<n> (its hit points),
## --bosslog (prints phases, staggers and WHAT hurt the hero), with --goto=boss --floor=N.
## Rules: every blow gets a mark of at least 0.5 s on floor 1 and never under 0.35 s; marks are RED
## (pale gold on the floor belongs to the Hungry Curse); always leave somewhere safe to stand.

const BossStory = preload("res://scripts/data/story.gd")
const Bosses = preload("res://scripts/data/bosses.gd")

const DEATH_TIME := 1.7          ## seconds of game time a boss takes to die (it starts in slow motion)
const FINAL_DEATH_TIME := 4.4    ## the final boss
const SHOT_CAP := 120            ## boss shots stop being fired when this many shots are on screen
const SHOT_RANGE := 300.0
const RED := Color(1.0, 0.22, 0.16)
const EMBER := Color(1.0, 0.42, 0.12)
## The hit flash of a boss: a short, partial flicker (HIT_FLICK s, at most one per HIT_GAP s), so a
## boss under steady fire keeps its real colours almost all the time (a long white-out hid the boss).
const HIT_SHADER := "shader_type canvas_item;\nrender_mode unshaded;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = vec4(mix(c.rgb, vec3(1.0), 0.45), c.a);\n}\n"
const HIT_FLICK := 0.05
const HIT_GAP := 0.3
## A wind-up shows only a brief pale pulse at its start; the red floor marks do the warning.
const TELL_PULSE := 0.12

static var _fx_frames := {}
static var _hit_mat: ShaderMaterial

var phase := 1
var boss_id := ""
var dying := 0.0
var staggered := 0.0             ## > 0 while it stands dazed
var final := false               ## the row's "final": killing it wins the run
var meta: Dictionary = {}        ## its sprite's entry in boss_cast.json
var facing := 1.0                ## the way the sprite looks right now (+1 right, -1 left)
var has_facing := true
var idle_anim := "idle"
var run_anim := "run"
var phase_marks: Array = []      ## health shares where a phase starts (the boss bar draws a notch there)

var _lifted := 0.0               ## px of air under the body (the pack's hover_px + the row's "hover")
var _body_h := 24.0
var _body_w := 24.0
var _bob := 0.0
var _bob_t := 0.0
var _stagger_dmg := 1.0
var _north := 0.0                ## it never stands closer than this to the back wall (px of floor)
var _real_hit := false
var _real_death := false
var _play := ""
var _play_hit := Callable()
var _play_end := Callable()
var _play_frames: Array = []
var _play_ends: Array = []
var _play_t := 0.0
var _play_prev := -1
var _play_free := false          ## this animation keeps running while the boss is stunned (entrance, flinch)
var _play_rev := false
var _token := 0
var _cancels := 0
var _posed := false
var _timers: Array = []          ## [seconds left, Callable]
var _burns: Array = []           ## [centre, radius, seconds left, seconds until armed]
var _fx_nodes: Array = []        ## [node, seconds left (looping ones) or -1]
var _death_total := 1.0
var _death_puff := 0.0
var _death_wave := 0
var _log := false                ## --bosslog: print what happens in the fight (see _say)
var _fight_t := 0.0
var _hurt_by := ""
var shielded := false            ## a guard is up: shots do nothing (shots.gd skips it); bombs, burns and Curse bites still land
var _flick := 0.0                ## seconds of hit flicker left
var _flick_gap := 0.0            ## seconds until the next flicker may start


static func hit_material() -> ShaderMaterial:
	if _hit_mat == null:
		_hit_mat = ShaderMaterial.new()
		_hit_mat.shader = Shader.new()
		_hit_mat.shader.code = HIT_SHADER
	return _hit_mat


func _row(enemy_id: String) -> Dictionary:
	boss_id = Bosses.real_id(enemy_id)
	return Bosses.info(enemy_id)


func _hp_scale() -> float:
	return 1.0


func _load_ai() -> RefCounted:
	return ai_for(String(data.get("script", boss_id)), "bosses")


func setup(the_room: Node, enemy_id: String, opts: Dictionary = {}) -> void:
	super.setup(the_room, enemy_id, opts)
	meta = Art.meta(_sprite_id)
	final = data.get("final", false)
	has_facing = not data.get("no_facing", false)
	idle_anim = _idle_anim
	run_anim = String(data.get("run", "run"))
	# the fight file decides when an animation plays: enemy.gd must not start one by itself
	_real_hit = _has_hit
	_real_death = _has_death
	_has_hit = false
	_has_attack = false
	# ---- size, from the measurements in boss_cast.json (a row may overrule "radius", "hit_r", "hit_up")
	_lifted = float(meta.get("hover_px", 0.0)) + _hover
	_body_h = float(meta.get("body_height", 24.0))
	_body_w = float(meta.get("body_width", 24.0))
	radius = float(data.get("radius", meta.get("radius", 14.0)))
	# shots test ONE circle: it starts at the feet line and covers the body, never much wider than it
	var hit_r := clampf((_lifted + _body_h * 0.9) * 0.5, radius, maxf(radius, minf(_body_w * 0.5 + 2.0, 44.0)))
	hit_r = float(data.get("hit_r", hit_r))
	hit_up = float(data.get("hit_up", hit_r - 2.0 + _lifted * 0.5))
	hit_grow = maxf(hit_r - radius, 1.0)
	_mid = _lifted + _body_h * 0.5
	mass = 40.0
	_bob = float(data.get("bob", 1.0 if _lifted > 0.0 else 0.0))
	_stagger_dmg = float(data.get("stagger_dmg", 1.0))
	# a very tall boss keeps off the back wall, or its head would leave the screen
	_north = float(data.get("north", clampf(_body_h + _lifted - 80.0, 0.0, 40.0)))
	if G.arg("bosshp") != "":
		# --bosshp=<n>: a test flag, to reach phase 2 or the death quickly
		max_hp = maxf(float(G.arg("bosshp")), 1.0)
		hp = max_hp
	phase_marks = data.get("phases", [0.5])
	_base_scale = 1.0
	sprite.scale = Vector2.ONE
	var shadow_w := clampf(_body_w * 0.7, radius * 2.0, radius * 3.4)
	shadow.scale = Vector2(shadow_w / 32.0, shadow_w * 0.42 / 32.0)
	# a bigger warning than a normal enemy gets
	run.fx.warn_circle(position, radius * 1.6, appear)


func _appear() -> void:
	sprite.visible = true
	shadow.visible = true
	hittable = true
	run.fx.burst(body_point(), Art.palette(_sprite_id), 14, 70.0, 0.4, 2.4)
	run.boss = self
	run.shake(0.6)
	Sfx.play("boss_roar")
	Sfx.music(String(run.theme.get("boss_music", "boss")))
	G.boss_started.emit(self)
	var says: Dictionary = BossStory.BOSS_SAYS.get(boss_id, {})        # the guardian speaks (scripts/data/story.gd)
	if says.has("start"):
		G.toast.emit(display_name, "\"%s\"" % String(says["start"]))
	G.toast.emit(display_name, "")
	face_player()
	facing = _face
	_log = G.flag("bosslog")
	if _log:
		G.player_hurt.connect(_on_player_hurt)
		_say("appears with %d hp" % int(max_hp))
	if ai.has_method("start"):
		ai.start(self)
	# the row's "enter": an animation it arrives with (the fight starts when it is over)
	var enter := String(data.get("enter", ""))
	if enter != "" and Art.has_anim(_sprite_id, enter):
		stun = maxf(stun, play(enter))
		_play_free = true
		_play_rev = data.get("enter_reverse", false)
		_tick_play(0.0)


func _physics_process(delta: float) -> void:
	if dying > 0.0:
		_tick_death(delta)
		return
	if not dead and appear <= 0.0:
		_fight_t += delta
		_tick_burns(delta)
		_tick_fx(delta)
		if stun > 0.0:
			# stunned (the Curse bit it, or it is staggered): the script stands still and so do its marks
			run.fx.hold_warns(get_instance_id(), delta)
			if staggered > 0.0:
				_tick_stagger(delta)
			if _play != "" and _play_free:
				_tick_play(delta)
		else:
			staggered = 0.0
			_tick_timers(delta)
			if _play != "" and not dead:
				_tick_play(delta)
	if dead:
		return
	super._physics_process(delta)
	if position.y < _north and lift <= 0.0:
		position.y = minf(position.y + 60.0 * delta, _north)
	if not dead and phase <= phase_marks.size() and hp <= max_hp * float(phase_marks[phase - 1]):
		_next_phase()


## --bosslog (a test flag): prints one line per event of the fight, so a builder can see how long
## the fight and each phase last and WHAT hurt the hero (which mark, the body, or a shot).
func _say(what: String) -> void:
	if _log:
		print("BOSSLOG %s t=%.1f phase=%d state=%d hp=%d%% %s" % [boss_id, _fight_t, phase, state, int(100.0 * hp / max_hp), what])


func _on_player_hurt(_half_hearts: int) -> void:
	var why := _hurt_by
	if why == "":
		# a guess from who stands next to the hero (the boss file's own marks are named exactly)
		why = "a shot (or a lobbed rock)"
		var curse: Node2D = room.curse
		if harmful and position.distance_to(player.position) < radius + player.radius + 2.0:
			why = "its body"
		elif curse != null and is_instance_valid(curse) and curse.position.distance_to(player.position) < 30.0:
			why = "the Curse"
		else:
			for e in room.enemies:
				if e != self and e.position.distance_to(player.position) < e.radius + player.radius + 3.0:
					why = "a helper"
	_say("hero hurt by %s (%d px from the boss)" % [why, int(position.distance_to(player.position))])


func _next_phase() -> void:
	phase += 1
	_say("phase %d begins" % phase)
	cancel()
	hittable = true
	harmful = true
	lift = 0.0
	staggered = 0.0
	stun = 0.7
	tell(0.7)
	run.shake(0.5)
	run.fx.ring(body_point(), 6.0, maxf(60.0, _body_h), 0.5, Color(1.0, 0.3, 0.2), 3.0)
	run.fx.burst(body_point(), Art.palette(_sprite_id), 18, 90.0, 0.5, 2.6)
	Sfx.play("boss_roar", 0.0, 0.0)
	_flinch()
	if ai.has_method("phase_changed"):
		ai.phase_changed(self, phase)


# =============================================================================== animations
## Plays `anim` once and returns how long it takes. on_hit(e, frame) is called on each hit frame
## (the row's "hit_frames", else boss_cast.json's, else the last frame), on_end(e) when it is over.
## `speed` 2.0 = twice as fast. `lead` seconds hold the first frame before it starts (a wind-up pose).
func play(anim: String, on_hit: Callable = Callable(), on_end: Callable = Callable(), speed: float = 1.0, lead: float = 0.0) -> float:
	var sf := sprite.sprite_frames
	if not sf.has_animation(anim):
		push_warning("Boss %s: no animation '%s'" % [boss_id, anim])
		anim = idle_anim
	_token += 1
	_posed = false
	_play = anim
	_play_hit = on_hit
	_play_end = on_end
	_play_frames = hit_frames(anim)
	_play_free = false
	_play_rev = false
	_play_prev = -1
	_play_t = -lead
	_play_ends = []
	var total := 0.0
	var fps := maxf(sf.get_animation_speed(anim) * maxf(speed, 0.05), 0.01)
	for i in sf.get_frame_count(anim):
		total += sf.get_frame_duration(anim, i) / fps
		_play_ends.append(total)
	if has_facing:
		facing = _face
	sprite.animation = anim
	sprite.pause()
	sprite.frame = 0
	return total + lead


## play(), timed so the first hit frame comes exactly `seconds` after this call: it holds the first
## frame for the time that is left over, or plays faster when the animation's own wind-up is longer.
func strike(anim: String, seconds: float, on_hit: Callable = Callable(), on_end: Callable = Callable()) -> float:
	var natural := hit_time(anim)
	if natural <= seconds or natural <= 0.0:
		return play(anim, on_hit, on_end, 1.0, seconds - natural)
	return play(anim, on_hit, on_end, natural / maxf(seconds, 0.05))


## The frames of `anim` where a blow lands or a shot leaves.
func hit_frames(anim: String) -> Array:
	var own: Dictionary = data.get("hit_frames", {})
	if own.has(anim):
		return own[anim]
	var listed: Variant = (meta.get("hit_frames", {}) as Dictionary).get(anim)
	if listed is Array and not (listed as Array).is_empty():
		return listed
	return [maxi(sprite.sprite_frames.get_frame_count(anim) - 1, 0)] if sprite.sprite_frames.has_animation(anim) else [0]


## Seconds from the start of `anim` to its first hit frame, at normal speed.
func hit_time(anim: String) -> float:
	return Art.frame_time(_sprite_id, anim, int(hit_frames(anim)[0]))


func anim_time(anim: String) -> float:
	return Art.anim_time(_sprite_id, anim)


## Freezes the sprite on one frame until the next play(), strike() or stop().
func pose(anim: String, frame: int = 0) -> void:
	stop()
	if not sprite.sprite_frames.has_animation(anim):
		return
	_posed = true
	sprite.animation = anim
	sprite.pause()
	sprite.frame = clampi(frame, 0, sprite.sprite_frames.get_frame_count(anim) - 1)


## Drops the running animation or pose without calling on_end.
func stop() -> void:
	_token += 1
	_play = ""
	_play_hit = Callable()
	_play_end = Callable()
	_play_free = false
	_posed = false


func busy() -> bool:
	return _play != ""


## Which loops the boss stands and walks in from now on.
func set_loops(idle: String, walk: String = "") -> void:
	idle_anim = idle
	run_anim = walk if walk != "" else idle


func face_player() -> void:
	face(to_player())


func _tick_play(delta: float) -> void:
	_play_t += delta
	if sprite.animation != _play:
		sprite.animation = _play
		sprite.pause()
	if _play_t < 0.0:
		sprite.frame = _play_ends.size() - 1 if _play_rev else 0
		return
	var n := _play_ends.size()
	var f := n
	for i in n:
		if _play_t < float(_play_ends[i]):
			f = i
			break
	var shown := mini(f, n - 1)
	sprite.frame = n - 1 - shown if _play_rev else shown
	var token := _token
	if shown > _play_prev:
		var prev := _play_prev
		_play_prev = shown
		if _play_hit.is_valid():
			for hf in _play_frames:
				if int(hf) > prev and int(hf) <= shown:
					_play_hit.call(self, int(hf))
					if token != _token or dead:
						return
	if f >= n:
		var done := _play_end
		stop()
		if done.is_valid():
			done.call(self)


## The pack's own flinch (only where it drew one); it runs while the boss is stunned.
func _flinch() -> void:
	if _real_hit and _play == "":
		play("hit")
		_play_free = true


# =============================================================================== places
## A spot on screen relative to the feet: Vector2(forward, -up), mirrored when it looks left.
func at_feet(v: Vector2) -> Vector2:
	return position + Vector2(v.x * (facing if has_facing else 1.0), v.y + 2.0 - lift - _hover)


func body_point() -> Vector2:
	return position - Vector2(0, _mid + lift)


## Where a shot leaves in `anim`, on screen (the row's "muzzle", else boss_cast.json's
## projectile_spawn, else the front of the body).
func muzzle_px(anim: String = "") -> Vector2:
	var own: Dictionary = data.get("muzzle", {})
	if own.has(anim):
		return at_feet(Vector2(float(own[anim][0]), float(own[anim][1])))
	var spawn: Variant = (meta.get("projectile_spawn", {}) as Dictionary).get(anim)
	if spawn is Dictionary and spawn.has("from_feet"):
		return at_feet(Vector2(float(spawn["from_feet"][0]), float(spawn["from_feet"][1])))
	return at_feet(Vector2(radius, -(_mid - _hover)))


## The same spot for the shot code (shots fly on the floor and are drawn SHOT_PLANE px above it).
func muzzle(anim: String = "") -> Vector2:
	return muzzle_px(anim) + Vector2(0, SHOT_PLANE)


# =============================================================================== shots
func shots_room() -> int:
	return maxi(SHOT_CAP - int(run.shots.count), 0)


## One enemy shot from `at`. extra: the same keys run.shots.fire() takes, plus "range" (px).
func shoot_from(at: Vector2, d: Vector2, shot_speed: float, type: String = "", extra: Dictionary = {}) -> bool:
	if shots_room() <= 0 or d == Vector2.ZERO:
		return false
	var more := extra.duplicate()
	more["src"] = display_name
	run.shots.fire(at, d.normalized() * shot_speed, Shots.SIDE_ENEMY, 1.0, float(extra.get("range", SHOT_RANGE)),
		type if type != "" else shot_type, more)
	return true


## `amount` shots spread evenly over `arc` radians around `d`.
func fan_from(at: Vector2, d: Vector2, amount: int, arc: float, shot_speed: float, type: String = "") -> void:
	var base := d.angle()
	for k in mini(amount, shots_room()):
		var a := base + (float(k) - float(amount - 1) * 0.5) * (arc / maxf(1.0, float(amount - 1)))
		shoot_from(at, Vector2.RIGHT.rotated(a), shot_speed, type)
	Sfx.play("enemy_shoot", -8.0)


func ring_from(at: Vector2, amount: int, shot_speed: float, type: String = "", angle_offset: float = 0.0) -> void:
	for k in mini(amount, shots_room()):
		shoot_from(at, Vector2.RIGHT.rotated(angle_offset + TAU * float(k) / float(amount)), shot_speed, type)
	Sfx.play("enemy_shoot", -6.0)


# =============================================================================== floor marks
func mark_circle(at: Vector2, r: float, seconds: float, color: Color = RED) -> void:
	run.fx.warn_circle(at, r, seconds, color, get_instance_id())


## A lane: everything within half_width of the line from `from` to `to`.
func mark_lane(from: Vector2, to: Vector2, half_width: float, seconds: float, color: Color = RED) -> void:
	run.fx.warn_line(from, to, half_width, seconds, color, get_instance_id())


## The lane the boss's own BODY sweeps when it charges `length` px along `d` (as wide as its body
## circle plus the hero's, so standing just outside the mark is safe). Returns where the lane ends.
func mark_charge(d: Vector2, length: float, seconds: float, color: Color = RED) -> Vector2:
	var to: Vector2 = position + d.normalized() * length
	mark_lane(position, to, radius + player.radius - 1.0, seconds, color)
	return to


## A wedge from `tip` along `d`, `half_angle` radians to each side.
func mark_cone(tip: Vector2, d: Vector2, length: float, half_angle: float, seconds: float, color: Color = RED) -> void:
	run.fx.warn_cone(tip, d, length, half_angle, seconds, color, get_instance_id())


## A band: safe inside r_inner and outside r_outer.
func mark_ring(at: Vector2, r_inner: float, r_outer: float, seconds: float, color: Color = RED) -> void:
	run.fx.warn_ring(at, r_inner, r_outer, seconds, color, get_instance_id())


func in_circle(at: Vector2, r: float) -> bool:
	return at.distance_to(player.position) < r + player.hit_radius - 2.0


func in_lane(from: Vector2, to: Vector2, half_width: float) -> bool:
	var ab := to - from
	var k := clampf((player.position - from).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
	return (from + ab * k).distance_to(player.position) < half_width + player.hit_radius - 2.0


func in_cone(tip: Vector2, d: Vector2, length: float, half_angle: float) -> bool:
	var rel: Vector2 = player.position - tip
	var far := rel.length()
	if far > length + player.hit_radius - 2.0:
		return false
	return far < 1.0 or absf(d.angle_to(rel)) < half_angle + (player.hit_radius - 2.0) / far


func in_ring(at: Vector2, r_inner: float, r_outer: float) -> bool:
	var far: float = at.distance_to(player.position)
	return far > r_inner - player.hit_radius + 2.0 and far < r_outer + player.hit_radius - 2.0


func _strike(inside: bool, from: Vector2, damage: int, what: String) -> bool:
	if not inside or not player.can_be_hit():
		return false
	_hurt_by = what
	player.hurt(damage, from, display_name)
	_hurt_by = ""
	return true


func strike_circle(at: Vector2, r: float, damage: int = 1) -> bool:
	return _strike(in_circle(at, r), at, damage, "a circle")


func strike_lane(from: Vector2, to: Vector2, half_width: float, damage: int = 1) -> bool:
	return _strike(in_lane(from, to, half_width), from, damage, "a lane")


func strike_cone(tip: Vector2, d: Vector2, length: float, half_angle: float, damage: int = 1) -> bool:
	return _strike(in_cone(tip, d, length, half_angle), tip, damage, "a cone")


func strike_ring(at: Vector2, r_inner: float, r_outer: float, damage: int = 1) -> bool:
	return _strike(in_ring(at, r_inner, r_outer), at, damage, "a ring")


## Ground that burns for `seconds` and hurts the hero who stands in it. It starts to hurt after
## `arm` seconds (give the hero time to step off when it appears under him).
func burn_ground(at: Vector2, r: float, seconds: float, arm: float = 0.4, color: Color = EMBER) -> void:
	run.fx.zone(at, r, seconds, color, get_instance_id())
	_burns.append([at, r, seconds, arm])


func _tick_burns(delta: float) -> void:
	for k in range(_burns.size() - 1, -1, -1):
		var b: Array = _burns[k]
		b[2] -= delta
		b[3] -= delta
		if b[2] <= 0.0:
			_burns.remove_at(k)
		elif b[3] <= 0.0:
			_strike((b[0] as Vector2).distance_to(player.position) < float(b[1]) - 2.0, b[0], 1, "burning ground")


# =============================================================================== time and rhythm
## Calls callback(e) after `seconds`. The clock stands still while the boss is stunned.
func after(seconds: float, callback: Callable) -> void:
	_timers.append([seconds, callback])


func _tick_timers(delta: float) -> void:
	if _timers.is_empty():
		return
	var due: Array = []
	for k in range(_timers.size() - 1, -1, -1):
		_timers[k][0] -= delta
		if _timers[k][0] <= 0.0:
			due.append(_timers[k][1])
			_timers.remove_at(k)
	due.reverse()
	var cancels := _cancels
	for callback: Callable in due:
		if cancels != _cancels or dead:
			return                      # an earlier callback called cancel(), or the boss died
		callback.call(self)


## THE BREATHER. The boss stands dazed for `seconds`: its fight file is not ticked, its timers
## wait, and shots hurt it "stagger_dmg" (bosses.gd) times as much. Set e.state / e.t for what
## comes next BEFORE calling it. `anim` = a pose to stand in (default: the pack's "hit", or idle).
func stagger(seconds: float, anim: String = "") -> void:
	stop()
	staggered = seconds
	stun = maxf(stun, seconds)
	_say("staggered for %.1f s" % seconds)
	lift = 0.0
	_tell = 0.0
	if anim != "" and sprite.sprite_frames.has_animation(anim):
		pose(anim, 0)
		if sprite.sprite_frames.get_animation_loop(anim):
			sprite.play(anim)               # a loop keeps moving ("nofire"); a one-shot stands on its first frame
	else:
		_flinch()
	run.fx.burst(body_point() - Vector2(0, _body_h * 0.4), [Color(0.75, 0.85, 1.0), Color(1, 1, 1)], 8, 50.0, 0.5, 2.0)


func _tick_stagger(delta: float) -> void:
	staggered -= delta
	_bob_t += delta * 3.0
	if fmod(staggered, 0.22) < delta:
		# dazed: pale squares drift up from its head
		run.fx.burst(position - Vector2(randf_range(-0.3, 0.3) * _body_w, _lifted + _body_h), [Color(0.75, 0.85, 1.0, 0.9)], 1, 10.0, 0.5, 2.0, Vector2.UP, -40.0)


## A clean slate: stops the animation, forgets every timer and takes its floor marks back
## (burning ground stays). Phase changes call it by themselves.
func cancel() -> void:
	stop()
	_cancels += 1
	_timers.clear()
	run.fx.drop_warns(get_instance_id(), false)


# =============================================================================== helpers and effects
## Summons up to `count` helpers on marked spots away from the hero and returns them.
## opts: "max" living helpers of this boss (4), "delay" s before they appear (0.9), "far" px from the hero (40).
func summon_minions(enemy_id: String, count: int, opts: Dictionary = {}) -> Array:
	var out: Array = []
	var delay := float(opts.get("delay", 0.9))
	for k in clampi(int(opts.get("max", 4)) - minion_count(), 0, count):
		var at: Vector2 = room.random_spawn_spot(player.position, false, float(opts.get("far", 40.0)))
		mark_circle(at, 8.0, delay)
		out.append(room.spawn_enemy(enemy_id, at, {"minion": true, "delay": delay, "owner": get_instance_id()}))
	return out


## Plays an effect animation of the boss art (ids boss_fx_*, see "fx" in boss_cast.json) at a spot
## on screen and returns its node (move, turn or free it yourself if you need to).
## opts: "fps" (12), "from" / "to" (play only these frames), "loop" + "life" (seconds),
##       "anchor" (the px of the picture that sits on `at`; default its middle),
##       "flip" (default: the boss looks left), "rot" (radians; turns instead of flipping),
##       "under" (drawn under the characters), "follow" (it moves with the boss), "color".
func fx_sprite(id: String, at: Vector2, opts: Dictionary = {}) -> AnimatedSprite2D:
	var src := Art.frames(id)
	if src == null:
		push_warning("Boss %s: no effect sprite '%s'" % [boss_id, id])
		return null
	var fps := float(opts.get("fps", 12.0))
	var loop: bool = opts.get("loop", false)
	var key := "%s:%d:%d:%s:%s" % [id, int(opts.get("from", 0)), int(opts.get("to", -1)), fps, loop]
	if not _fx_frames.has(key):
		var sf := SpriteFrames.new()
		sf.set_animation_speed("default", fps)
		sf.set_animation_loop("default", loop)
		var n := src.get_frame_count("default")
		var last := int(opts.get("to", -1))
		for i in range(clampi(int(opts.get("from", 0)), 0, n - 1), n if last < 0 else mini(last + 1, n)):
			sf.add_frame("default", src.get_frame_texture("default", i))
		_fx_frames[key] = sf
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _fx_frames[key]
	s.centered = false
	s.offset = -(opts.get("anchor", Art.size(id) * 0.5) as Vector2)
	if opts.has("rot"):
		s.rotation = float(opts["rot"])
		if cos(s.rotation) < 0.0:
			s.scale.y = -1.0                # keep the picture the right way up when it points left
	elif opts.get("flip", facing < 0.0 and has_facing):
		s.scale.x = -1.0
	s.z_index = -1 if opts.get("under", false) else 1
	s.modulate = opts.get("color", Color(1, 1, 1))
	if opts.get("follow", false):
		add_child(s)
		s.position = at - position
	else:
		room.ysort.add_child(s)
		s.position = at
	s.play("default")
	_fx_nodes.append([s, float(opts.get("life", 1.0)) if loop else -1.0])
	if not loop:
		s.animation_finished.connect(s.queue_free)
	return s


## A still picture cut out of one of the boss's own frames (rect in canvas px), e.g. the club an
## ogre throws. Nothing is drawn: it is the artist's pixels. The node is yours to move and free
## (it is freed with the boss). Its origin is the middle of the piece.
func cut_sprite(anim: String, frame: int, rect: Rect2) -> Sprite2D:
	var piece := AtlasTexture.new()
	piece.atlas = sprite.sprite_frames.get_frame_texture(anim, frame)
	piece.region = rect
	var s := Sprite2D.new()
	s.texture = piece
	s.z_index = 1
	room.ysort.add_child(s)
	_fx_nodes.append([s, -1.0])
	return s


func _tick_fx(delta: float) -> void:
	for k in range(_fx_nodes.size() - 1, -1, -1):
		var row: Array = _fx_nodes[k]
		if not is_instance_valid(row[0]):
			_fx_nodes.remove_at(k)
		elif float(row[1]) >= 0.0:
			row[1] = float(row[1]) - delta
			if float(row[1]) <= 0.0:
				(row[0] as Node).queue_free()
				_fx_nodes.remove_at(k)


func _free_fx() -> void:
	for row: Array in _fx_nodes:
		if is_instance_valid(row[0]):
			(row[0] as Node).queue_free()
	_fx_nodes.clear()


# =============================================================================== look
## The warning blink (no automatic attack animation: the fight file plays its own).
func tell(seconds: float) -> void:
	_tell = seconds
	_tell_dur = seconds
	run.fx.ring(body_point(), maxf(radius * 2.4, _body_h * 0.7), radius * 0.8, seconds, Color(1.0, 0.35, 0.25, 0.9), 1.5)


func _update_look(delta: float) -> void:
	if _play == "" and not _posed:
		if has_facing:
			facing = _face
		var want := run_anim if _moved else idle_anim
		if sprite.animation != want or not sprite.is_playing():
			sprite.play(want)
	_bob_t += delta
	var bob := roundf(sin(_bob_t * 2.6) * _bob) if staggered <= 0.0 else 0.0
	sprite.scale = Vector2(facing if has_facing else 1.0, 1.0)
	sprite.position = Vector2(0.0, 2.0 - lift - _hover + bob)
	shadow.modulate.a = clampf(1.0 - (lift + _lifted * 0.5) / 60.0, 0.35, 1.0)
	sprite.self_modulate = Color(0.72, 0.74, 0.86) if staggered > 0.0 else Color(1, 1, 1)
	_flick_gap -= delta
	if _flash > 0.0 and _flick_gap <= 0.0:
		_flick = HIT_FLICK
		_flick_gap = HIT_GAP
	_flash = 0.0
	if _tell > 0.0:
		_tell -= delta
	if _flick > 0.0:
		_flick -= delta
		sprite.material = hit_material()
	elif _tell > 0.0 and _tell_dur - _tell < TELL_PULSE:
		sprite.material = hit_material()      # the same soft flicker as a hit (the pale wind-up shader whitened a boss this size)
	else:
		sprite.material = null


# =============================================================================== getting hurt
func hurt(amount: float, from_dir: Vector2 = Vector2.ZERO, knock_mult: float = 1.0) -> void:
	super.hurt(amount * (_stagger_dmg if staggered > 0.0 else 1.0), from_dir, knock_mult)


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
	_say("dies")
	cancel()
	_burns.clear()
	_free_fx()
	_death_total = float(data.get("death_time", FINAL_DEATH_TIME if final else DEATH_TIME))
	dying = _death_total
	_death_wave = 0
	lift = 0.0
	stun = 0.0
	staggered = 0.0
	sprite.material = null
	sprite.self_modulate = Color(1, 1, 1)
	sprite.pause()
	if _real_death:
		sprite.animation = "death"
		sprite.pause()
		sprite.frame = 0
	run.fx.hazards.clear()
	run.fx.warns.clear()
	run.fx.zones.clear()
	run.shots.clear()
	run.slowmo(0.25 if final else 0.3, 0.75 if final else 0.3)
	run.hitstop(0.08)
	Sfx.play("boss_die")
	# its helpers fall with it
	for e in room.enemies.duplicate():
		if e != self and is_instance_valid(e):
			e.die(false)


## The death: the pack's own frames where it drew them (spread over most of the time), otherwise
## a shake and a white blink; bursts in the boss's own colours that come faster and faster; a
## fade at the end. The final boss also sends three shockwaves through the room on the way.
func _tick_death(delta: float) -> void:
	dying -= delta
	var k := clampf(1.0 - dying / _death_total, 0.0, 1.0)
	var colors := Art.palette(_sprite_id)
	var mid := position - Vector2(0, _mid)
	if _real_death:
		var n := sprite.sprite_frames.get_frame_count("death")
		sprite.frame = mini(int(k / 0.8 * float(n)), n - 1)
		sprite.self_modulate.a = clampf((1.0 - k) / 0.12, 0.0, 1.0)
	else:
		sprite.material = hit_material() if fmod(dying * 14.0, 1.0) < 0.35 else null
		sprite.position.x = randf_range(-1.5, 1.5) * (1.0 + k)
		sprite.self_modulate.a = clampf((1.0 - k) / 0.3, 0.0, 1.0)
	shadow.modulate.a = clampf((1.0 - k) / 0.3, 0.0, 1.0)
	_death_puff -= delta
	if _death_puff <= 0.0 and k < 0.9:
		_death_puff = lerpf(0.16, 0.05, k)
		var at := position + Vector2(randf_range(-0.4, 0.4) * _body_w, -_lifted - randf() * _body_h)
		run.fx.burst(at, colors, 8, 70.0, 0.5, 2.6)
		run.fx.ring(at, 2.0, 12.0, 0.2, colors[0], 1.5)
		run.shake(0.2)
	if final and _death_wave < 3 and k >= 0.22 * float(_death_wave + 1):
		_death_wave += 1
		run.fx.ring(mid, 8.0, 150.0, 0.6, colors[_death_wave % colors.size()], 4.0)
		run.fx.burst(mid, colors, 40, 160.0, 0.8, 3.0)
		run.fx.flash(Color(1, 1, 1, 0.35), 0.18)
		run.shake(0.8)
		Sfx.play("explosion", -3.0)
	if dying <= 0.0:
		run.fx.burst(mid, colors, 110 if final else 70, 190.0 if final else 150.0, 1.1 if final else 0.9, 3.4)
		run.fx.ring(mid, 6.0, 170.0 if final else 90.0, 0.7 if final else 0.5, Color(1, 1, 1), 4.0)
		run.fx.flash(Color(1, 1, 1, 0.8 if final else 0.5), 0.5 if final else 0.2)
		run.shake(1.0)
		Sfx.play("explosion")
		Sfx.play("enemy_die_big")
		for n2 in 5 + randi() % 4:
			room.drop("coin", position + Vector2(randf_range(-8, 8), randf_range(-6, 6)))
		room.drop("heart", position)
		room.enemy_died(self)
		run.boss_killed(self)
		queue_free()


## Ground that hurts like burn_ground() but is NOT drawn here: the fight file draws its own puddle
## (the Gutter King's green slime). The test bot keeps out of it. Cleared when the boss dies.
func hurt_ground(at: Vector2, r: float, seconds: float, arm: float = 0.4) -> void:
	_burns.append([at, r, seconds, arm])
	run.fx.hazards.append([0, at, at, r - 6.0, seconds, get_instance_id(), 0.0])
