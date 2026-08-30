class_name Ball
extends Node3D
## Verbatim port of the ball's state and behavior from src/game.mjs:
## ballStart/ballEnd/groupPosition constants, updateBall() (lines 360-374),
## dispatch()'s RETURN_BALL/INVITED side effects (lines 214-223), and
## updateScene()'s ball visibility/emissive (lines 449-455). Reacts to
## Game.state_changed rather than being polled by game.gd, keeping
## dispatch() to pure orchestration (see game.gd's doc comment).

## Relocated for the 2026-08-28 world expansion (world_bounds.gd's own doc
## comment has the four-room layout) -- same offsets from Group (0,-11,
## was (0,-3.8)) and the garden pocket's BallEnd marker (14,-12, was
## (8.6,-6.6)) the single-room version held from its own equivalents.
const START := Vector3(0.5, 0.45, -10.9)
const END := Vector3(14.0, 0.45, -12.0)
const REST_POSITION := Vector3(0.45, 0.42, -11.1)  # where it settles once returned
const ARC_HEIGHT := 2.1
const FLIGHT_SECONDS := 1.8
const MIN_Y := 0.45

## Where the carried ball sits relative to the child. Was 0.36 m off to one
## SIDE at 0.88 m, from before the child had a carry pose at all -- with
## CARRY_CLIP's two arms held out in front, a ball floating past one elbow
## is exactly the "ball beside an empty hand" tell. Centred and forward now.
##
## Low and close rather than out at hand height: this ball's radius is 0.42
## against a 1.08 m child, so it is a beach ball to them. Held out at arm
## height it eclipses the whole child from anywhere in front. Tucked to the
## chest its top lands just under the chin, the head stays clear, and the
## carry arms come over it -- which is how a child that size actually
## carries a ball this size.
const CARRY_FORWARD := 0.30
const CARRY_HEIGHT := 0.56

## Held for the whole carry, over idle, walk and sprint alike -- see
## character_visual.gd's set_arm_pose(). "holding-both" is arms-out-front
## with both hands, which is how a child that size carries a ball this size;
## "holding-right" (the one-handed variant) reads as carrying a bucket.
const CARRY_CLIP := "holding-both"

## The bend-down-and-scoop clip, played once as the ball is picked up. Not a
## prerequisite for anything: the state has already changed by the time this
## runs, and the clip plays alongside.
const PICKUP_CLIP := "pick-up"

## Handing it back. The right arm swings out in front, which is as close to
## "roll it to them" as the pack has -- there is no throw clip.
const RETURN_CLIP := "interact-right"

@onready var mesh: MeshInstance3D = $Mesh

var carrying: bool = false
var _tween: Tween = null


func _ready() -> void:
	global_position = START
	Game.ball = self
	Game.state_changed.connect(_on_state_changed)


func _physics_process(_delta: float) -> void:
	if carrying and is_instance_valid(Game.player):
		var player := Game.player
		# In front of the chest, not beside the hip: heading 0 faces -z (see
		# player.gd's atan2(-dx, -dz) convention), so forward is
		# (-sin(y), 0, -cos(y)).
		var forward := Vector3(-sin(player.rotation.y), 0.0, -cos(player.rotation.y)) * CARRY_FORWARD
		global_position = Vector3(player.global_position.x + forward.x, CARRY_HEIGHT, player.global_position.z + forward.z)

	if global_position.y < MIN_Y:
		global_position.y = MIN_Y

	_update_visibility_and_emissive()


## The animation calls below are presentation only, in every case AFTER the
## state has already changed and the mechanical side effect has already
## happened. Nothing here is awaited and nothing gates on a clip finishing,
## so picking the ball up and giving it back still succeed at exactly the
## moment they did before -- the child just does it visibly now.
func _on_state_changed(new_state: String) -> void:
	match new_state:
		EpisodeDirector.State.ARRIVE:
			# restart -- game.mjs's resetGame() reinitializes ballPosition/
			# carryingBall the same way.
			if _tween != null and _tween.is_valid():
				_tween.kill()
			carrying = false
			global_position = START
			_set_carry_pose(false)
		EpisodeDirector.State.BALL_IN_FLIGHT:
			_start_flight()
		EpisodeDirector.State.RETURN_BALL:
			carrying = true
			# The scoop and the carry start together on purpose: the arm
			# overlay eases in over the same crossfade the pick-up clip is
			# blending across, so the arms arrive already holding the ball
			# rather than snapping to the carry a third of a second later.
			var visual := CharacterVisual.of_player()
			if visual != null:
				visual.play_pose_once(PICKUP_CLIP)
			_set_carry_pose(true)
		EpisodeDirector.State.INVITED:
			carrying = false
			global_position = REST_POSITION
			_set_carry_pose(false)
			var giver := CharacterVisual.of_player()
			if giver != null:
				giver.play_pose_once(RETURN_CLIP)


func _set_carry_pose(carried: bool) -> void:
	var visual := CharacterVisual.of_player()
	if visual == null:
		return
	if carried:
		visual.set_arm_pose(CARRY_CLIP)
	else:
		visual.clear_arm_pose()


func _start_flight() -> void:
	carrying = false
	_set_carry_pose(false)  # unreachable from the authored route, but carrying must never outlive `carrying`
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_on_flight_progress, 0.0, 1.0, FLIGHT_SECONDS)
	_tween.finished.connect(func() -> void: Game.dispatch("ball_landed"))


func _on_flight_progress(t: float) -> void:
	var arc := sin(t * PI) * ARC_HEIGHT
	global_position = Vector3(
		lerpf(START.x, END.x, t),
		lerpf(START.y, END.y, t) + arc,
		lerpf(START.z, END.z, t)
	)


func _update_visibility_and_emissive() -> void:
	var state := Game.director.state
	var hidden_with_group := (
		state == EpisodeDirector.State.INVITED
		or state == EpisodeDirector.State.GO_HOME
		or state == EpisodeDirector.State.COMPLETE
	)
	var ball_visible := not hidden_with_group or carrying
	visible = ball_visible
	if not ball_visible:
		return

	var glow := 0.0
	if state == EpisodeDirector.State.FIND_BALL:
		glow = Game.lens.get_visuals()["curiosity_glow"] * 0.55
	var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat != null:
		mat.emission_energy_multiplier = glow
