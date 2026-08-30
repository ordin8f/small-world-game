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

## Fixed eye for the two slide-alignment frames. Close, level with the
## middle of the run, and looking ACROSS it -- the play camera sits behind
## the player and so points straight down the slide, which is the one angle
## from which a rider sunk into the plank and a rider sitting on it look
## exactly the same. That is why the 2026-08-30 misalignment survived both
## the test suite and every screenshot beat until someone played it.
const SLIDE_EYE := Vector3(2.8, 4.0, -9.8)
const SLIDE_SUBJECT := Vector3(-3.4, 1.3, -10.5)

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

	# --- 1. Tower: climb the stairs, stand on the platform, slide down ----
	_player.global_position = WorldAffordances.CLIMB_TRIGGER
	await _wait_ticks(55)  # partway up the staircase -- stairs, ground and tower all read
	await _capture("climbing")
	# Side-on, so the question "are the child's feet on the treads or is
	# this a lift up a blank face" is actually answerable from the frame.
	await _capture_from("climbing_side_on", Vector3(-6.2, 2.8, -18.2), Vector3(-6.2, 1.45, -12.25))

	await _wait_for_verb("ON_PLATFORM", 300)
	await _capture("on_platform")
	# The EMPTY slide from the exact eye the ride below is shot from. The
	# pair is the diagnostic: the first frame shows where the plank's
	# surface is, the second shows where the child is, and the tower's own
	# cast shadow (which covers this whole run in most moods) cannot hide a
	# discrepancy across both.
	await _capture_from("slide_empty_side_on", SLIDE_EYE, SLIDE_SUBJECT)

	_runner.simulate_action_press("move_back")
	await _wait_for_verb("SLIDING", 60)
	# Mid-ride, side-on. THE frame for the 2026-08-30 alignment defect: from
	# behind the player the slide is edge-on and a rider sunk into the plank
	# looks identical to one sitting on it, which is exactly why the tests
	# and the screenshots both missed it and the developer did not.
	# (_capture() itself settles for 20 more ticks before grabbing, so these
	# waits are ~20 short of where each frame actually lands: the ride is
	# 1.3 s / 78 ticks, of which the first 64 are on the plank.)
	await _wait_ticks(6)
	# Grazing, from just in front of the foot looking back UP the run. The
	# side-on pair below is partly blocked by the near rail (which is doing
	# its job); this one puts the eye almost in the plane of the bed, so a
	# rider sunk into it would have the surface cutting across them and one
	# floating over it would show daylight underneath.
	await _capture_from("sliding_up_slope", Vector3(-3.4, 0.55, -7.9), Vector3(-3.4, 2.2, -10.9))
	await _capture_from("sliding_side_on", SLIDE_EYE, SLIDE_SUBJECT)
	await _capture("sliding")  # late in the ride -- the play camera's own framing
	await _wait_for_verb("GROUND", 200)
	_runner.simulate_action_release("move_back")
	await _wait_ticks(10)
	await _capture("slide_landed")

	# --- 1b. The tower as the player meets it -----------------------------
	# Standing back on the approach: does a staircase read as an obvious way
	# up from where a child actually stands, or does the slide still look
	# like the only route?
	_player.global_position = Vector3(-5.6, 0.0, -8.2)
	await _wait_ticks(90)
	await _capture("tower_approach")

	# --- 1c. Sitting on the bench -----------------------------------------
	_player.global_position = WorldAffordances.bench_stand_position()
	await _wait_ticks(60)
	_game.interact()
	await _wait_ticks(40)
	await _capture("bench_sitting")
	await _capture_from("bench_sitting_close", Vector3(-4.6, 1.5, -8.2), Vector3(-7.0, 0.75, -9.8))
	_game.interact()
	await _wait_ticks(20)

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
	# WALL_WALKING/_wall_offset pointed at an edge that happens to still
	# validate at the new x/z, holding the player on the edging instead of
	# the ground it just teleported onto.
	_player.verb = _player.Verb.GROUND
	_player.set("_wall_offset", 0.0)
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


## A capture from a throwaway camera at a fixed spot instead of the play
## camera. The play camera sits behind the player looking the way they face,
## which is the one angle that CANNOT answer "is the child on the surface or
## inside it" for either the slide or the stairs -- both run away from the
## viewer there. Restores whatever camera was current afterwards, so the
## route carries on unaffected.
##
## Carries its own fill light, which the ordinary beats above deliberately do
## not. These frames are MEASUREMENTS, not art: the playground's tower casts
## a hard shadow straight down the slide in most moods, and a black frame
## answers nothing. The fill is local to this function and gone before the
## next real beat, so nothing the art passes look at is touched by it.
func _capture_from(beat_name: String, from: Vector3, look_at: Vector3) -> void:
	var previous: Camera3D = get_root().get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 55.0
	_main.add_child(cam)
	cam.global_position = from
	cam.look_at(look_at, Vector3.UP)
	cam.current = true

	var fill := OmniLight3D.new()
	fill.omni_range = 30.0
	fill.light_energy = 1.6
	fill.shadow_enabled = false
	_main.add_child(fill)
	fill.global_position = from + Vector3(0.0, 1.5, 0.0)

	await _capture(beat_name)
	fill.queue_free()
	cam.queue_free()
	if is_instance_valid(previous):
		previous.current = true


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
