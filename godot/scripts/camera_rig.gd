extends Node3D
## Port of src/game.mjs's updateCamera() (lines 384-411) onto a pivot (this
## node) -> SpringArm3D -> Camera3D chain. Verbatim except for the doorway
## fix inside _physics_process's `desired_x`/`desired_z` block below -- see
## its comment; game.mjs's own per-axis clamp is still the common path.
##
## The pivot sits at the look-at target (matching the source's
## threeCamera.lookAt(target)); the SpringArm3D is oriented from the pivot
## toward the damped desired camera position, with spring_length set to
## that distance -- so SpringArm3D's own collision shapecast pulls the
## camera inward exactly when geometry would otherwise clip it. That's the
## thing Saturday Afternoon's hand-rolled camera got wrong (follow camera
## left outside the starting room's walls). No orbit/mouse-look in this
## pass -- same simplification as player.gd, see its doc comment.

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _smoothed_desired: Vector3 = Vector3.ZERO
var _initialized: bool = false
var _excluded_player: bool = false


func _ready() -> void:
	Game.camera = camera


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

	var p := player.global_position
	var profile := CameraProfile.profile(p.z)
	# Pulled into explicitly-typed floats (not used inline from the
	# Dictionary) -- Vector3 has no operator overload for Variant, so an
	# inline `forward * profile["lead"]` can't be statically typed and
	# fails GDScript's `:=` inference. Same pattern as player.gd's yaw.
	var yaw: float = profile["authored_yaw"]  # mouse-look yaw omitted, see class doc
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

	# game.mjs:399-400's own authored world-space clamp (the courtyard's
	# actual x/z extents) -- test_camera_never_in_geometry.gd asserts the
	# FINAL camera position never exceeds these, so they stay the hard
	# outer bound no matter what happens below.
	var desired_z := clampf(raw_z, -12.55, 11.05)
	var desired_x: float
	if desired_z == raw_z:
		# Common case, and exactly game.mjs:399-400: the courtyard has room
		# for the full authored shot in its intended direction.
		desired_x = clampf(raw_x, -9.65, 9.65)
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
		# head. (Confirmed: even after Task 2's much lower height numbers
		# below, the *unfixed* clamp still collapses the arm to well under
		# 1m at the door beat -- a low camera alone doesn't fix this, it
		# just changes a steep collapse into a point-blank one.)
		#
		# Fix: preserve the authored shot *radius* (the XZ-plane distance
		# this zone was tuned for) and let the shortfall the wall imposes
		# swing sideways along `lat` instead of vanishing -- the same move
		# a camera operator backed against a wall makes (side-step, don't
		# melt into the subject). `horiz_radius` is what the uncapped
		# formula wanted in the XZ plane; `used_z` is what the wall
		# actually leaves for depth; `side_mag` is the sideways distance
		# that keeps the total radius (and so, combined with the
		# unclamped `height` above, roughly the total spring-arm length)
		# equal to what was authored.
		var horiz_radius := Vector2(raw_offset.x, raw_offset.z).length()
		var used_z := desired_z - p.z
		var side_mag := sqrt(maxf(0.0, horiz_radius * horiz_radius - used_z * used_z))
		var side_sign := 1.0 if raw_offset.x >= 0.0 else -1.0
		desired_x = clampf(p.x + side_sign * side_mag, -9.65, 9.65)

	var desired := Vector3(desired_x, height, desired_z)

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

