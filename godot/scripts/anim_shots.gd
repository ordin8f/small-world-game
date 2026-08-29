extends SceneTree
## Animation contact sheet: renders every clip in a Kenney character .glb so
## a clip can be CHOSEN by looking at it rather than by guessing from its
## name. Built while wiring the interaction animations -- the Kenney names
## are terse ("interact-right", "holding-both") and several of them do not
## read the way the name suggests, so picking one blind is how you end up
## with an NPC whose "talk pose" was `wave`, a clip that does not exist in
## the pack at all.
##
## Same windowed-capture technique as scripts/verb_shots.gd (headless never
## renders a frame to grab), but it builds its own tiny stage -- camera,
## key light, ground card, one character -- instead of loading main.tscn:
## nothing here is about the world, only about the pose, and a neutral
## background makes silhouettes far easier to judge than a courtyard is.
##
## Emits two things: one contact sheet per page (a grid of every clip at one
## frame, for recognising what a clip IS) and, for the clips the game
## actually plays, a four-frame strip across the clip's length -- a single
## frame cannot show whether a clip reads as a motion, and two clips can look
## identical at their midpoint while being opposites (emote-yes and emote-no
## both pass through neutral halfway through).
##
## Must run WITHOUT --headless. Usage:
##   godot --path godot --script res://scripts/anim_shots.gd --resolution 1280x720

const GLB_PATH := "res://assets/kenney/character-male-a.glb"
const OUT_DIR := "user://anim_shots"
const CELL := 384          ## contact-sheet cell size, px
const GRID_COLUMNS := 4
const GRID_ROWS := 4       ## 16 clips per page; 32 clips -> 2 pages
const SETTLE_TICKS := 4    ## frames to let a seek propagate to the transforms

## The clips this game plays (or that were candidates for it). Rendered as
## time strips after the contact sheets.
const FEATURED := [
	"idle", "walk", "sprint", "sit", "crouch", "pick-up",
	"holding-both", "holding-right", "holding-left", "interact-right",
	"interact-left", "emote-yes", "emote-no", "attack-kick-right", "static",
	"drive", "jump",
]

## Where in each clip the contact sheet samples. Most of these poses peak
## mid-clip; the held poses are single-pose clips where any time works.
const SAMPLE_FRACTION := 0.5

## Time strip sample points, as fractions of clip length. Deliberately not
## 0.0/1.0: the first and last frames of these clips are usually the neutral
## pose the clip starts and returns to, which says nothing about the clip.
const STRIP_FRACTIONS := [0.12, 0.37, 0.62, 0.87]

var _anim: AnimationPlayer = null
var _model: Node3D = null
var _stage: Node3D = null
var _camera: Camera3D = null
var _ground: MeshInstance3D = null


func _initialize() -> void:
	_run()


func _run() -> void:
	_build_stage()
	# Measuring has to wait for a real frame: during _initialize() the root
	# Window is not yet inside the tree, so every global_transform read on a
	# freshly added child returns identity and the merged AABB comes back
	# empty (which silently framed the first version of this tool from
	# inside the character's head).
	await process_frame
	await process_frame
	_frame_camera()
	await process_frame

	if _anim == null:
		push_error("anim_shots: no AnimationPlayer found under %s" % GLB_PATH)
		quit(1)
		return

	var clips: Array = []
	for name in _anim.get_animation_list():
		clips.append(name)
	print("anim_shots: %d clips in %s" % [clips.size(), GLB_PATH])

	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var per_page := GRID_COLUMNS * GRID_ROWS
	var page := 0
	while page * per_page < clips.size():
		var slice: Array = clips.slice(page * per_page, mini((page + 1) * per_page, clips.size()))
		await _capture_sheet(slice, page + 1)
		page += 1

	for clip in FEATURED:
		if clips.has(clip):
			await _capture_strip(clip)

	print("SHOTS_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


## One PNG holding GRID_COLUMNS x GRID_ROWS clips, each downsampled into its
## own cell. Reading 32 separate files to compare poses is far worse than
## reading two sheets side by side.
func _capture_sheet(clips: Array, page_number: int) -> void:
	var sheet := Image.create(CELL * GRID_COLUMNS, CELL * GRID_ROWS, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.09, 0.10, 0.12))

	for i in range(clips.size()):
		var clip: String = clips[i]
		var frame := await _render_clip(clip, SAMPLE_FRACTION)
		if frame == null:
			continue
		frame.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
		if frame.get_format() != Image.FORMAT_RGBA8:
			frame.convert(Image.FORMAT_RGBA8)
		var col := i % GRID_COLUMNS
		var row := i / GRID_COLUMNS
		sheet.blit_rect(frame, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, row * CELL))

	var path := "%s/sheet_%d.png" % [OUT_DIR, page_number]
	var err := sheet.save_png(path)
	if err != OK:
		push_error("anim_shots: save_png(%s) failed: %d" % [path, err])
		return
	print("[sheet %d] %s -> %s" % [page_number, str(clips), ProjectSettings.globalize_path(path)])


## One clip, STRIP_FRACTIONS.size() frames left-to-right across its length --
## reads as a flipbook of the motion rather than a single ambiguous pose.
func _capture_strip(clip: String) -> void:
	var strip := Image.create(CELL * STRIP_FRACTIONS.size(), CELL, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0.09, 0.10, 0.12))
	for i in range(STRIP_FRACTIONS.size()):
		var frame := await _render_clip(clip, STRIP_FRACTIONS[i])
		if frame == null:
			continue
		frame.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
		if frame.get_format() != Image.FORMAT_RGBA8:
			frame.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(frame, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))

	var path := "%s/strip_%s.png" % [OUT_DIR, clip]
	var err := strip.save_png(path)
	if err != OK:
		push_error("anim_shots: save_png(%s) failed: %d" % [path, err])
		return
	print("[strip] %s -> %s" % [clip, ProjectSettings.globalize_path(path)])


## Seeks rather than plays: a screenshot of a running clip lands wherever the
## frame timing happens to put it, which is not reproducible between runs.
## seek(t, true) forces the transforms to the sampled time immediately.
func _render_clip(clip: String, fraction: float) -> Image:
	if not _anim.has_animation(clip):
		push_warning("anim_shots: no such clip %s" % clip)
		return null
	var length := _anim.get_animation(clip).length
	_anim.play(clip)
	_anim.seek(length * fraction, true)
	_anim.pause()
	for _i in range(SETTLE_TICKS):
		await process_frame
	var img: Image = get_root().get_texture().get_image()
	if img == null or img.is_empty():
		push_error("anim_shots: %s produced no image" % clip)
		return null
	# Square crop about the centre so contact-sheet cells aren't squashed by
	# the 16:9 viewport.
	var side: int = mini(img.get_width(), img.get_height())
	var x := (img.get_width() - side) / 2
	var y := (img.get_height() - side) / 2
	return img.get_region(Rect2i(x, y, side, side))


## A neutral three-quarter stage: key light from camera-left so limb
## separation reads, a flat card behind so the silhouette does, and a warm
## fill so the shadow side isn't black.
func _build_stage() -> void:
	_stage = Node3D.new()
	get_root().add_child(_stage)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.18, 0.22)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.66)
	e.ambient_light_energy = 0.55
	env.environment = e
	_stage.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32.0, 38.0, 0.0)
	key.light_energy = 1.5
	_stage.add_child(key)

	var packed: PackedScene = load(GLB_PATH)
	_model = packed.instantiate()
	_stage.add_child(_model)
	_anim = _find_animation_player(_model)

	# Ground card, so a crouch/sit reads as being ON something rather than
	# floating in a void. Sized/placed in _frame_camera() once the model can
	# actually be measured.
	var plane := PlaneMesh.new()
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.30, 0.32, 0.35)
	ground_mat.roughness = 1.0
	plane.surface_set_material(0, ground_mat)
	_ground = MeshInstance3D.new()
	_ground.mesh = plane
	_stage.add_child(_ground)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_stage.add_child(_camera)
	_camera.current = true


## Three-quarter front view, framed off the model's real measured height:
## far enough back that a kick, a lie-down or a sit stays fully in frame
## (the poses that blow the framing are the wide ones, not the standing
## ones), angled 40 degrees off front so both arms are visible -- a dead-on
## front view hides whichever arm is behind the torso, which is exactly the
## thing being judged here.
func _frame_camera() -> void:
	var aabb := _merged_aabb(_model)
	var height: float = maxf(aabb.size.y, 0.001)
	var centre: Vector3 = aabb.position + aabb.size * 0.5
	print("anim_shots: model height %.3f, centre (%.2f, %.2f, %.2f)" % [height, centre.x, centre.y, centre.z])

	(_ground.mesh as PlaneMesh).size = Vector2(height * 10.0, height * 10.0)
	_ground.position.y = aabb.position.y

	# Aim below centre: a sit/crouch/lie-down drops well under the standing
	# centre, and cropping the feet off a crouch is the one thing that would
	# make this tool useless for judging a crouch.
	var aim := Vector3(centre.x, aabb.position.y + height * 0.42, centre.z)
	var dist := height * 2.55
	_camera.position = aim + Vector3(dist * 0.64, height * 0.30, dist * 0.77)
	_camera.look_at_from_position(_camera.position, aim, Vector3.UP)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _merged_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for mesh_instance in _find_all_mesh_instances(node):
		var global_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if first:
			result = global_aabb
			first = false
		else:
			result = result.merge(global_aabb)
	return result


func _find_all_mesh_instances(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	return result
