extends Node3D
## Port of src/game.mjs's updateCamera() (lines 384-411) onto a pivot (this
## node) -> SpringArm3D -> Camera3D chain. Verbatim except for the home-end
## pull-in fix inside _physics_process's `desired_x`/`desired_z` block below
## -- see its comment; game.mjs's own per-axis clamp is still the common path.
##
## The pivot sits at the look-at target (matching the source's
## threeCamera.lookAt(target)); the SpringArm3D is oriented from the pivot
## toward the damped desired camera position, with spring_length set to
## that distance -- so SpringArm3D's own collision shapecast pulls the
## camera inward exactly when geometry would otherwise clip it. That's the
## thing Saturday Afternoon's hand-rolled camera got wrong (follow camera
## left outside the starting room's walls).
##
## MOUSE-LOOK (camera-fix task, 2026-08-28): restored from game.mjs's
## pointerdown/pointermove/pointerup drag-look (lines 309-325, 386-392),
## dropped by the original M1.4 port ("no orbit/mouse-look in this pass",
## a deliberate simplification while the world was one room the player
## always faced the same authored direction across). The world is now four
## connected places; the player needs to be able to look around while
## exploring. `_look_yaw`/`_look_pitch` accumulate from left-mouse-drag
## motion (project.godot's `camera_look` action gates the drag, matching
## the source's single-pointer model), clamped to the source's own cone
## (yaw +-0.36 rad, pitch -0.12..0.2) and springing back to the authored
## angle (lambda 2.0/2.3) whenever the button is released -- so the
## authored zone framing (ART_DIRECTION.md's "camera placement is part of
## the visual identity") is always what the camera returns to, never a
## free third-person orbit. Reduced-motion disables the look entirely
## (matches the source's own `if (!dragActive || reducedMotion) return`).
##
## Deliberately NOT threaded into player.gd's own movement-relative-camera
## yaw (which the source *did* couple: dragging also rotated which way "W"
## walks). Movement staying authored-yaw-only is player.gd's own explicit,
## repeated design choice (three call sites, each commented "mouse-look yaw
## omitted") predating this task and shared with the wall-walk/platform
## verbs; re-plumbing it is a materially bigger change than "give the
## camera back" and out of this task's scope. The practical cost is small --
## the look cone is only +-0.36 rad (~20 deg) and springs back the moment
## the button is released, so a brief mismatch between where the camera
## looks and which way "forward" walks is the extent of it, not a durable
## disorientation.

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _smoothed_desired: Vector3 = Vector3.ZERO
var _initialized: bool = false
var _excluded_player: bool = false

## game.mjs:127-129's lookYaw/lookPitch/dragActive, ported verbatim.
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _drag_active: bool = false

const LOOK_YAW_LIMIT := 0.36     # game.mjs:322
const LOOK_PITCH_MIN := -0.12    # game.mjs:323
const LOOK_PITCH_MAX := 0.2      # game.mjs:323
const LOOK_YAW_SENSITIVITY := 0.0045   # game.mjs:322 (per pixel of drag)
const LOOK_PITCH_SENSITIVITY := 0.0025 # game.mjs:323 (per pixel of drag)
const LOOK_YAW_SPRINGBACK := 2.0       # game.mjs:387
const LOOK_PITCH_SPRINGBACK := 2.3     # game.mjs:388
const LOOK_PITCH_HEIGHT_SCALE := 2.8   # game.mjs:397


func _ready() -> void:
	Game.camera = camera


## game.mjs:309-325 -- pointerdown/pointermove/pointerup/pointercancel,
## ported onto Godot's own mouse events. _unhandled_input (not _input)
## matches every other input handler in this project (game.gd, pause_menu.gd,
## debug_overlay.gd) and means a drag that starts on a HUD button (which
## consumes the event first, standard Control behaviour) never also spins
## the camera.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_look"):
		_drag_active = true
	elif event.is_action_released("camera_look"):
		_drag_active = false
	elif event is InputEventMouseMotion and _drag_active and not Game.reduced_motion:
		var motion := event as InputEventMouseMotion
		_look_yaw = clampf(_look_yaw - motion.relative.x * LOOK_YAW_SENSITIVITY, -LOOK_YAW_LIMIT, LOOK_YAW_LIMIT)
		_look_pitch = clampf(_look_pitch + motion.relative.y * LOOK_PITCH_SENSITIVITY, LOOK_PITCH_MIN, LOOK_PITCH_MAX)


func _physics_process(delta: float) -> void:
	var player := Game.player
	if not is_instance_valid(player):
		return

	# Deferred rather than done in _ready(): sibling _ready() order (Player
	# vs CameraRig, both children of Main) isn't something to depend on --
	# this runs as soon as Game.player is actually set, whichever order
	# _ready() calls land in.
	if not _excluded_player:
		spring_arm.add_excluded_object(player.get_rid())
		_excluded_player = true

	# game.mjs:386-389 -- while not actively dragging (or under reduced
	# motion, which overrides an in-progress drag too -- source's own
	# `if (!dragActive || reducedMotion)`), both look axes damp back to the
	# authored angle. This is what makes the authored zone framing the
	# thing the camera always returns to rather than a free orbit.
	if not _drag_active or Game.reduced_motion:
		_look_yaw = CameraProfile.damp(_look_yaw, 0.0, LOOK_YAW_SPRINGBACK, delta)
		_look_pitch = CameraProfile.damp(_look_pitch, 0.0, LOOK_PITCH_SPRINGBACK, delta)

	var p := player.global_position
	var profile := CameraProfile.profile(p.z)
	# Pulled into explicitly-typed floats (not used inline from the
	# Dictionary) -- Vector3 has no operator overload for Variant, so an
	# inline `forward * profile["lead"]` can't be statically typed and
	# fails GDScript's `:=` inference. Same pattern as player.gd's yaw.
	# Movement (player.gd) intentionally stays authored_yaw-only, without
	# _look_yaw -- see this file's class doc comment.
	var yaw: float = profile["authored_yaw"] + _look_yaw
	var distance: float = profile["distance"]
	var height: float = profile["height"]
	var target_height: float = profile["target_height"]
	var fov: float = profile["fov"]
	var lateral: float = profile["lateral"]
	var lead: float = profile["lead"]
	var s := sin(yaw)
	var c := cos(yaw)

	# game.mjs:394-400 -- desired camera position. `distance` and `lateral`
	# are offsets along two orthonormal directions relative to the player:
	# `back` (unit vector; game.mjs's own (sin yaw, cos yaw)) and `lat`
	# (unit vector, perpendicular to `back`; game.mjs's (cos yaw, -sin yaw)).
	# Kept as explicit Vector3s, rather than inlined the way game.mjs writes
	# desired.x/desired.z directly, because the doorway fix just below
	# reuses both directions.
	var back := Vector3(s, 0.0, c)
	var lat := Vector3(c, 0.0, -s)
	var raw_offset := back * distance + lat * lateral
	var raw_x := p.x + raw_offset.x
	var raw_z := p.z + raw_offset.z

	# The courtyard's own world-space envelope -- test_camera_never_in_
	# geometry.gd asserts the FINAL camera position never exceeds these, so
	# they stay the hard outer bound no matter what happens below.
	# Re-tuned for the 2026-08-28 world expansion (world_bounds.gd's own
	# doc comment has the four-room layout).
	#
	# UNLIKE the single-room version's pair, these are NOT "just inside
	# can_move_to's own envelope" -- an earlier version of this pass tried
	# exactly that (a uniform ~0.35 m margin off can_move_to's own
	# [-16.6,22.6]/[-20.3,16.3]) and it silently reproduced the doorway
	# collapse bug documented below, because that margin put the clamp
	# PAST the nearest real wall face instead of short of it. Each bound
	# below is instead picked to sit clear of the SPECIFIC nearest solid
	# thing a shot in that direction could reach: z min clears the
	# playground's own back wall (near face -19.4); x min/max clear the
	# playground west wall (-15.4) and the garden pocket's east wall
	# (21.65) respectively -- the two widest rooms, and so the two real
	# bounds a wide REVEAL-zone shot could actually reach.
	#
	# z max is the home end's own bound, and is NOT the doorway piers
	# (front face 14.0) -- camera-fix task (2026-08-28): the piers only
	# mattered as a bound while the fallback below could swing `desired_x`
	# out several metres (the superseded sideways-swing fix, this file's
	# `else` branch below has the full history), which could put the
	# fallback target's own X inside the piers' footprint even though the
	# PLAYER was centered in the 2.4 m gap between them. This file's
	# pull-in fallback instead keeps `desired_x` close to the player at all
	# times (bounded by `raw_offset.x`, which is only ever a few tenths of
	# a metre for THRESHOLD/APPROACH/REVEAL's own authored `lateral`) --
	# for a centered player it can no longer reach the piers' footprint at
	# all, so the piers stop being the binding constraint. What remains is
	# the home room's own back cap (z=16.3, half_z 0.05, near face 16.25,
	# world_bounds.gd's true end-of-room wall) -- 15.9 sits 0.35 m short of
	# it, comfortably outside SpringArm3D's own 0.15 m shapecast margin.
	# Screenshot- and probe-verified (tools/shots.ps1's "door" beat;
	# tools/_probe_camera_swing.gd, camera-fix task, not committed): the
	# tighter 13.5 bound left almost no room for the pull-in fallback to
	# work with at the door beat (z~12.5, deep enough in the room that the
	# old bound was already only ~1 m of z away) -- distance 0.97 m,
	# visually the character's own head filling the frame. At 15.9 the same
	# beat gets ~3.3 m, matching the threshold beat's own well-composed
	# framing instead of collapsing near it.
	#
	# A player deliberately mouse-look-dragging toward the full +-0.36 rad
	# cone CAN still push `raw_offset.x` past the gap's own 1.2 m
	# half-width at this depth -- that's the spring arm's own shapecast
	# correctly shortening the shot against the pier the player just aimed
	# at, the exact "geometry clips it, so the arm pulls in" behaviour this
	# rig is built on (see this file's class doc comment), not a
	# regression of the bug above: it only happens on deliberate extreme
	# input, never at the authored default.
	var desired_z := clampf(raw_z, -19.0, 15.9)
	var desired_x: float
	if desired_z == raw_z:
		# Common case: the courtyard has room for the full authored shot
		# in its intended direction.
		desired_x = clampf(raw_x, -15.0, 21.0)
	else:
		# Doorway collapse fix (Gate 1 camera item; 780c690's commit
		# message: "at the home doorway the SpringArm3D camera collapses
		# into the player"). Diagnosed with a throwaway probe script
		# (godot/tools/_probe_camera_debug.gd, deleted after use, not
		# committed): SpringArm3D's own shapecast never fires here --
		# measured collision shrink was 0.0000 at every route beat,
		# including the door beat. The collapse is entirely this clamp:
		# near the home threshold the player is already only ~1m from the
		# z=12.3 wall this zone's camera formula wants to sit *beyond* (by
		# `distance`, THRESHOLD's own 5.5 authored below), so clamping
		# desired.z alone silently threw away nearly all of the horizontal reach
		# while `height` stayed at its full authored value -- the spring
		# arm's horizontal leg collapsed to a handful of centimeters while
		# its vertical leg stayed meters tall, producing a near-vertical
		# look-down that fills the frame with the back of the player's
		# head.
		#
		# 780c690's own fix (superseded below, camera-fix task 2026-08-28):
		# preserve the authored shot's XZ-plane *radius* and let the
		# shortfall the wall imposes swing sideways along `lat` instead of
		# vanishing. That traded the vertical collapse for a *lateral* one
		# nobody had measured: at the home porch's OWN start position
		# (player.gd's START_POSITION, z=10 -- not an edge case, the game's
		# literal opening frame) it parks the camera ~4.8 m to the side of
		# the player, so the shot reads as beside the child rather than
		# behind them, every time the player is anywhere in the home room
		# (probed across z=8..16: this clamp branch is not a rare doorway
		# edge case here, it is the ENTIRE home room, because THRESHOLD/
		# APPROACH's authored distance -- 5.5-7 m -- simply doesn't fit
		# between the room's own start depth and the piers). Worse, once the
		# player is far enough in that the clamp bound (13.5) sits BEHIND
		# them (z > ~13.5, reachable through the 2.4 m doorway gap itself),
		# `used_z` goes negative and the radius-preserving swing still
		# throws the camera ~5 m to one side -- but "one side" is ambiguous
		# by design (`side_sign` picks whichever side `raw_offset.x`
		# leans, which for a centered player is close to a coin flip) and
		# BOTH sides are a solid pier there. Reproduced with this file's own
		# probe (godot/tools/_probe_camera_swing.gd, camera-fix task, not
		# committed): at z=15.93 the swung target sat inside the right
		# pier's footprint, SpringArm3D's shapecast (correctly) yanked it
		# back to a 1.8 m point-blank shot, and the resulting angle was
		# 127.6 deg off dead-behind -- in front of the player, not behind.
		#
		# Fix: preserve *direction* instead of radius -- scale the whole
		# raw offset (x and z together) toward the player by the same
		# factor `k` that brings its z-component exactly onto the wall
		# bound, rather than solving for whatever sideways x makes the
		# radius match. This is a dolly-in along the authored angle (arm
		# gets shorter, aim doesn't change), the same thing a SpringArm3D's
		# own shapecast does when it shortens on contact -- so at the start
		# position it now sits 3.2 deg off dead-behind at 3.5 m (58% of
		# authored, well clear of test_camera_never_in_geometry.gd's 0.10
		# floor) instead of 53.7 deg at 6.0 m. `raw_offset.z` is always
		# positive and dominated by `distance` (a few metres) for every
		# authored yaw this zone blends across, including the full
		# mouse-look range added above (+-0.36 rad, cos >= 0.93) -- safe to
		# divide by. `k` can go negative once `used_z` does (the player is
		# deep enough that even the wall bound sits ahead of them); since
		# `raw_offset.x` is always small (it's only ever `lateral`'s own
		# contribution, ~0.15-0.55 m, THRESHOLD/APPROACH/REVEAL never lean
		# far sideways), scaling it by a `k` in [-1,1] can't reproduce the
		# old wide swing -- worst case (deep in the doorway gap) it's a few
		# centimetres either side of centered, comfortably inside the 2.4 m
		# gap and clear of both piers, not a fresh collision. That deep
		# pocket is not visited by either narrative beat near this zone
		# (screenshot-measured: threshold z=10, door z=12.53, both short of
		# where the clamp bound crosses the player's own position at
		# z~13.5) -- same honest-limit treatment test_camera_never_in_
		# geometry.gd already gives the garden gap: the common case is
		# fixed outright, the rare deep-exploration pocket degrades to a
		# close, centered shot instead of a wrong one.
		var used_z := desired_z - p.z
		var k := clampf(used_z / raw_offset.z, -1.0, 1.0)
		desired_x = clampf(p.x + raw_offset.x * k, -15.0, 21.0)

	var desired := Vector3(desired_x, height + _look_pitch * LOOK_PITCH_HEIGHT_SCALE, desired_z)

	# game.mjs:407-409 -- look-at target, ahead of the player by `lead`.
	var forward := Vector3(-s, 0.0, -c)
	var target := Vector3(p.x, target_height, p.z) + forward * lead

	# game.mjs:402-403 -- position damped toward `desired`, not snapped to it.
	if not _initialized:
		_smoothed_desired = desired
		_initialized = true
	else:
		var alpha := 1.0 - exp(-delta * (16.0 if Game.reduced_motion else 7.3))
		_smoothed_desired = _smoothed_desired.lerp(desired, alpha)

	global_position = target
	# SpringArm3D extends its children along its local +Z axis (verified
	# empirically -- NOT -Z, despite -Z being every other node's "forward"
	# in Godot). look_at() orients -Z toward its argument, so to make +Z
	# point at `_smoothed_desired`, look_at() the point that's
	# _smoothed_desired reflected through target instead.
	#
	# look_at() errors (rather than no-op) if origin and target coincide --
	# possible in principle if the player is wedged into a tight corner and
	# the damped desired position degenerates onto the look-at target.
	# Skip that single tick's reorientation rather than crash; the previous
	# rotation stays, imperceptible at 60Hz.
	var mirrored_desired := 2.0 * target - _smoothed_desired
	if not target.is_equal_approx(mirrored_desired):
		look_at(mirrored_desired, Vector3.UP)
	spring_arm.spring_length = target.distance_to(_smoothed_desired)

	# game.mjs:410 -- lookAt(target); SpringArm3D only translates its child,
	# so the camera's own rotation is set explicitly here every tick.
	if not camera.global_position.is_equal_approx(target):
		camera.look_at(target, Vector3.UP)
	camera.fov = CameraProfile.damp(camera.fov, fov, 5.5, delta)

