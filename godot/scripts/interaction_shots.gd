extends SceneTree
## Windowed screenshot capture for the INTERACTION animations specifically:
## the carry (standing and walking), the sandbox crouch, pocketing a
## keepsake, the arms-out balance, and the two seated rides. Same technique
## as scripts/verb_shots.gd and scripts/mechanics_shots.gd (in-engine
## Viewport capture; headless never renders a frame to grab), kept as its
## own file rather than added to either of those so the three "what does
## this look like" tools stay independently owned and mergeable.
##
## Deliberately shoots each beat from a fixed close camera of its own rather
## than through the play camera: the play camera frames the WORLD, and at
## its distance a pose is thirty pixels tall. What is being judged here is
## whether the child's arms are holding the ball, which needs the child to
## fill the frame.
##
## Must run WITHOUT --headless. Usage:
##   godot --path godot --script res://scripts/interaction_shots.gd --resolution 1280x720

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://interaction_shots"
const WARMUP_TICKS := 90

var _runner: GdUnitSceneRunner = null
var _main: Node = null
var _player: Node3D = null
var _game: Node = null
var _camera: Camera3D = null
var _shot_index: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)
	_main = _runner.scene()
	if _main == null:
		push_error("interaction_shots: failed to load/instantiate %s" % SCENE_PATH)
		_shutdown(1)
		return

	_hide_ui()
	_game = get_root().get_node("Game")
	_player = _game.player
	if not is_instance_valid(_player):
		push_error("interaction_shots: Game.player is null after scene load")
		_shutdown(1)
		return

	_game.start_episode(0.0)
	_hide_ui()
	for _i in range(WARMUP_TICKS):
		await physics_frame

	# Our own close camera, made current in place of the play camera (and of
	# title_camera.gd's, which _ready() otherwise leaves current for this
	# script's whole run -- see mechanics_shots.gd's note on the same trap).
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_main.add_child(_camera)
	_camera.current = true

	await _shoot_carry()
	await _shoot_sandbox()
	await _shoot_treasure()
	await _shoot_balance()
	await _shoot_swing()
	await _shoot_slide()

	print("SHOTS_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))
	_shutdown(0)


# ------------------------------------------------------------------- carry --

func _shoot_carry() -> void:
	# The reference frame first: same child, same camera, empty-handed.
	await _wait_ticks(20)
	await _capture("carry_00_before_empty_handed")

	# Drive the rail to the moment the ball is picked up. Dispatched rather
	# than walked -- this tool is about the pose, and test_playthrough.gd
	# already owns "the route actually works".
	#
	# ball_landed is NOT dispatched by hand: ball.gd's own 1.8s flight tween
	# fires it when the arc lands, and a hand-dispatch races it -- the tween
	# keeps driving the ball's position for the rest of its run, so the child
	# stands there in a perfect carry pose holding nothing while the ball is
	# still flying to the garden. Waiting for the real transition is also
	# what a real player does.
	_game.dispatch("observe")
	_game.dispatch("ball_kicked")
	await _wait_for_state(EpisodeDirector.State.FIND_BALL, 240)
	await _wait_ticks(10)
	_game.dispatch("ball_picked_up")
	await _wait_ticks(8)
	await _capture("carry_01_pick_up_clip")

	await _wait_ticks(40)  # past the pick-up hold, into the steady carry
	await _capture("carry_02_standing_with_ball")

	_runner.simulate_action_press("move_forward")
	await _wait_ticks(40)
	await _capture("carry_03_walking_with_ball")
	_runner.simulate_action_press("run")
	await _wait_ticks(30)
	await _capture("carry_04_running_with_ball")
	_runner.simulate_action_release("run")
	_runner.simulate_action_release("move_forward")
	await _wait_ticks(20)

	# ...and the same carry through the camera the game actually plays on.
	# Every shot above is from in front, which is the worst possible angle
	# for this ball: its radius is 0.42 against a 1.08 m child, so anything
	# held in front of them eclipses them from the front no matter where it
	# is put. The play camera sits behind and above, where a ball held in
	# front reads as held rather than as a wall.
	await _capture("carry_07_from_the_play_camera", true)

	_game.dispatch("ball_returned")
	await _wait_ticks(8)
	await _capture("carry_05_giving_it_back")
	await _wait_ticks(40)
	await _capture("carry_06_empty_handed_again")


# ---------------------------------------------------------------- free-roam --

func _shoot_sandbox() -> void:
	var sandbox: Node3D = _main.find_child("Sandbox", true, false)
	if sandbox == null:
		return
	_player.global_position = sandbox.global_position
	await _wait_ticks(20)
	await _capture("sandbox_00_standing_in_the_pit")
	_game.interact()
	await _wait_ticks(10)
	await _capture("sandbox_01_patting_the_sand")


func _shoot_treasure() -> void:
	var marble: Node3D = _main.find_child("Marble", true, false)
	if marble == null:
		return
	_player.global_position = marble.global_position
	await _wait_ticks(20)
	_game.interact()
	await _wait_ticks(8)
	await _capture("treasure_00_pocketing_it")


# -------------------------------------------------------------------- verbs --

func _shoot_balance() -> void:
	# Same mount point test_player_verbs.gd and verb_shots.gd both use.
	_player.global_position = Vector3(-4.15, 0.0, 13.2)
	await _wait_for_verb("WALL_WALKING", 120)
	await _wait_ticks(30)
	await _capture("balance_00_arms_out_standing")
	_runner.simulate_action_press("move_forward")
	await _wait_ticks(30)
	await _capture("balance_01_arms_out_walking")
	_runner.simulate_action_release("move_forward")
	await _wait_ticks(10)

	# Clean dismount before jumping to unrelated geometry -- a raw teleport
	# can otherwise leave the player stuck on the wall (verb_shots.gd hit
	# exactly this and documents it).
	_player.call("_start_wall_dismount")
	await _wait_for_verb("GROUND", 120)
	_player.global_position.y = 0.0


func _shoot_swing() -> void:
	var swing: Node3D = _main.find_child("Swing", true, false)
	if swing == null:
		return
	_player.global_position = swing.global_position + Vector3(0.6, 0.0, 0.0)
	await _wait_ticks(20)
	_game.interact()
	await _wait_ticks(30)
	await _capture("swing_00_seated")
	# Pumped, not just waited on: SwingMath holds a swing at rest forever
	# with no input, so an unpumped "mid arc" shot is the seated shot again.
	_runner.simulate_action_press("move_forward")
	await _wait_ticks(70)
	_runner.simulate_action_release("move_forward")
	await _capture("swing_01_mid_arc")
	_game.interact()  # hop off
	await _wait_ticks(20)


func _shoot_slide() -> void:
	_player.global_position = WorldAffordances.CLIMB_TRIGGER
	await _wait_for_verb("ON_PLATFORM", 300)
	_runner.simulate_action_press("move_back")
	await _wait_for_verb("SLIDING", 90)
	_runner.simulate_action_release("move_back")
	await _wait_ticks(30)
	await _capture("slide_00_riding_down")


# ------------------------------------------------------------------ helpers --

## Frames the child from a fixed three-quarter front angle, close enough
## that the arms are legible. Aimed at chest height so a crouch and a
## standing carry both stay in frame.
func _place_camera() -> void:
	var p := _player.global_position
	var forward := Vector3(-sin(_player.rotation.y), 0.0, -cos(_player.rotation.y))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var aim := p + Vector3(0.0, 0.55, 0.0)
	_camera.global_position = aim + forward * 2.2 + right * 1.5 + Vector3(0.0, 0.45, 0.0)
	_camera.look_at(aim, Vector3.UP)


## `use_play_camera` hands the frame back to the game's own third-person
## camera instead of this tool's close one -- for the handful of beats where
## the question is "how does this read in play", not "what is the pose".
func _capture(beat_name: String, use_play_camera: bool = false) -> void:
	_hide_ui()
	if use_play_camera and is_instance_valid(_game.camera):
		_game.camera.current = true
	else:
		_place_camera()
		_camera.current = true
	for _i in range(4):
		await physics_frame
	await process_frame

	var img: Image = get_root().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("interaction_shots: %s produced no image" % beat_name)
		return

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_shot_index += 1
	var rel_path := "%s/%02d_%s.png" % [OUT_DIR, _shot_index, beat_name]
	var err := img.save_png(rel_path)
	if err != OK:
		push_error("interaction_shots: save_png(%s) failed: %d" % [rel_path, err])
		return

	var visual: Node = _player.character_visual
	print("[%s] clip=%s arm_pose=%s blend=%.2f -> %s" % [
		beat_name, visual.current_clip(), visual.arm_pose_clip(), visual.arm_pose_blend(),
		ProjectSettings.globalize_path(rel_path),
	])


func _wait_ticks(n: int) -> void:
	for _i in range(n):
		await physics_frame


func _wait_for_state(state: String, max_ticks: int) -> void:
	for _i in range(max_ticks):
		if _game.director.state == state:
			return
		await physics_frame
	push_error("interaction_shots: never reached state %s" % state)


func _wait_for_verb(verb_name: String, max_ticks: int) -> void:
	for _i in range(max_ticks):
		if _player.verb == _player.Verb[verb_name]:
			return
		await physics_frame


## Mirrors screenshot_route.gd's own _shutdown() -- see its doc comment for
## why GdUnitSceneRunner must be released via the Engine meta key before
## quit(), not just have its local variable nulled.
func _shutdown(code: int) -> void:
	_runner = null
	Engine.remove_meta("GdUnitSceneRunner")
	quit(code)


func _hide_ui() -> void:
	_hide_canvas_layers_recursive(_main)


func _hide_canvas_layers_recursive(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child in node.get_children():
		_hide_canvas_layers_recursive(child)
