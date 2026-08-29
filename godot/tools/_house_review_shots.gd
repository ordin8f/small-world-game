extends SceneTree
## Throwaway art-review tool (not part of the deliverable, delete after
## use): the real gameplay camera (camera_rig.gd) always looks AWAY from
## home in this zone -- by design, it chases "forward" -- so it can never
## actually frame the house head-on. This spawns a free, independent
## Camera3D (no gameplay logic at all) at a few fixed points facing the
## house and the garden bed, purely so a human/agent can *look at* the new
## geometry from angles the play camera structurally cannot reach.

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://house_review"

var _runner: GdUnitSceneRunner = null
var _main: Node = null
var _cam: Camera3D = null


func _initialize() -> void:
	_run()


func _run() -> void:
	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)
	_main = _runner.scene()

	_hide_ui_layers()

	_cam = Camera3D.new()
	_cam.fov = 60.0
	get_root().add_child(_cam)
	_cam.current = true

	for _i in range(10):
		await physics_frame

	# 1. Approach: standing where the player starts, looking straight at
	# the house through the doorway.
	_cam.global_position = Vector3(0.0, 1.3, 10.0)
	_cam.look_at(Vector3(0.0, 1.6, 20.0), Vector3.UP)
	await _settle_and_capture("house_from_approach")

	# 2. High above, looking down the passage -- roof/chimney massing.
	_cam.global_position = Vector3(0.0, 9.0, 6.0)
	_cam.look_at(Vector3(0.0, 0.0, 19.0), Vector3.UP)
	await _settle_and_capture("house_overhead")

	# 3. The garden bed edging, from the path, at child eye height.
	_cam.global_position = Vector3(-1.5, 1.3, 12.6)
	_cam.look_at(Vector3(-4.9, 0.4, 12.0), Vector3.UP)
	await _settle_and_capture("garden_edging_from_path")

	print("SHOTS_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _hide_ui_layers() -> void:
	_hide_recursive(_main)


func _hide_recursive(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child in node.get_children():
		_hide_recursive(child)


func _settle_and_capture(beat_name: String) -> void:
	for _i in range(20):
		await physics_frame
	var img: Image = get_root().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var rel_path := "%s/%s.png" % [OUT_DIR, beat_name]
	img.save_png(rel_path)
	print("%s -> %s" % [beat_name, ProjectSettings.globalize_path(rel_path)])
