extends SceneTree
## Gate 0: windowed screenshot capture for the four new playground verbs --
## climb+slide, garden-edging balance, stepping-stones imagination cue, and
## the puddle splash. Same technique as scripts/screenshot_route.gd
## (in-engine Viewport capture; headless never renders a frame to grab),
## but these verbs live off the authored 7-event route, so this drives
## player.gd directly by teleport + simulated input rather than walking
## DriveRoute waypoints.
##
## Must run WITHOUT --headless. Usage:
##   godot --path godot --script res://scripts/verb_shots.gd --resolution 1280x720

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://verb_shots"
const WARMUP_TICKS := 150

var _runner: GdUnitSceneRunner = null
var _main: Node = null
var _player: Node3D = null
var _game: Node = null
var _shot_index: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)
	_main = _runner.scene()
	if _main == null:
		push_error("verb_shots: failed to load/instantiate %s" % SCENE_PATH)
		_shutdown(1)
		return

	_hide_ui()
	_game = get_root().get_node("Game")
	_player = _game.player
	if not is_instance_valid(_player):
		push_error("verb_shots: Game.player is null after scene load")
		_shutdown(1)
		return

	# Gate 0 frame: force the real play camera current -- see
	# screenshot_route.gd's identical fix for why (TitleCamera's own
	# _ready() otherwise keeps its fixed drift camera active for this
	# script's entire run, since it never goes through title_card.gd's
	# Play button / glide_to_gameplay() handoff).
	if is_instance_valid(_game.camera):
		_game.camera.current = true

	_game.start_episode(0.0)
	_hide_ui()

	for _i in range(WARMUP_TICKS):
		await physics_frame

	# --- 1. Tower: climb, stand on the platform, slide down ---------------
	_player.global_position = WorldAffordances.CLIMB_TRIGGER
	await _wait_ticks(18)  # partway up the rise -- ground and tower both read
	await _capture("climbing")

	await _wait_for_verb("ON_PLATFORM", 200)
	await _capture("on_platform")

	_runner.simulate_action_press("move_back")
	await _wait_for_verb("SLIDING", 60)
	await _wait_ticks(42)  # late in the ride, close to the launch -- lower z
	await _capture("sliding")  # means a closer APPROACH-leaning camera than mid-ride
	await _wait_for_verb("GROUND", 200)
	_runner.simulate_action_release("move_back")
	await _wait_ticks(10)
	await _capture("slide_landed")

	# --- 2. Garden bed edging: mount and balance along the top -------------
	# Balance verb moved off the tall boundary wall onto a low brick edging
	# by the home threshold (world_affordances.gd's own doc comment); same
	# offset test_player_verbs.gd uses.
	_player.global_position = Vector3(-4.15, 0.0, 13.2)
	await _wait_for_verb("WALL_WALKING", 60)
	_runner.simulate_action_press("move_forward")
	await _wait_ticks(45)
	await _capture("edging_balancing")
	_runner.simulate_action_release("move_forward")
	await _wait_ticks(10)

	# Force a clean dismount before jumping to unrelated geometry -- a real
	# player always walks continuously between these, so verb is always
	# GROUND by the time they arrive somewhere new; a raw teleport (this
	# script's own shortcut, not something real play ever does) can leave
	# WALL_WALKING/_wall_offset_x pointed at a segment that happens to still
	# validate at the new x/z, holding the player on the wall instead of the
	# ground it just teleported onto.
	_player.verb = _player.Verb.GROUND
	_player.set("_wall_offset_x", 0.0)
	_player.character_visual.rotation.z = 0.0
	_player.global_position.y = 0.0

	# --- 3. Stepping stones: the gap (imagination cue) vs. a stone ---------
	_player.global_position = Vector3(12.1, 0.0, -10.3)
	await _wait_ticks(100)
	await _capture("stones_gap_imagination")

	var stone: Dictionary = WorldAffordances.STONES[0]
	_player.global_position = Vector3(stone["x"], 0.0, stone["z"])
	await _wait_ticks(100)
	await _capture("on_stone_ordinary")

	# --- 4. Puddle splash ---------------------------------------------------
	var puddle: Dictionary = WorldAffordances.PUDDLES[0]
	_player.global_position = Vector3(0.0, 0.0, 10.0)  # dry ground first, so entering it is a fresh trigger
	await _wait_ticks(6)
	_player.global_position = Vector3(puddle["x"], 0.0, puddle["z"])
	await _wait_ticks(8)  # ring is young, bright, and still small -- reads clearly
	await _capture("puddle_splash")

	# --- 5. Imagination cue, isolated: same camera position, cue off vs on -
	# The four beats above each drive the cue through real player movement,
	# which also changes the camera zone -- useful for "does the verb
	# work" but useless for "how strong does the cue actually read", since
	# the framing itself changes too. Forcing it directly at one fixed
	# position isolates that.
	var perception: Node = _main.find_child("Perception", true, false)
	var stepping_stones: Node = _main.find_child("SteppingStones", true, false)
	if perception != null and stepping_stones != null:
		stepping_stones.set_physics_process(false)  # isolate: stop its own poller fighting the override below
		_player.global_position = Vector3(12.1, 0.0, -10.3)  # identical camera framing both shots

		perception.call("set_imagination_target", false)
		await _wait_ticks(60)
		await _capture("imagination_off_reference")

		perception.call("set_imagination_target", true)
		await _wait_ticks(60)
		await _capture("imagination_on_isolated")

	print("SHOTS_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))
	_shutdown(0)


## Mirrors screenshot_route.gd's own _shutdown() -- see its doc comment for
## why GdUnitSceneRunner must be released via the Engine meta key before
## quit(), not just have its local variable nulled.
func _shutdown(code: int) -> void:
	_runner = null
	Engine.remove_meta("GdUnitSceneRunner")
	quit(code)


func _wait_ticks(n: int) -> void:
	for _i in range(n):
		await physics_frame


## Polls player.verb (a script-level enum, not statically typed on the
## loosely-typed _player: Node3D handle here -- same untyped-handle
## approach screenshot_route.gd already uses for _player/_game) by name
## rather than ordinal, so this stays correct if player.gd's Verb enum is
## ever reordered.
func _wait_for_verb(verb_name: String, max_ticks: int) -> void:
	for _i in range(max_ticks):
		var current: int = _player.verb
		var enum_value: int = _player.Verb[verb_name]
		if current == enum_value:
			return
		await physics_frame


func _capture(beat_name: String) -> void:
	_hide_ui()
	for _i in range(20):
		await physics_frame

	var img: Image = get_root().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("verb_shots: %s produced no image" % beat_name)
		return

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_shot_index += 1
	var rel_path := "%s/%02d_%s.png" % [OUT_DIR, _shot_index, beat_name]
	var err := img.save_png(rel_path)
	if err != OK:
		push_error("verb_shots: save_png(%s) failed: %d" % [rel_path, err])
		return

	var abs_path := ProjectSettings.globalize_path(rel_path)
	var p := _player.global_position
	print("[%s] verb=%s player=(%.2f, %.2f, %.2f) -> %s" % [
		beat_name, _player.Verb.keys()[_player.verb], p.x, p.y, p.z, abs_path,
	])


func _hide_ui() -> void:
	_hide_canvas_layers_recursive(_main)


func _hide_canvas_layers_recursive(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child in node.get_children():
		_hide_canvas_layers_recursive(child)
