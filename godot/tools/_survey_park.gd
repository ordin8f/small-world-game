extends SceneTree
## Survey shots: the park seen from places the six story beats never look.
##
## tools/shots.ps1 renders the authored route, which is the right thing to
## judge the GAME on -- but every one of its six cameras sits on the
## world's central north-south spine, so the whole west lawn, the south
## boundary and the south-east corner are off-frame in all six. A pass
## whose brief is "the left and right hand areas" cannot be checked with
## six frames that never point left or right.
##
## Free camera, not the play camera: this is a look at the level, not a
## check of the framing. Runs WITHOUT --headless for the same reason
## screenshot_route.gd does -- headless never renders a frame to capture.
##
##   godot --path godot --script res://tools/_survey_park.gd --resolution 1280x720

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://survey"
const SETTLE_TICKS := 150

## name, eye x/y/z, look-at x/y/z, fov
const VIEWS := [
	["a_gate_looking_in", 0.0, 2.2, -1.5, 0.0, 1.0, -14.0, 58.0],
	["b_plaza_looking_west", 0.0, 1.9, -8.6, -22.0, 1.4, -11.0, 58.0],
	["c_plaza_looking_east", 0.0, 1.9, -8.6, 22.0, 1.4, -11.0, 58.0],
	["d_west_lawn_looking_east", -20.0, 1.9, -12.0, 6.0, 1.2, -12.0, 58.0],
	["e_south_walk_looking_north", -2.0, 1.9, -21.0, 0.0, 1.6, -6.0, 58.0],
	["f_se_corner_looking_west", 20.0, 2.0, -20.0, -10.0, 1.5, -15.0, 58.0],
	["g_high_over_the_park", -4.0, 22.0, 10.0, -1.0, 0.0, -15.0, 62.0],
	["h_west_edge_looking_south", -19.0, 1.9, -6.0, -14.0, 1.2, -22.0, 58.0],
]


func _initialize() -> void:
	await _run()


func _run() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	var scene: Node = packed.instantiate()
	get_root().add_child(scene)

	var cam := Camera3D.new()
	get_root().add_child(cam)
	cam.far = 200.0

	await process_frame
	await process_frame
	# Past the title screen and into the episode's own opening state, so the
	# emotional lens is running the play mood rather than the title one --
	# perception.gd rewrites every light and the fog every frame from that
	# state, so a survey shot taken at the title would be a photograph of
	# lighting the player never sees. Same two calls screenshot_route.gd
	# makes, and the same reason.
	var game: Node = get_root().get_node("Game")
	if is_instance_valid(game.camera):
		game.camera.current = true
	game.start_episode(0.0)
	_hide_canvas_layers(scene)

	for i in range(SETTLE_TICKS):
		await process_frame
	_hide_canvas_layers(scene)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for view in VIEWS:
		cam.position = Vector3(view[1], view[2], view[3])
		cam.look_at(Vector3(view[4], view[5], view[6]), Vector3.UP)
		cam.fov = float(view[7])
		cam.make_current()
		for i in range(6):
			await process_frame
		var image: Image = get_root().get_texture().get_image()
		var path: String = "%s/%s.png" % [OUT_DIR, view[0]]
		image.save_png(path)
		print("[survey] %s eye=(%.1f, %.1f, %.1f)" % [view[0], view[1], view[2], view[3]])

	print("SURVEY_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


## hud.gd re-shows itself on every Game.state_changed, so this is called
## after start_episode() as well as before the captures -- exactly the
## re-hide screenshot_route.gd's own _dispatch() does, for the same reason.
func _hide_canvas_layers(node: Node) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	for child in node.get_children():
		_hide_canvas_layers(child)
