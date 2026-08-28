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
## platform, and balancing along the garden wall are short SCRIPTED or
## constrained excursions from the baseline walk/run loop above, entered
## automatically by proximity (world_affordances.gd) rather than a new input
## binding -- ART_DIRECTION.md asks for "very small contextual prompts only
## when necessary", and walking up to the thing needs none at all. Every
## verb ends by returning `verb` to Verb.GROUND, which re-enters the exact
## baseline code path below unchanged, so test_player_movement.gd's and
## test_playthrough.gd's numbers can't be touched by any of this unless a
## verb actually triggers -- and none of their authored routes pass near
## the tower or the wall.

@export var walk_speed: float = 2.65
@export var run_speed: float = 4.1
@export var locked_y: float = 0.0

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

const CLIMB_RISE_SECONDS := 0.85   ## phase 1: straight up the tower's outer face
const CLIMB_STEP_SECONDS := 0.45   ## phase 2: step in over the deck edge
const SLIDE_SECONDS := 1.3
const SLIDE_RIDE_FRACTION := 0.82  ## fraction of SLIDE_SECONDS spent riding vs. launching
const SLIDE_LAUNCH_HEIGHT := 0.4   ## the "small launch at the bottom" the brief asks for
const WALL_MOUNT_SECONDS := 0.3
const WALL_WALK_SPEED := 1.35      ## slower than walk_speed -- precarious, not punishing
const WALL_LEAN_SPEED := 0.55      ## m/s the player can drift sideways off the centerline
const WALL_DISMOUNT_SECONDS := 0.22

var _verb_time: float = 0.0
var _verb_from: Vector3 = Vector3.ZERO
var _verb_to: Vector3 = Vector3.ZERO
var _wall_offset_x: float = 0.0    ## current sideways drift from the wall's centerline, meters
var _wall_wobble_time: float = 0.0


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


func _physics_process(delta: float) -> void:
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
## into the tower's base or the wall's base is the entire input vocabulary
## for these two verbs, matching ART_DIRECTION.md's "very small contextual
## prompts only when necessary" by needing no prompt at all.
func _check_verb_triggers() -> void:
	var p := global_position
	if WorldAffordances.near_climb_trigger(p.x, p.z):
		_start_climb()
	elif WorldAffordances.near_wall_mount(p.x, p.z):
		_start_wall_mount()


# ------------------------------------------------------- tower + slide --

func _start_climb() -> void:
	verb = Verb.CLIMBING
	_verb_time = 0.0
	velocity = Vector3.ZERO
	moving = false
	character_visual.set_motion(false, false)


## Two-phase scripted rise: straight up alongside the tower's outer face
## (clear of its collider footprint, WorldBounds.COLLIDERS' {-3.4,-5.6}
## entry) and only then in over the deck edge -- a straight-line lerp from
## the ground trigger straight to the inset platform stand point would
## carry the player, at low height, straight through the tower's own solid
## box collider (0.05..2.45m tall) for most of the move.
func _process_climb(delta: float) -> void:
	_verb_time += delta
	if _verb_time <= CLIMB_RISE_SECONDS:
		var eased := 1.0 - pow(1.0 - clampf(_verb_time / CLIMB_RISE_SECONDS, 0.0, 1.0), 2.0)
		global_position = Vector3(
			WorldAffordances.CLIMB_TRIGGER.x,
			lerpf(0.0, WorldAffordances.PLATFORM_TOP_Y + 0.05, eased),
			WorldAffordances.CLIMB_TRIGGER.z,
		)
		return

	var step_t := clampf((_verb_time - CLIMB_RISE_SECONDS) / CLIMB_STEP_SECONDS, 0.0, 1.0)
	global_position = Vector3(
		WorldAffordances.TOWER_X,
		lerpf(WorldAffordances.PLATFORM_TOP_Y + 0.05, WorldAffordances.PLATFORM_TOP_Y, step_t),
		lerpf(WorldAffordances.CLIMB_TRIGGER.z, WorldAffordances.PLATFORM_STAND.z, step_t),
	)
	if step_t >= 1.0:
		verb = Verb.ON_PLATFORM


## A small free-roam state on the tower deck -- there is no collider up
## there (the platform is render-only, see _bootstrap_courtyard.gd), so
## this hand-clamps the player to its footprint instead of calling
## move_and_slide(). Walking to the south edge (toward the slide, away
## from the tower's own footprint centre) launches the slide.
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
		global_position.z = clampf(global_position.z + direction["z"] * walk_speed * delta, WorldAffordances.TOWER_Z - half, WorldAffordances.TOWER_Z + half + 0.3)

		var target_heading := atan2(-direction["x"], -direction["z"])
		heading += _angle_delta(target_heading, heading) * minf(1.0, delta * 10.0)
		rotation.y = heading
		walk_cycle += delta * 7.0
		AudioDirector.play_step(false)

	global_position.y = WorldAffordances.PLATFORM_TOP_Y

	if global_position.z > WorldAffordances.TOWER_Z + WorldAffordances.TOWER_FOOTPRINT_HALF - 0.15:
		_start_slide()


func _start_slide() -> void:
	verb = Verb.SLIDING
	_verb_time = 0.0
	moving = false
	character_visual.play_pose("sit")  # reads far better riding down than a standing idle
	AudioDirector.play_slide_whoosh()


## Rides WorldAffordances' authored curve: an accelerating descent
## (SLIDE_RIDE_FRACTION of the total time) then a short forward launch hop
## (the remainder) that lands exactly on SLIDE_END -- "accelerate down, a
## small launch at the bottom" per the brief. Bypasses move_and_slide()
## the same way ball.gd's flight tween bypasses physics for the ball:
## this is a scripted beat, not free movement.
func _process_slide(delta: float) -> void:
	_verb_time += delta
	var t := clampf(_verb_time / SLIDE_SECONDS, 0.0, 1.0)
	var start: Vector3 = WorldAffordances.SLIDE_START
	var end: Vector3 = WorldAffordances.SLIDE_END
	var ride_end := Vector3(start.x, 0.35, lerpf(start.z, end.z, SLIDE_RIDE_FRACTION * 0.94))

	if t < SLIDE_RIDE_FRACTION:
		var rt := t / SLIDE_RIDE_FRACTION
		global_position = start.lerp(ride_end, rt * rt)  # accelerating, not linear
	else:
		var lt := (t - SLIDE_RIDE_FRACTION) / (1.0 - SLIDE_RIDE_FRACTION)
		var hop := sin(lt * PI) * SLIDE_LAUNCH_HEIGHT
		global_position = Vector3(
			start.x,
			lerpf(ride_end.y, 0.0, lt) + hop,
			lerpf(ride_end.z, end.z, lt),
		)

	# Face the direction of travel throughout (down and out, +z here) --
	# same "heading chases movement" convention the baseline uses.
	heading += _angle_delta(PI, heading) * minf(1.0, delta * 6.0)
	rotation.y = heading

	if t >= 1.0:
		verb = Verb.GROUND
		global_position = end


# ------------------------------------------------------------- garden wall --

func _start_wall_mount() -> void:
	verb = Verb.WALL_MOUNTING
	_verb_time = 0.0
	_verb_from = global_position
	velocity = Vector3.ZERO
	moving = false
	character_visual.set_motion(false, false)


func _process_wall_mount(delta: float) -> void:
	_verb_time += delta
	var t := clampf(_verb_time / WALL_MOUNT_SECONDS, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.0)
	var target := Vector3(WorldAffordances.WALL_X, WorldAffordances.WALL_TOP_Y, _verb_from.z)
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
## off either end of a wall segment dismounts the same way, just as
## gently: this is not a failure state, it's just being on the ground again.
func _process_wall_walk(delta: float) -> void:
	var input_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	moving = absf(input_x) > 0.01 or absf(input_z) > 0.01
	running = false
	character_visual.set_motion(moving, false)

	var segment := WorldAffordances.wall_segment_at_z(global_position.z)
	if segment.is_empty():
		_start_wall_dismount()
		return

	if moving:
		var profile := CameraProfile.profile(global_position.z)
		var yaw: float = profile["authored_yaw"]
		var direction := CameraProfile.input_direction(input_x, input_z, yaw)

		var next_z: float = clampf(global_position.z + direction["z"] * WALL_WALK_SPEED * delta, segment["z_min"] - 0.1, segment["z_max"] + 0.1)
		global_position.z = next_z
		_wall_offset_x = clampf(_wall_offset_x + direction["x"] * WALL_LEAN_SPEED * delta, -WorldAffordances.WALL_HALF_WIDTH - 0.5, WorldAffordances.WALL_HALF_WIDTH + 0.5)

		if absf(direction["z"]) > 0.01:
			var target_heading: float = PI if direction["z"] > 0.0 else 0.0
			heading += _angle_delta(target_heading, heading) * minf(1.0, delta * 8.0)
			rotation.y = heading
		walk_cycle += delta * 6.0
		AudioDirector.play_step(false)
	else:
		_wall_offset_x = move_toward(_wall_offset_x, 0.0, delta * 0.35)

	global_position.x = WorldAffordances.WALL_X + _wall_offset_x
	global_position.y = WorldAffordances.WALL_TOP_Y

	_wall_wobble_time += delta
	var wobble := sin(_wall_wobble_time * 2.6) * 0.045
	character_visual.rotation.z = wobble - _wall_offset_x * 0.5

	if absf(_wall_offset_x) > WorldAffordances.WALL_HALF_WIDTH:
		_start_wall_dismount()


func _start_wall_dismount() -> void:
	verb = Verb.WALL_DISMOUNT
	_verb_time = 0.0
	_verb_from = global_position
	var landing_x := global_position.x
	# A lean-caused dismount (exceeded WALL_HALF_WIDTH) must land clearly
	# outside WorldAffordances.near_wall_mount()'s wider WALL_MOUNT_X_RANGE,
	# not just past the half-width -- landing anywhere inside that range
	# means the very next GROUND tick's _check_verb_triggers() sees the
	# wall again and re-mounts immediately, so "stepping off" would
	# silently do nothing. A segment-end dismount doesn't need this: z
	# alone already clears wall_segment_at_z(), so x is left as-is.
	if absf(_wall_offset_x) > WorldAffordances.WALL_HALF_WIDTH:
		var side := signf(_wall_offset_x)
		landing_x = WorldAffordances.WALL_X + side * (WorldAffordances.WALL_MOUNT_X_RANGE + 0.3)
	_verb_to = Vector3(landing_x, locked_y, global_position.z)
	character_visual.rotation.z = 0.0
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
