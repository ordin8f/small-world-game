class_name Swing
extends Node3D
## Gate 1 (mechanics agent): "swing and sandbox both need geometry that
## doesn't exist... swinging should have real arc and momentum and be
## worth doing twice." Self-contained, position-parametrized scene (see
## tools/_bootstrap_swing_scene.gd's own doc comment) -- dropped into
## main.tscn at an authored position rather than wired through
## tools/_bootstrap_courtyard.gd, which the world-expansion agent owns and
## is actively rewriting.
##
## Pendulum dynamics live in scripts/logic/swing_math.gd as a pure,
## unit-tested step function; this script only wires input -> that
## function -> the scene graph. It rotates $Pivot.rotation.x each tick;
## the chains and seat are $Pivot's own children (authored hanging
## straight down), so the seat's WORLD position/rotation fall out of
## Godot's transform hierarchy instead of being hand-computed here.
##
## Free-roam interactable (Game.free_interactables), like the other Gate 1
## mechanics: walk up, press interact to sit, press it again to hop off --
## the same single button toggles both directions, since this project has
## no separate "cancel" input action.

const SEAT_TOP_Y_OFFSET := 0.16  ## lifts the character visual to sit ON the seat's top face, not at its center
const MOUNT_RADIUS := 1.3
const DISMOUNT_SIDE_OFFSET := 0.9  ## clear of MOUNT_RADIUS so stepping off doesn't instantly re-trigger the mount prompt
const CREAK_THETA_WINDOW := 0.06   ## only near the bottom of the arc
const CREAK_MIN_OMEGA := 0.5
const CREAK_MIN_INTERVAL := 0.35

## "drive", not "sit". Both put the child at seat height with their legs out
## in front (they are the same seated pose in the Kenney rig), but "sit"
## leaves the arms hanging down through the seat while "drive" holds them
## up and forward -- which, on a swing, is holding the chains. The slide
## keeps "sit", where hands-in-lap is right and there is nothing to hold.
const RIDE_CLIP := "drive"

@onready var pivot: Node3D = $Pivot
@onready var seat: MeshInstance3D = $Pivot/Seat

var label: String = "Sit on the swing"
var radius: float = MOUNT_RADIUS

var _riding: bool = false
var _theta: float = 0.0
var _omega: float = 0.0
var _last_creak_time: float = -1000.0


func _ready() -> void:
	Game.register_free_interactable(self)
	Game.state_changed.connect(_on_state_changed)


func _exit_tree() -> void:
	Game.unregister_free_interactable(self)


func interact() -> void:
	if _riding:
		_dismount()
	else:
		_mount()


func _mount() -> void:
	if not is_instance_valid(Game.player):
		return
	_riding = true
	Game.player.external_control = true
	Game.player.character_visual.play_pose(RIDE_CLIP)


func _dismount() -> void:
	_riding = false
	if is_instance_valid(Game.player):
		var player := Game.player
		player.external_control = false
		# Land beside the swing's own base on whichever side it was
		# currently leaning toward, not directly under the seat mid-arc,
		# and clear of MOUNT_RADIUS so the very next physics tick's
		# free-interactable poll doesn't instantly re-offer "Sit on the
		# swing" before the player has visibly stepped away.
		var side: Vector3 = global_transform.basis.x if _theta >= 0.0 else -global_transform.basis.x
		player.global_position = global_position + side * DISMOUNT_SIDE_OFFSET
		player.global_position.y = player.locked_y
		player.rotation.y = global_rotation.y
		player.character_visual.set_motion(false, false)
	_theta = 0.0
	_omega = 0.0
	pivot.rotation.x = 0.0


func _physics_process(delta: float) -> void:
	if not _riding:
		return
	if not is_instance_valid(Game.player):
		_dismount()
		return

	var pump := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var result := SwingMath.step(_theta, _omega, pump, delta)
	_theta = result["theta"]
	_omega = result["omega"]
	pivot.rotation.x = _theta

	var seat_top: Vector3 = seat.global_position + Vector3(0.0, SEAT_TOP_Y_OFFSET, 0.0)
	Game.player.global_position = seat_top
	Game.player.rotation.y = global_rotation.y

	_maybe_creak()


## A soft wooden creak near the bottom of a strong-enough arc -- cheap game
## feel (puddles.gd's own doc comment: "cheap, high charm"), rate-limited
## the same way AudioDirector.play_step() self-limits footsteps so a long
## ride doesn't spam it every physics tick near theta=0.
func _maybe_creak() -> void:
	if absf(_theta) > CREAK_THETA_WINDOW or absf(_omega) < CREAK_MIN_OMEGA:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_creak_time < CREAK_MIN_INTERVAL:
		return
	_last_creak_time = now
	AudioDirector.play_swing_creak(absf(_omega) / SwingMath.MAX_OMEGA)


func _on_state_changed(new_state: String) -> void:
	if new_state == EpisodeDirector.State.ARRIVE and _riding:
		_dismount()
