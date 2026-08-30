extends CharacterBody3D
## Verbatim port of src/game.mjs's movePlayer() (lines 328-358) onto a
## CharacterBody3D. Y is locked (no gravity, no jump) -- the source player
## has no vertical component at all, always implicitly ground-level.
##
## Movement: WASD/arrows -> CameraProfile.input_direction (screen-relative to
## the current camera zone's authored_yaw, mouse-look yaw omitted here, see
## GODOT_REBUILD_PLAN.md M1.3) -> velocity -> move_and_slide() against the
## real M1.2 wall colliders (Godot's own collision resolution stands in for
## the source's per-axis canMoveTo clamp -- both are circle/capsule-vs-box
## sliding, just via different systems; WorldBounds.can_move_to remains
## available/tested as the reference data, not re-invoked here).
##
## GATE 0 VERBS -- climbing the left playground tower, sliding down from its
## platform, and balancing along a garden bed's brick edging are short SCRIPTED or
## constrained excursions from the baseline walk/run loop above, entered
## automatically by proximity (world_affordances.gd) rather than a new input
## binding -- ART_DIRECTION.md asks for "very small contextual prompts only
## when necessary", and walking up to the thing needs none at all. Every
## verb ends by returning `verb` to Verb.GROUND, which re-enters the exact
## baseline code path below unchanged, so test_player_movement.gd's and
## test_playthrough.gd's numbers can't be touched by any of this unless a
## verb actually triggers -- and none of their authored routes pass near
## the tower or the edging.

@export var walk_speed: float = 2.65
@export var run_speed: float = 4.1
## The one height the child ever stands at -- there is no gravity and no
## terrain-follow, so this is the world's walking plane, not a starting
## value. Derived from WorldAffordances rather than written as 0.0 so it is
## visibly the same number the ground layers are laid under: the park pass
## stacked those upward from it (plaza +5 cm, bark pit +7 cm, chalk circle
## +8.5 cm) and the child ended up wading through the park.
@export var locked_y: float = WorldAffordances.WALK_PLANE_Y

## The doorway threshold, not the world origin -- inside the home porch
## (world_bounds.gd's HOME room, x[-7,7] z[8,16]), 4 m short of the
## doorway piers (centered z=15) and 2 m short of the lane mouth (z=8).
## Relocated in the 2026-08-28 world expansion from the single-room
## version's (0, 0, 6.5) -- see world_bounds.gd's own doc comment for the
## four-room layout this and every other authored position below now sits
## in. CameraProfile.profile()'s THRESHOLD->APPROACH band (z 11..8) was
## re-tuned alongside this so the player starts partway through it rather
## than already-saturated -- see that file's own doc comment for why
## z=(0,0,0)-equivalent under-zoning was a real bug the first time.
const START_POSITION := Vector3(0.0, 0.0, 10.0)

## Set true only while an actual movement key is held -- mirrors
## player.moving in the source, which gates heading/walk-cycle updates too
## (heading holds its last value when idle, it doesn't snap to zero).
var moving: bool = false
var running: bool = false
var heading: float = 0.0
var walk_cycle: float = 0.0

@onready var character_visual: CharacterVisual = $Player

# --------------------------------------------------------------- verbs --

## GROUND is the baseline loop above. ON_PLATFORM is a small free-roam
## state atop the tower deck (its own footprint clamp, no move_and_slide
## collider up there to keep the player on it). The rest are short
## scripted moves driven by _verb_time, none of them read player input for
## anything but WALL_WALKING and ON_PLATFORM.
enum Verb { GROUND, CLIMBING, ON_PLATFORM, SLIDING, WALL_MOUNTING, WALL_WALKING, WALL_DISMOUNT }
var verb: Verb = Verb.GROUND

const CLIMB_RISE_SECONDS := 1.9    ## phase 1: up the staircase against the tower's west flank
const CLIMB_STEP_SECONDS := 0.45   ## phase 2: step in from the top tread onto the deck
const SLIDE_SECONDS := 1.3
const WALL_MOUNT_SECONDS := 0.3
const WALL_WALK_SPEED := 1.35      ## slower than walk_speed -- precarious, not punishing
const WALL_LEAN_SPEED := 0.55      ## m/s the player can drift sideways off the centerline
const WALL_DISMOUNT_SECONDS := 0.22

## Arms out sideways for the whole balance, layered over the ordinary
## walk/idle clips (character_visual.gd's set_arm_pose). Deliberately NOT a
## clip swap: the wobble and the lean below are already doing the balancing,
## and any full-body clip would have replaced the walk cycle with a static
## pose and left the child gliding along the bricks with still legs. "static"
## is the rig's rest T-pose, and a T-pose is exactly what a child's arms do
## on a narrow wall -- the one place in this pack where the useless-looking
## clip is the right one.
const BALANCE_ARM_CLIP := "static"

var _verb_time: float = 0.0
var _verb_from: Vector3 = Vector3.ZERO
var _verb_to: Vector3 = Vector3.ZERO
var _wall_offset_x: float = 0.0    ## current sideways drift from the wall's centerline, meters
var _wall_wobble_time: float = 0.0

## Gate 1 (mechanics agent): set by external free-roam mechanics (swing.gd)
## that need to fully own the player's transform for a short ride -- the
## same "this script does nothing, something else drives
## global_position/rotation" contract every Verb above already gives
## player.gd's OWN scripted beats, just reachable from outside this file.
## A swing can be dropped anywhere by any future map (it doesn't know
## player.gd's Verb enum and shouldn't have to), so it drives the player
## directly the way ball.gd already drives ITS OWN position off Game.player
## when carried -- this flag is the one addition that lets it do so without
## fighting move_and_slide(). While true, _physics_process below does
## nothing at all: no input read, no move_and_slide, no verb processing.
## The external system is responsible for setting this back to false (and
## for leaving character_visual in a sane pose/motion state) when the ride
## ends.
var external_control: bool = false


func _ready() -> void:
	Game.player = self
	_reset_to_start()
	Game.state_changed.connect(_on_state_changed)


func _on_state_changed(new_state: String) -> void:
	# Matches ball.gd's own ARRIVE handler -- both run on every
	# start_episode(), including "Play again", so a replay restarts the
	# player at the doorway threshold same as a fresh page load.
	if new_state == EpisodeDirector.State.ARRIVE:
		_reset_to_start()


func _reset_to_start() -> void:
	global_position = START_POSITION
	global_position.y = locked_y
	heading = 0.0
	walk_cycle = 0.0
	moving = false
	rotation.y = heading
	# A restart mid-verb (unreachable from any authored route today, but
	# cheap to guard) must not leave the player stuck sliding/balancing.
	verb = Verb.GROUND
	_wall_offset_x = 0.0
	character_visual.rotation.z = 0.0
	# ...and no leftover carry/balance arms or half-finished pose, same
	# reasoning as the verb reset just above.
	character_visual.reset_pose()
	# Gate 1: a restart mid-swing-ride must hand control back too -- same
	# defensive reasoning as the verb reset just above. swing.gd also
	# listens for ARRIVE itself and dismounts on its own end, but a
	# restart happening the same tick could race which handler runs first;
	# this makes the player's own half of that reset unconditional.
	external_control = false


func _physics_process(delta: float) -> void:
	if external_control:
		return
	match verb:
		Verb.CLIMBING:
			_process_climb(delta)
			return
		Verb.ON_PLATFORM:
			_process_on_platform(delta)
			return
		Verb.SLIDING:
			_process_slide(delta)
			return
		Verb.WALL_MOUNTING:
			_process_wall_mount(delta)
			return
		Verb.WALL_WALKING:
			_process_wall_walk(delta)
			return
		Verb.WALL_DISMOUNT:
			_process_wall_dismount(delta)
			return
		Verb.GROUND:
			pass  # falls through to the baseline loop below

	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var magnitude := Vector2(input_x, input_z).length()
	moving = magnitude > 0.01
	running = Input.is_action_pressed("run")
	# game.mjs:435-437 -- switchAction() runs every frame regardless of
	# whether the player is currently moving.
	character_visual.set_motion(moving, running)

	if not moving:
		velocity = Vector3.ZERO
		move_and_slide()
		global_position.y = locked_y
		_check_verb_triggers()
		return

	var profile := CameraProfile.profile(global_position.z)
	var yaw: float = profile["authored_yaw"]  # mouse-look yaw omitted, see class doc
	var direction := CameraProfile.input_direction(input_x, input_z, yaw)
	var speed := run_speed if running else walk_speed

	velocity = Vector3(direction["x"] * speed, 0.0, direction["z"] * speed)
	move_and_slide()
	global_position.y = locked_y

	# game.mjs:354-355 -- targetHeading = atan2(-direction.x, -direction.z);
	# heading += angleDelta(target, heading) * min(1, dt*10)
	var target_heading := atan2(-direction["x"], -direction["z"])
	heading += _angle_delta(target_heading, heading) * minf(1.0, delta * 10.0)
	rotation.y = heading

	walk_cycle += delta * (10.0 if running else 7.0)
	AudioDirector.play_step(running)  # game.mjs:357

	_check_verb_triggers()


static func _angle_delta(target: float, current: float) -> float:
	return atan2(sin(target - current), cos(target - current))


# ----------------------------------------------------------- verb triggers --

## Checked every GROUND tick, moving or not -- walking (or simply standing)
## into the tower's base or the edging's base is the entire input vocabulary
## for these two verbs, matching ART_DIRECTION.md's "very small contextual
## prompts only when necessary" by needing no prompt at all.
func _check_verb_triggers() -> void:
	var p := global_position
	if WorldAffordances.near_climb_trigger(p.x, p.z):
		_start_climb()
	elif WorldAffordances.near_edging_mount(p.x, p.z):
		_start_wall_mount()


# ------------------------------------------------------- tower + slide --

func _start_climb() -> void:
	verb = Verb.CLIMBING
	_verb_time = 0.0
	velocity = Vector3.ZERO
	# The whole point of the 2026-08-30 pass is that the ascent reads as
	# climbing rather than teleporting, and the cheapest half of that is
	# simply keeping the walk cycle running the whole way up instead of
	# gliding a frozen idle pose along a line.
	moving = true
	character_visual.set_motion(true, false)


## Two-phase scripted ascent, walking the staircase _bootstrap_courtyard.gd
## builds up the tower's WEST flank: along it at a constant rate (feet on
## the treads, because the height comes from
## WorldAffordances.stair_surface_y_at_x() -- the same ramp the meshes are
## placed on), then a step in from the top tread onto the deck.
##
## Before this the "climb" ran straight up a blank south face on the tower's
## own outer edge with nothing built there at all. That was invisible, so
## the slide looked like the only route up, and it read as a lift rather
## than a climb. Constant rate rather than the old eased rise for the same
## reason: a child walks up steps, they do not accelerate off the ground.
func _process_climb(delta: float) -> void:
	_verb_time += delta
	if _verb_time <= CLIMB_RISE_SECONDS:
		var t := clampf(_verb_time / CLIMB_RISE_SECONDS, 0.0, 1.0)
		var x := lerpf(WorldAffordances.CLIMB_TRIGGER.x, WorldAffordances.CLIMB_TOP.x, t)
		global_position = Vector3(x, WorldAffordances.stair_surface_y_at_x(x), WorldAffordances.STAIR_Z)
		# Facing along the climb (+x, up the stairs) -- same "heading chases
		# movement" convention the baseline walk uses.
		heading += _angle_delta(-PI * 0.5, heading) * minf(1.0, delta * 6.0)
		rotation.y = heading
		walk_cycle += delta * 7.0
		# The climb drives walk_cycle and puts feet on the treads, but until
		# 2026-08-30 it was the one verb that walked in total silence -- the
		# ordinary walk, the tower deck and the edging all tick footsteps
		# already. Same self-rate-limiting call they use, so a 1.9 s ascent
		# gets about five steps rather than one per frame.
		AudioDirector.play_step(false)
		return

	var step_t := clampf((_verb_time - CLIMB_RISE_SECONDS) / CLIMB_STEP_SECONDS, 0.0, 1.0)
	global_position = WorldAffordances.CLIMB_TOP.lerp(WorldAffordances.PLATFORM_STAND, step_t)
	walk_cycle += delta * 7.0
	if step_t >= 1.0:
		verb = Verb.ON_PLATFORM
		moving = false
		character_visual.set_motion(false, false)


## A small free-roam state on the tower deck -- there is no collider up
## there (the platform is render-only, see _bootstrap_courtyard.gd), so
## this hand-clamps the player to its footprint instead of calling
## move_and_slide(). Walking off the SLIDE'S OWN MOUTH -- not just anywhere
## along the south edge -- launches the slide: see
## WorldAffordances.at_slide_mouth(). The z clamp stops exactly at the deck
## edge for the same reason, since the old 0.3 m of overhang past it only
## existed to make the "any part of the south edge" trigger reachable, and
## with the trigger narrowed it would just be somewhere to stand in the air.
func _process_on_platform(delta: float) -> void:
	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	moving = Vector2(input_x, input_z).length() > 0.01
	running = false
	character_visual.set_motion(moving, false)

	if moving:
		var profile := CameraProfile.profile(global_position.z)
		var yaw: float = profile["authored_yaw"]
		var direction := CameraProfile.input_direction(input_x, input_z, yaw)
		var half := WorldAffordances.TOWER_FOOTPRINT_HALF - 0.2
		global_position.x = clampf(global_position.x + direction["x"] * walk_speed * delta, WorldAffordances.TOWER_X - half, WorldAffordances.TOWER_X + half)
		global_position.z = clampf(global_position.z + direction["z"] * walk_speed * delta, WorldAffordances.TOWER_Z - half, WorldAffordances.TOWER_Z + WorldAffordances.TOWER_FOOTPRINT_HALF - 0.05)

		var target_heading := atan2(-direction["x"], -direction["z"])
		heading += _angle_delta(target_heading, heading) * minf(1.0, delta * 10.0)
		rotation.y = heading
		walk_cycle += delta * 7.0
		AudioDirector.play_step(false)

	global_position.y = WorldAffordances.PLATFORM_TOP_Y

	if WorldAffordances.at_slide_mouth(global_position.x, global_position.z):
		_start_slide()


func _start_slide() -> void:
	verb = Verb.SLIDING
	_verb_time = 0.0
	moving = false
	# "sit" translates the rig's root bone down to seat height, which is why
	# character_visual.gd compensates for it -- without that the rider is
	# buried to the eyebrows in the chute rather than sitting in it.
	character_visual.play_pose("sit")  # reads far better riding down than a standing idle
	AudioDirector.play_slide_whoosh()


## Rides WorldAffordances.slide_ride_position() -- the slide's own top
## surface plus the seat lift, accelerating down it and then hopping off the
## foot onto SLIDE_END ("accelerate down, a small launch at the bottom" per
## the brief). The whole path lives in that pure function rather than here,
## because it has to be the SAME path the plank is built from and the same
## one tests/play/test_slide_ride_on_the_plank.gd samples; this version of
## the loop reconstructed its own curve from a start point, an end point and
## a hand-tuned mid-height (0.35), and none of the three agreed with the
## plank the player could see.
##
## Bypasses move_and_slide() the same way ball.gd's flight tween bypasses
## physics for the ball: this is a scripted beat, not free movement.
func _process_slide(delta: float) -> void:
	_verb_time += delta
	var t := clampf(_verb_time / SLIDE_SECONDS, 0.0, 1.0)
	global_position = WorldAffordances.slide_ride_position(t)

	# Face the direction of travel throughout (down and out, +z here) --
	# same "heading chases movement" convention the baseline uses.
	heading += _angle_delta(PI, heading) * minf(1.0, delta * 6.0)
	rotation.y = heading

	if t >= 1.0:
		verb = Verb.GROUND
		global_position = WorldAffordances.SLIDE_END


# ----------------------------------------------------------- garden edging --

func _start_wall_mount() -> void:
	verb = Verb.WALL_MOUNTING
	_verb_time = 0.0
	_verb_from = global_position
	velocity = Vector3.ZERO
	moving = false
	character_visual.set_motion(false, false)
	# Arms go out as they step up, not once they are already up there --
	# the overlay eases in over the crossfade, which is roughly the mount's
	# own 0.3s, so the two land together.
	character_visual.set_arm_pose(BALANCE_ARM_CLIP)


func _process_wall_mount(delta: float) -> void:
	_verb_time += delta
	var t := clampf(_verb_time / WALL_MOUNT_SECONDS, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.0)
	var target := Vector3(WorldAffordances.EDGING_X, WorldAffordances.EDGING_TOP_Y, _verb_from.z)
	global_position = _verb_from.lerp(target, eased)
	if t >= 1.0:
		verb = Verb.WALL_WALKING
		_wall_offset_x = 0.0
		_wall_wobble_time = 0.0


## Precariousness is communicated entirely through speed, a continuous
## cosmetic wobble, and a visible sideways lean -- never a UI gauge
## (PRODUCT_CONTRACT.md/ART_DIRECTION.md ban meters and fail states).
## _wall_offset_x is the one number that actually matters for falling: it
## only moves from sustained sideways INPUT, so the wobble alone can never
## cause a fall, and stepping off is always a deliberate, player-driven
## choice -- "impossible to fail in a punishing way" per the brief. Walking
## off either end of the edging's run dismounts the same way, just as
## gently: this is not a failure state, it's just being on the ground again.
func _process_wall_walk(delta: float) -> void:
	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	moving = absf(input_x) > 0.01 or absf(input_z) > 0.01
	running = false
	character_visual.set_motion(moving, false)

	var segment := WorldAffordances.edging_segment_at_z(global_position.z)
	if segment.is_empty():
		_start_wall_dismount()
		return

	if moving:
		var profile := CameraProfile.profile(global_position.z)
		var yaw: float = profile["authored_yaw"]
		var direction := CameraProfile.input_direction(input_x, input_z, yaw)

		var next_z: float = clampf(global_position.z + direction["z"] * WALL_WALK_SPEED * delta, segment["z_min"] - 0.1, segment["z_max"] + 0.1)
		global_position.z = next_z
		_wall_offset_x = clampf(_wall_offset_x + direction["x"] * WALL_LEAN_SPEED * delta, -WorldAffordances.EDGING_HALF_WIDTH - 0.5, WorldAffordances.EDGING_HALF_WIDTH + 0.5)

		if absf(direction["z"]) > 0.01:
			var target_heading: float = PI if direction["z"] > 0.0 else 0.0
			heading += _angle_delta(target_heading, heading) * minf(1.0, delta * 8.0)
			rotation.y = heading
		walk_cycle += delta * 6.0
		AudioDirector.play_step(false)
	else:
		_wall_offset_x = move_toward(_wall_offset_x, 0.0, delta * 0.35)

	global_position.x = WorldAffordances.EDGING_X + _wall_offset_x
	global_position.y = WorldAffordances.EDGING_TOP_Y

	_wall_wobble_time += delta
	var wobble := sin(_wall_wobble_time * 2.6) * 0.045
	character_visual.rotation.z = wobble - _wall_offset_x * 0.5

	if absf(_wall_offset_x) > WorldAffordances.EDGING_HALF_WIDTH:
		_start_wall_dismount()


func _start_wall_dismount() -> void:
	verb = Verb.WALL_DISMOUNT
	_verb_time = 0.0
	_verb_from = global_position
	var landing_x := global_position.x
	# A lean-caused dismount (exceeded EDGING_HALF_WIDTH) must land clearly
	# outside WorldAffordances.near_edging_mount()'s wider EDGING_MOUNT_X_RANGE,
	# not just past the half-width -- landing anywhere inside that range
	# means the very next GROUND tick's _check_verb_triggers() sees the
	# edging again and re-mounts immediately, so "stepping off" would
	# silently do nothing. A segment-end dismount doesn't need this: z
	# alone already clears edging_segment_at_z(), so x is left as-is.
	if absf(_wall_offset_x) > WorldAffordances.EDGING_HALF_WIDTH:
		var side := signf(_wall_offset_x)
		landing_x = WorldAffordances.EDGING_X + side * (WorldAffordances.EDGING_MOUNT_X_RANGE + 0.3)
	_verb_to = Vector3(landing_x, locked_y, global_position.z)
	character_visual.rotation.z = 0.0
	character_visual.clear_arm_pose()
	_wall_offset_x = 0.0
	moving = false
	character_visual.set_motion(false, false)


func _process_wall_dismount(delta: float) -> void:
	_verb_time += delta
	var t := clampf(_verb_time / WALL_DISMOUNT_SECONDS, 0.0, 1.0)
	global_position = _verb_from.lerp(_verb_to, t * t)  # a real drop, not a float-down
	if t >= 1.0:
		verb = Verb.GROUND
		global_position.y = locked_y
