extends SceneTree
## Renders the real play camera at arbitrary standing positions, so the
## worst offenders tools/_probe_camera_sweep.gd finds can actually be
## LOOKED at instead of trusted from a number.
##
## tools/shots.ps1's six authored beats are necessary and not sufficient --
## they are exactly the six points four prior rounds of camera work kept
## re-measuring while the developer found faults everywhere else. This
## takes the coordinates out of the sweep's ranked table and shoots them.
##
##   tools\godot.ps1 --path . --script res://tools/_shot_at.gd \
##       --resolution 1280x720 -- -10 -5 16 -17 -6 -14.5
##
## (x z x z ... pairs after the "--"; NEVER --headless, which renders no
## frame at all -- screenshot_route.gd's own doc comment has the reasoning
## and this file reuses its capture, title-camera and shutdown handling
## verbatim in method.)

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://shots_at"
const WARMUP_TICKS := 150
## camera_rig.gd damps with lambda 7.3; 90 ticks is 1.5 s, well past
## convergence, and matches test_camera_never_in_geometry.gd's own settle.
const SETTLE_TICKS := 90

var _runner: GdUnitSceneRunner = null
var _main: Node = null
var _game: Node = null
var _player: Node3D = null
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var spots: Array = []
	var i := 0
	while i + 1 < args.size():
		spots.append(Vector2(float(args[i]), float(args[i + 1])))
		i += 2
	if spots.is_empty():
		push_error("_shot_at: no positions given (expected 'x z' pairs after --)")
		_shutdown(1)
		return

	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)
	_main = _runner.scene()
	if _main == null:
		push_error("_shot_at: failed to instantiate %s" % SCENE_PATH)
		_shutdown(1)
		return
	_game = get_root().get_node("Game")
	_player = _game.player

	# TitleCamera's _ready() steals `current`; without this every frame is
	# the title drift camera, not the play rig (screenshot_route.gd's own
	# comment records the round where that silently invalidated a whole set).
	if is_instance_valid(_game.camera):
		_game.camera.current = true
	_game.start_episode(0.0)
	_hide_canvas_layers(_main)
	for _w in range(WARMUP_TICKS):
		await physics_frame

	# player.gd does nothing at all while this is set -- no input, no
	# move_and_slide, no proximity verbs -- so the child stays exactly
	# where it is put and no stray tower-climb starts mid-capture.
	_player.external_control = true

	var index := 0
	for spot in spots:
		index += 1
		_player.global_position = Vector3(spot.x, _player.locked_y, spot.y)
		_hide_canvas_layers(_main)
		for _s in range(SETTLE_TICKS):
			await physics_frame
		await _capture(index, spot)

	print("SHOTS_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))
	if _failures.is_empty():
		print("_shot_at: %d shot(s) captured cleanly." % index)
		_shutdown(0)
	else:
		push_error("_shot_at: %d shot(s) look broken: %s" % [_failures.size(), ", ".join(_failures)])
		_shutdown(1)


func _capture(index: int, spot: Vector2) -> void:
	var img: Image = get_root().get_texture().get_image()
	if img == null or img.is_empty():
		_failures.append("#%d (no image)" % index)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var name_part := "%02d_x%+05.1f_z%+05.1f" % [index, spot.x, spot.y]
	var rel_path := "%s/%s.png" % [OUT_DIR, name_part.replace(".", "p")]
	var err := img.save_png(rel_path)
	if err != OK:
		_failures.append("#%d (save_png %d)" % [index, err])
		return
	var p := _player.global_position
	var cam: Camera3D = _game.camera
	var c := cam.global_position
	print("[%02d] player=(%.2f, %.2f) camera=(%.2f, %.2f, %.2f) dist=%.2f -> %s" % [
		index, p.x, p.z, c.x, c.y, c.z, c.distance_to(p),
		ProjectSettings.globalize_path(rel_path),
	])


func _hide_canvas_layers(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child in node.get_children():
		_hide_canvas_layers(child)


## See scripts/screenshot_route.gd's _shutdown() -- quit() with the runner
## still referenced double-frees the scene and segfaults on exit.
func _shutdown(code: int) -> void:
	_runner = null
	Engine.remove_meta("GdUnitSceneRunner")
	quit(code)
