extends Node3D
## Verbatim port of the ball's state and behavior from src/game.mjs:
## ballStart/ballEnd/groupPosition constants, updateBall() (lines 360-374),
## dispatch()'s RETURN_BALL/INVITED side effects (lines 214-223), and
## updateScene()'s ball visibility/emissive (lines 449-455). Reacts to
## Game.state_changed rather than being polled by game.gd, keeping
## dispatch() to pure orchestration (see game.gd's doc comment).

const START := Vector3(0.5, 0.45, -3.7)
const END := Vector3(8.6, 0.45, -6.6)
const REST_POSITION := Vector3(0.45, 0.42, -3.9)  # game.mjs:220, where it settles once returned
const ARC_HEIGHT := 2.1
const FLIGHT_SECONDS := 1.8
const CARRY_SIDE := 0.36
const CARRY_HEIGHT := 0.88
const MIN_Y := 0.45

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
		var side := Vector3(cos(player.rotation.y) * CARRY_SIDE, 0.0, -sin(player.rotation.y) * CARRY_SIDE)
		global_position = Vector3(player.global_position.x + side.x, CARRY_HEIGHT, player.global_position.z + side.z)

	if global_position.y < MIN_Y:
		global_position.y = MIN_Y

	_update_visibility_and_emissive()


func _on_state_changed(new_state: String) -> void:
	match new_state:
		EpisodeDirector.State.ARRIVE:
			# restart -- game.mjs's resetGame() reinitializes ballPosition/
			# carryingBall the same way.
			if _tween != null and _tween.is_valid():
				_tween.kill()
			carrying = false
			global_position = START
		EpisodeDirector.State.BALL_IN_FLIGHT:
			_start_flight()
		EpisodeDirector.State.RETURN_BALL:
			carrying = true
		EpisodeDirector.State.INVITED:
			carrying = false
			global_position = REST_POSITION


func _start_flight() -> void:
	carrying = false
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
