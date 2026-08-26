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

@export var walk_speed: float = 2.65
@export var run_speed: float = 4.1
@export var locked_y: float = 0.0

## game.mjs:80's authored start (also resetGame()'s player.position, lines
## 242-263) -- the doorway threshold, not the world origin. Missed in the
## original M1.3/M2.2 port: nothing set the player's x/z, so it defaulted
## to (0, 0, 0), which CameraProfile.profile() treats as already fully
## APPROACH-zoned (the z=7..3 threshold->approach blend saturates at
## z<=3), skipping the authored THRESHOLD opening shot entirely. Found
## while shooting M3.4's "threshold" reference frame.
const START_POSITION := Vector3(0.0, 0.0, 6.5)

## Set true only while an actual movement key is held -- mirrors
## player.moving in the source, which gates heading/walk-cycle updates too
## (heading holds its last value when idle, it doesn't snap to zero).
var moving: bool = false
var running: bool = false
var heading: float = 0.0
var walk_cycle: float = 0.0

@onready var character_visual: CharacterVisual = $Player


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


func _physics_process(delta: float) -> void:
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


static func _angle_delta(target: float, current: float) -> float:
	return atan2(sin(target - current), cos(target - current))
