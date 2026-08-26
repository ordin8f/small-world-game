extends Node3D
## Verbatim port of src/game.mjs's updateCamera() (lines 384-411) onto a
## pivot (this node) -> SpringArm3D -> Camera3D chain.
##
## The pivot sits at the look-at target (matching the source's
## threeCamera.lookAt(target)); the SpringArm3D is oriented from the pivot
## toward the damped desired camera position, with spring_length set to
## that distance -- so SpringArm3D's own collision shapecast pulls the
## camera inward exactly when geometry would otherwise clip it. That's the
## thing Saturday Afternoon's hand-rolled camera got wrong (follow camera
## left outside the starting room's walls). No orbit/mouse-look in this
## pass -- same simplification as player.gd, see its doc comment.

@export var reduced_motion: bool = false

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

	# game.mjs:394-400 -- desired camera position, clamped.
	var desired := Vector3(
		p.x + s * distance + c * lateral,
		height,
		p.z + c * distance - s * lateral
	)
	desired.x = clampf(desired.x, -9.65, 9.65)
	desired.z = clampf(desired.z, -12.55, 11.05)

	# game.mjs:407-409 -- look-at target, ahead of the player by `lead`.
	var forward := Vector3(-s, 0.0, -c)
	var target := Vector3(p.x, target_height, p.z) + forward * lead

	# game.mjs:402-403 -- position damped toward `desired`, not snapped to it.
	if not _initialized:
		_smoothed_desired = desired
		_initialized = true
	else:
		var alpha := 1.0 - exp(-delta * (16.0 if reduced_motion else 7.3))
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
