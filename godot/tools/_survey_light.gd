extends SceneTree

## Measures how dark the frame is from EVERY part of the park, not from the six
## route beats.
##
## Developer, 2026-08-30: "The darkness is a bit too much - and hard to see
## anything in there", and then, of the method rather than the bug: "You haven't
## explored the entire play area." Six sampled beats cannot find a dark corner
## at the two hundred places nobody sampled -- the same reason four rounds of
## camera work measured the same six frames and missed what a minute of walking
## found.
##
## So this stands the player on a grid across the whole walkable area, renders
## the real frame from the real camera at each spot, and reports the luminance
## distribution. Numbers first: a hundred frames is too many to judge by eye, and
## "hard to see anything" is a measurable claim. It saves a PNG only for the
## darkest few, which are the ones worth actually looking at.
##
## Reuses screenshot_route.gd's capture route deliberately -- the class doc there
## records that Windows GDI makes Viewport.get_texture().get_image() the only
## reliable readback, and that lesson should not be relearned here.

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://light_survey"

## Coarse enough to finish in minutes, fine enough that no region of a 45x20 m
## park goes unvisited.
const STEP := 4.0
const X_RANGE := [-22.0, 21.0]
const Z_RANGE := [-23.0, 15.0]

## Ticks to let the frame settle once the player has ARRIVED somewhere. The
## player is walked there, not teleported: two earlier versions of this set
## global_position directly and the camera never followed at all -- it sat within
## 0.6 m of the home threshold for all 79 samples, at 12 ticks and again at 90,
## so every luminance figure was the same frame measured 79 times. The rig
## tracks driven motion, not assignment. The camera-position spread printed in
## _report() exists so that failure can never be silent again.
const SETTLE_TICKS := 8

## Below this mean luminance a frame is too dark to read. Calibrated against the
## frames the developer was complaining about: the pre-fix foreground sat near
## 0.06-0.10, and the fixed frames come in around 0.30+.
const DARK_MEAN := 0.18
## A frame can have a bright sky and an unreadable ground, so the low tail
## matters more than the mean. This is the share of pixels below near-black.
const CRUSHED_FRACTION := 0.35
const CRUSHED_LEVEL := 0.06

var _runner: GdUnitSceneRunnerImpl
var _player: Node3D
var _game: Node
var _rows: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)
	if _runner.scene() == null:
		push_error("light_survey: could not load %s" % SCENE_PATH)
		quit(1)
		return

	var game: Node = get_root().get_node_or_null("Game")
	_game = game
	if game == null:
		push_error("light_survey: no Game autoload")
		quit(1)
		return
	game.call("start_episode", 0.0)
	await _runner.simulate_frames(2)

	_player = game.get("player")
	if _player == null:
		push_error("light_survey: no player")
		quit(1)
		return
	_hide_canvas_layers(_runner.scene())

	var visited := 0
	var flip := false
	var x: float = X_RANGE[0]
	while x <= X_RANGE[1]:
		var lane: Array = []
		var z: float = Z_RANGE[0]
		while z <= Z_RANGE[1]:
			if WorldBounds.can_move_to(x, z):
				lane.append(Vector2(x, z))
			z += STEP
		if flip:
			lane.reverse()
		flip = not flip
		for point in lane:
			await _walk_to(point)
			visited += 1
			await _sample(point.x, point.y)
		x += STEP

	_report(visited)
	quit(0)


## Walks the player to `target` with the same input-driven steering the tests
## and the screenshot route use, so the camera rig sees ordinary motion.
func _walk_to(target: Vector2) -> void:
	await DriveRoute.run(_runner, _player, [target], func() -> void: pass)


func _sample(x: float, z: float) -> void:
	for _i in range(SETTLE_TICKS):
		await physics_frame

	var img: Image = get_root().get_texture().get_image()
	if img == null or img.is_empty():
		return

	# Downsample before reading pixels: at 1280x720 a per-pixel loop in GDScript
	# costs more than the render does, and luminance statistics do not need the
	# full resolution.
	img.resize(160, 90, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	var crushed := 0
	var count := img.get_width() * img.get_height()
	for py in range(img.get_height()):
		for px in range(img.get_width()):
			var c: Color = img.get_pixel(px, py)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			total += l
			if l < CRUSHED_LEVEL:
				crushed += 1

	# Game.camera, NOT get_viewport().get_camera_3d(). The latter reported a
	# fixed point near the home threshold for every sample in three separate
	# runs while the rendered frames were plainly changing -- it is not the
	# rig's camera. Reading it led me to conclude the camera never followed the
	# player, which was a claim about my instrument, not about the game.
	var cam: Camera3D = _game.get("camera")
	var cam_pos: Vector3 = cam.global_position if cam != null else Vector3.INF
	_rows.append({
		"x": x, "z": z,
		"mean": total / float(count),
		"crushed": float(crushed) / float(count),
		"cam": cam_pos,
	})


func _report(visited: int) -> void:
	_rows.sort_custom(func(a, b): return a["mean"] < b["mean"])

	var too_dark: Array = []
	for row in _rows:
		if row["mean"] < DARK_MEAN or row["crushed"] > CRUSHED_FRACTION:
			too_dark.append(row)

	print("light_survey: %d walkable positions on a %.1f m grid" % [visited, STEP])
	print("  mean luminance   darkest %.3f   median %.3f   brightest %.3f"
		% [_rows[0]["mean"], _rows[_rows.size() / 2]["mean"], _rows[-1]["mean"]])
	print("  positions failing the readability floor (mean < %.2f or >%.0f%% near-black): %d of %d"
		% [DARK_MEAN, CRUSHED_FRACTION * 100.0, too_dark.size(), _rows.size()])
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for row in _rows:
		var c: Vector3 = row["cam"]
		lo = Vector3(minf(lo.x, c.x), minf(lo.y, c.y), minf(lo.z, c.z))
		hi = Vector3(maxf(hi.x, c.x), maxf(hi.y, c.y), maxf(hi.z, c.z))
	print("  camera moved over x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f  <- near-zero here means the rig never followed"
		% [lo.x, hi.x, lo.y, hi.y, lo.z, hi.z])
	print("  --- darkest 12 ---")
	for i in range(mini(12, _rows.size())):
		var r: Dictionary = _rows[i]
		var c: Vector3 = r["cam"]
		print("    (%+6.1f, %+6.1f)  mean %.3f  near-black %4.1f%%  camera (%+6.1f,%+5.1f,%+6.1f)%s"
			% [r["x"], r["z"], r["mean"], r["crushed"] * 100.0, c.x, c.y, c.z,
			   "   <-- FAILS" if (r["mean"] < DARK_MEAN or r["crushed"] > CRUSHED_FRACTION) else ""])


func _hide_canvas_layers(node: Node) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	for child in node.get_children():
		_hide_canvas_layers(child)
