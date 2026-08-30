extends SceneTree
## Whole-world camera sweep -- every place the player can actually stand,
## not a handful of authored beats.
##
##   godot --headless --path godot --script res://tools/_probe_camera_sweep.gd
##   ... -- --drive-only        (skip the teleport grid, just drive)
##   ... -- --sweep-only        (skip the drive)
##   ... -- --at 12.0 -8.0      (one cell, verbose, for chasing a single fault)
##
## WHY THIS EXISTS. Four prior rounds of camera work measured the same six
## static screenshot beats and closed with the developer still finding
## faults by walking around. Six points cannot find a fault that lives at
## the two hundred places nobody sampled. This floods the walkable plane on
## the same ~0.5 m grid tools/_probe_reachability.gd uses (real physics
## world, the player's real capsule) and drives the REAL camera rig at every
## cell -- scripts/camera_rig.gd and scripts/logic/camera_profile.gd are
## instantiated and stepped, never reimplemented, so a fix to either shows
## up here without touching this file.
##
## Settled state, not a transient: before each cell the rig's own
## `_initialized` flag is cleared, which makes camera_rig.gd snap
## `_smoothed_desired` onto `desired` on the next physics tick instead of
## damping toward it. That is exactly the state a player who stops walking
## converges to (the regime test_camera_never_in_geometry.gd's own
## garden-gap test was added for), reached in two ticks instead of ninety.
##
## The metrics, and why each one is here:
##   occluded  -- is the child actually VISIBLE from the camera? Cast
##                camera->body on layers 1 AND 2. The shipped test only
##                casts on layer 2 (camera_blocks walls), which is a
##                "camera is not inside a wall" check; every tree trunk,
##                playground tower, bench and staircase in this world is
##                layer 1 only, so a camera standing behind one passes that
##                test with the child completely hidden.
##   vis-occl  -- same question against RENDER geometry (AABBs), which
##                catches the slide, the plank, the swing and the arch --
##                visual-only props with no collider at all. Worst case by
##                construction (an AABB is a canopy's full width).
##   near%     -- share of the picture taken by geometry within 6 m, the
##                same 64x36-style ray grid _probe_reachability.gd already
##                uses, at 32x18 so it can run 2600 times.
##   angle     -- degrees off dead-behind, the shipped test's own metric.
##   dist      -- camera<->player separation, and its ratio to the zone's
##                authored distance.
##   pitch     -- degrees below horizontal, plus the share of the frame
##                aimed under the horizon: a camera staring at the dirt and
##                a camera staring at the sky are both faults, and nothing
##                in this repo has ever measured either.
##   in frame  -- are all three body samples inside the camera frustum?
##                A shot can be a perfect distance and angle and still have
##                walked the child off the edge of the picture; nothing in
##                this repo had ever asked, and the answer was "no" at 306
##                of the 3610 positions.
##   clearance -- distance from the camera to the nearest camera-blocking
##                wall. Neither distance nor occlusion can see a camera
##                sitting 0.1 m to one side of a wall: it is not inside
##                anything, it is a fine distance from the child, and half
##                the picture is wall.
##   jump      -- the big one. How far the camera moves for a 0.5 m step in
##                player position, compared with its 4-neighbours. A camera
##                that snaps as you cross a line is far more noticeable in
##                play than one that is merely badly placed, and a
##                beat-sampled test cannot see it at all.
##
## Run `--drive-only` for the second half alone: a genuine continuous walk
## through every region with real simulated input. Teleport sampling and
## driven motion find different bugs -- the settled grid cannot see damping
## lag, and the drive cannot visit 3610 places.

const SCENE_PATH := "res://scenes/main.tscn"

# --- grid (same origin/extent as tools/_probe_reachability.gd) -------------
## 0.5 m is the reported figure. `--step 1.0` quarters the cell count for
## A/B iteration; it finds the same faults in the same places, it just
## resolves their edges more coarsely, so every number this task REPORTS
## comes from a 0.5 m run.
const X_MIN := -25.0
const Z_MIN := -26.0
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var STEP := 0.5
var X_CELLS := 101
var Z_CELLS := 89

# --- measurement constants -------------------------------------------------
## Feet / chest / head. One head ray alone calls a camera "clear" when the
## child is visible from the neck up behind a bench.
const BODY_SAMPLES := [0.25, 0.85, 1.45]
const HEAD_HEIGHT := 1.5
## Anything closer than this is "in your face" rather than "in the scene"
## (_probe_reachability.gd's own NEAR_M).
const NEAR_M := 6.0
const FRAME_COLS := 32
const FRAME_ROWS := 18
const ASPECT := 1280.0 / 720.0
## Coarse XZ buckets for near-geometry lookup -- without this the 2600-cell
## sweep is O(cells * every mesh in the world) and takes minutes.
const BUCKET := 8.0

# --- thresholds used only to COUNT faults in the summary -------------------
const ANGLE_LIMIT := 35.0
const RATIO_FLOOR := 0.35
const NEAR_LIMIT := 30.0
const JUMP_LIMIT := 1.5   # metres of camera travel per 0.5 m player step

var _runner: GdUnitSceneRunner = null
var _main: Node = null
var _game: Node = null
var _player: Node3D = null
var _camera: Camera3D = null
var _rig: Node3D = null
var _arm: SpringArm3D = null

var _space: PhysicsDirectSpaceState3D
var _shape_params: PhysicsShapeQueryParameters3D
var _capsule_y := 0.54
var _exclude: Array = []

var _boxes: Array = []          # [{name, box}]
var _buckets := {}              # Vector2i -> Array[int] (indices into _boxes)
var _labels := {}               # collider RID -> readable name

## Per sampled cell: a Dictionary of every metric. `_slot` maps grid index
## -> position in this array so the neighbour pass can find them.
var _cells: Array = []
var _slot := {}

var _do_sweep := true
var _do_drive := true
## --fast drops the 32x18 frame-occupancy ray grid, which is ~85% of the
## sweep's runtime. Everything that decides a re-tune (occlusion, distance,
## angle, pitch, in-frame, discontinuity) is unaffected, so A/B runs use it
## and the reported before/after tables do not.
var _fast := false
var _single := Vector2(INF, INF)


func _initialize() -> void:
	await _run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--drive-only"):
		_do_sweep = false
	if args.has("--sweep-only"):
		_do_drive = false
	if args.has("--fast"):
		_fast = true
	var step_arg := args.find("--step")
	if step_arg >= 0 and args.size() > step_arg + 1:
		STEP = float(args[step_arg + 1])
		X_CELLS = int(round(50.0 / STEP)) + 1   # x[-25, 25]
		Z_CELLS = int(round(44.0 / STEP)) + 1   # z[-26, 18]
	var at := args.find("--at")
	if at >= 0 and args.size() > at + 2:
		_single = Vector2(float(args[at + 1]), float(args[at + 2]))
		_do_drive = false

	# Instantiated + added ourselves (never change_scene_to_file), exactly
	# as scripts/screenshot_route.gd does and for the same reason: a second
	# competing copy of main.tscn would fight over Game.player/camera.
	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)
	_main = _runner.scene()
	if _main == null:
		printerr("FATAL: could not instantiate %s" % SCENE_PATH)
		quit(1)
		return

	# `Game` by get_node(), never as a bare identifier -- a --script entry
	# point compiles before the autoload globals are registered for the
	# static analyzer (screenshot_route.gd's own doc comment).
	_game = get_root().get_node("Game")
	_player = _game.get("player")
	_camera = _game.get("camera")
	if _player == null or _camera == null:
		printerr("FATAL: Game.player/Game.camera not set after two frames.")
		quit(1)
		return
	_arm = _camera.get_parent() as SpringArm3D
	_rig = _arm.get_parent() as Node3D

	_space = _player.get_world_3d().direct_space_state
	_exclude = [_player.get_rid()]
	_collect_boxes(_main)
	_label_colliders(_main)
	_prepare_shape_query()

	print("camera rig: %s  arm margin %.2f  arm mask %d  camera fov %.1f" % [
		_rig.get_script().resource_path, _arm.margin, _arm.collision_mask, _camera.fov,
	])
	print("render boxes collected: %d (bucketed into %d cells of %.0f m)" % [
		_boxes.size(), _buckets.size(), BUCKET,
	])

	if _single.x != INF:
		await _report_single(_single.x, _single.y)
		_shutdown(0)
		return

	if _do_sweep:
		var dist := await _flood()
		await _sweep(dist)
		_report_coverage()
		_report_regions()
		_report_distributions()
		_report_worst()
		_neighbour_pass()
	if _do_drive:
		await _drive()
	_shutdown(0)


## quit() with the GdUnitSceneRunner still referenced segfaults on exit --
## scripts/screenshot_route.gd's own _shutdown() has the full diagnosis
## (GdUnitSceneRunnerImpl's PREDELETE frees the scene a second time after
## the tree teardown already did). Dropping BOTH references (the local and
## the Engine meta the constructor sets) runs that cleanup while the tree
## is still alive. This probe reproduced the same crash before adopting it.
func _shutdown(code: int) -> void:
	_runner = null
	Engine.remove_meta("GdUnitSceneRunner")
	quit(code)


# ---------------------------------------------------------------- geometry --

func _prepare_shape_query() -> void:
	var capsule: CapsuleShape3D = null
	for child in _player.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			capsule = (child.shape as CapsuleShape3D).duplicate()
			_capsule_y = child.position.y
			break
	if capsule == null:
		printerr("FATAL: no CapsuleShape3D under the live player.")
		quit(1)
		return
	print("player capsule (read off the live player): radius=%.3f height=%.3f shape_y=%.3f" % [
		capsule.radius, capsule.height, _capsule_y,
	])
	_shape_params = PhysicsShapeQueryParameters3D.new()
	_shape_params.shape = capsule
	_shape_params.collision_mask = 1
	_shape_params.collide_with_areas = false
	_shape_params.collide_with_bodies = true
	_shape_params.exclude = _exclude


## Every rendered box in the world, bucketed by XZ so a near-geometry query
## touches a handful instead of all of them. Same collection rule as
## _probe_reachability.gd's _collect_occluders: no name or type heuristics.
func _collect_boxes(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is GeometryInstance3D):
			continue
		var local: AABB = (node as GeometryInstance3D).get_aabb()
		if local.size == Vector3.ZERO:
			continue
		var box: AABB = (node as GeometryInstance3D).global_transform * local
		# The player's own body must not count as something between the
		# camera and the player.
		if _player.is_ancestor_of(node) or node == _player:
			continue
		_boxes.append({"name": str(node.name), "box": box})

	for i in range(_boxes.size()):
		var box: AABB = _boxes[i]["box"]
		var x0 := int(floor(box.position.x / BUCKET))
		var x1 := int(floor(box.end.x / BUCKET))
		var z0 := int(floor(box.position.z / BUCKET))
		var z1 := int(floor(box.end.z / BUCKET))
		for bx in range(x0, x1 + 1):
			for bz in range(z0, z1 + 1):
				var key := Vector2i(bx, bz)
				if not _buckets.has(key):
					_buckets[key] = PackedInt32Array()
				_buckets[key].append(i)


## Readable names for physics hits. WallColliders' children are generated
## from WorldBounds.COLLIDERS in order (tools/_bootstrap_courtyard.gd's
## _add_wall_colliders), so index i names entry i -- a hit reported as
## "wall#31 (9.5,1.3 half 1.5x1.3 cam)" is traceable straight back to the
## line of world_bounds.gd that put it there.
func _label_colliders(root: Node) -> void:
	var walls := _find_named(root, "WallColliders")
	if walls == null:
		printerr("WARNING: no WallColliders node found -- hits will be unlabelled.")
		return
	var kids := walls.get_children()
	for i in range(kids.size()):
		var body := kids[i] as StaticBody3D
		if body == null:
			continue
		var label := "wall#%d" % i
		if i < WorldBounds.COLLIDERS.size():
			var b: Dictionary = WorldBounds.COLLIDERS[i]
			label = "wall#%d(%.1f,%.1f h%.1fx%.1f%s)" % [
				i, b["x"], b["z"], b["half_x"], b["half_z"],
				" CAM" if b.get("camera_blocks", false) else "",
			]
		_labels[body.get_rid()] = label


func _find_named(node: Node, name_wanted: String) -> Node:
	if str(node.name) == name_wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, name_wanted)
		if found != null:
			return found
	return null


func _index(cell: Vector2i) -> int:
	return cell.y * X_CELLS + cell.x


func _cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(round((x - X_MIN) / STEP)), int(round((z - Z_MIN) / STEP)))


func _world_of(cell: Vector2i) -> Vector2:
	return Vector2(X_MIN + cell.x * STEP, Z_MIN + cell.y * STEP)


## Reachability flood -- copied in method (not in code) from
## _probe_reachability.gd: every step confirmed with a SWEPT capsule cast,
## because two free cells 0.5 m apart can still have a wall corner between
## them.
func _flood() -> PackedInt32Array:
	var free := PackedByteArray()
	free.resize(X_CELLS * Z_CELLS)
	for zi in range(Z_CELLS):
		for xi in range(X_CELLS):
			var p := _world_of(Vector2i(xi, zi))
			_shape_params.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, _capsule_y, p.y))
			_shape_params.motion = Vector3.ZERO
			free[zi * X_CELLS + xi] = 1 if _space.intersect_shape(_shape_params, 1).is_empty() else 0

	var dist := PackedInt32Array()
	dist.resize(X_CELLS * Z_CELLS)
	dist.fill(-1)
	var start := _cell_of(0.0, 10.0)
	if free[_index(start)] == 0:
		printerr("FATAL: spawn cell (0,10) is blocked.")
		quit(1)
		return dist
	dist[_index(start)] = 0
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var here := _world_of(cell)
		for delta in NEIGHBORS:
			var next: Vector2i = cell + delta
			if next.x < 0 or next.x >= X_CELLS or next.y < 0 or next.y >= Z_CELLS:
				continue
			var ni := _index(next)
			if dist[ni] != -1 or free[ni] == 0:
				continue
			_shape_params.transform = Transform3D(Basis.IDENTITY, Vector3(here.x, _capsule_y, here.y))
			_shape_params.motion = Vector3(delta.x * STEP, 0.0, delta.y * STEP)
			var cast: PackedFloat32Array = _space.cast_motion(_shape_params)
			if cast.size() < 1 or cast[0] < 0.999:
				continue
			dist[ni] = dist[_index(cell)] + 1
			queue.append(next)
	return dist


# ------------------------------------------------------------------- sweep --

## Park the player at (x,z) and let the REAL rig settle onto it. Clearing
## camera_rig.gd's `_initialized` makes it snap rather than damp, so two
## physics ticks reach the same place ninety would.
func _settle_at(x: float, z: float) -> void:
	_player.set("external_control", true)   # player.gd: no input, no move_and_slide, no verbs
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(x, _player.get("locked_y"), z)
	_rig.set("_initialized", false)
	await physics_frame
	await physics_frame


func _sweep(dist: PackedInt32Array) -> void:
	var total := 0
	for i in range(dist.size()):
		if dist[i] >= 0:
			total += 1
	print("")
	print("sweeping %d reachable cells (%.0f m^2 at %.2f m spacing)..." % [
		total, total * STEP * STEP, STEP,
	])
	var started := Time.get_ticks_msec()
	var done := 0
	for i in range(dist.size()):
		if dist[i] < 0:
			continue
		var cell := Vector2i(i % X_CELLS, i / X_CELLS)
		var p := _world_of(cell)
		await _settle_at(p.x, p.y)
		var m := _measure()
		m["cell"] = cell
		m["index"] = i
		_slot[i] = _cells.size()
		_cells.append(m)
		done += 1
		if done % 400 == 0:
			print("  %d/%d cells (%.1f s)" % [done, total, (Time.get_ticks_msec() - started) / 1000.0])
	print("  swept %d cells in %.1f s" % [done, (Time.get_ticks_msec() - started) / 1000.0])


## Everything measured at the player's CURRENT settled position.
func _measure() -> Dictionary:
	var p := _player.global_position
	var eye := _camera.global_position
	var profile: Dictionary = CameraProfile.profile(p.z)
	var authored: float = profile["distance"]
	var basis := _camera.global_transform.basis
	var forward := -basis.z

	var offset := Vector2(eye.x - p.x, eye.z - p.z)
	var back := Vector2(sin(profile["authored_yaw"]), cos(profile["authored_yaw"]))
	var angle := 0.0
	if offset.length() > 0.05:
		angle = absf(rad_to_deg(back.angle_to(offset)))

	# --- occlusion: is the child actually visible from here? ---------------
	var blocked := 0
	var blocker := ""
	for h in BODY_SAMPLES:
		var target := p + Vector3(0.0, h, 0.0)
		var q := PhysicsRayQueryParameters3D.create(eye, target)
		q.exclude = _exclude
		q.collision_mask = 3     # movement AND camera layers: trunks, towers, bench, walls
		var hit := _space.intersect_ray(q)
		if not hit.is_empty():
			blocked += 1
			if blocker == "":
				blocker = _labels.get(hit["rid"], str(hit["collider"].name))
	# The shipped test's own question, kept separate: layer 2 only.
	var wall_hit := false
	var head := p + Vector3(0.0, HEAD_HEIGHT, 0.0)
	var wq := PhysicsRayQueryParameters3D.create(head, eye)
	wq.exclude = _exclude
	wq.collision_mask = 2
	wall_hit = not _space.intersect_ray(wq).is_empty()

	# Radius is the camera<->player span, not a fixed number: a box further
	# from the camera than the child is cannot be between them.
	var candidates := PackedInt32Array() if _fast else _candidates(eye, eye.distance_to(p) + 1.0)
	var vis_blocked := 0
	var vis_name := ""
	for h in BODY_SAMPLES:
		var target := p + Vector3(0.0, h, 0.0)
		var who := _segment_blocker(eye, target, candidates)
		if who != "":
			vis_blocked += 1
			if vis_name == "":
				vis_name = who

	# --- what fills the frame, and where the frame is pointed -------------
	var near_pool := PackedInt32Array() if _fast else _candidates(eye, NEAR_M)
	var half_v: float = tan(deg_to_rad(float(profile["fov"]) * 0.5))
	var half_h: float = half_v * ASPECT
	var right := basis.x
	var up := basis.y
	var near_hits := 0
	var standing_hits := 0
	var below := 0
	var shares := {}
	for row in range(FRAME_ROWS):
		var v: float = (2.0 * (row + 0.5) / FRAME_ROWS - 1.0) * half_v
		for col in range(FRAME_COLS):
			var h2: float = (2.0 * (col + 0.5) / FRAME_COLS - 1.0) * half_h
			var dir := (forward + right * h2 + up * v).normalized()
			if dir.y < 0.0:
				below += 1
			var best := INF
			var who := ""
			var who_is_ground := true
			for bi in near_pool:
				var b: AABB = _boxes[bi]["box"]
				if b.has_point(eye):
					continue
				var res = b.intersects_ray(eye, dir)
				if res == null:
					continue
				var t: float = (res as Vector3).distance_to(eye)
				if t < best:
					best = t
					who = _boxes[bi]["name"]
					who_is_ground = _is_ground_slab(b)
			if best <= NEAR_M:
				near_hits += 1
				# The floor is always in shot and is not "something in the
				# way" -- `standing` is the share taken by geometry that
				# actually stands up off the ground.
				if not who_is_ground:
					standing_hits += 1
					shares[who] = shares.get(who, 0) + 1
	var frame_total := FRAME_COLS * FRAME_ROWS
	var top_name := ""
	var top_share := 0.0
	for key in shares:
		var pct := 100.0 * float(shares[key]) / frame_total
		if pct > top_share:
			top_share = pct
			top_name = key

	# Is the child even in shot? A camera can sit at a perfect distance and
	# angle and still have walked the player out of the frame; nothing in
	# this repo has ever asked.
	var in_frame := 0
	for h in BODY_SAMPLES:
		if _camera.is_position_in_frustum(p + Vector3(0.0, h, 0.0)):
			in_frame += 1

	return {
		"px": p.x, "pz": p.z,
		"cx": eye.x, "cy": eye.y, "cz": eye.z,
		"yaw": atan2(-forward.x, -forward.z),
		"pitch": rad_to_deg(asin(clampf(-forward.y, -1.0, 1.0))),
		"below": 100.0 * below / frame_total,
		"dist": eye.distance_to(p),
		"authored": authored,
		"ratio": eye.distance_to(p) / authored,
		"angle": angle,
		"blocked": blocked,
		"blocker": blocker,
		# A collider hit ALONE overstates: every layer-1 box in this world
		# is a uniform 2.4 m tall regardless of what it renders as, so the
		# 0.9 m bench and the open staircase both "block" a sightline that
		# in the running game passes straight over them. A render-AABB hit
		# alone understates the other way (a tree's AABB is its whole crown).
		# The AND of the two is the defensible number: something that is
		# both solid and actually drawn stands between camera and child.
		"hidden": 1 if (blocked > 0 and vis_blocked > 0) else 0,
		"wall_hit": wall_hit,
		"vis_blocked": vis_blocked,
		"vis_name": vis_name,
		"near": 100.0 * near_hits / frame_total,
		"standing": 100.0 * standing_hits / frame_total,
		"top_near": top_share,
		"top_name": top_name,
		"in_frame": in_frame,
		"arm_want": _arm.spring_length,
		"arm_got": _arm.get_hit_length(),
		"clear": _wall_clearance(eye),
	}


## Distance from the camera to the nearest camera-blocking wall. Neither
## the distance nor the occlusion metric can see this fault: a camera 0.1 m
## to one side of a 5 m wall is not inside anything and is a perfectly good
## distance from the child, and half the picture is still wall. Measured
## against WorldBounds.COLLIDERS' own boxes (camera_blocks only), which are
## the exact boxes tools/_bootstrap_courtyard.gd builds the layer-2 bodies
## from.
func _wall_clearance(eye: Vector3) -> float:
	var best := INF
	for box in WorldBounds.COLLIDERS:
		if not box.get("camera_blocks", false):
			continue
		var dx: float = maxf(absf(eye.x - box["x"]) - box["half_x"], 0.0)
		var dz: float = maxf(absf(eye.z - box["z"]) - box["half_z"], 0.0)
		# Every camera_blocks body is 5 m tall standing on the ground, so a
		# camera under 5 m gets no vertical relief.
		var dy: float = maxf(eye.y - 5.0, 0.0)
		best = minf(best, sqrt(dx * dx + dy * dy + dz * dz))
	return best


## A flat slab lying on the ground -- paving, lawn, a chalk circle. Same
## rule _probe_reachability.gd's ground census uses (top under 0.4 m); the
## thickness test keeps a low wall or a bench seat out of it.
func _is_ground_slab(box: AABB) -> bool:
	return box.size.y < 0.5 and box.end.y < 0.6


## Indices of render boxes whose AABB comes within `radius` of `origin`.
func _candidates(origin: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := {}
	var reach := int(ceil(radius / BUCKET))
	var bx := int(floor(origin.x / BUCKET))
	var bz := int(floor(origin.z / BUCKET))
	for ix in range(bx - reach, bx + reach + 1):
		for iz in range(bz - reach, bz + reach + 1):
			var key := Vector2i(ix, iz)
			if not _buckets.has(key):
				continue
			for i in _buckets[key]:
				if seen.has(i):
					continue
				seen[i] = true
				var b: AABB = _boxes[i]["box"]
				var dx := maxf(maxf(b.position.x - origin.x, origin.x - b.end.x), 0.0)
				var dy := maxf(maxf(b.position.y - origin.y, origin.y - b.end.y), 0.0)
				var dz := maxf(maxf(b.position.z - origin.z, origin.z - b.end.z), 0.0)
				if dx * dx + dy * dy + dz * dz <= radius * radius:
					out.append(i)
	return out


## Name of the first render box strictly between `from` and `to`, or "".
## Boxes containing either endpoint are skipped -- you are not blocked by
## the canopy you are standing under, nor by the arch the camera sits in.
func _segment_blocker(from: Vector3, to: Vector3, pool: PackedInt32Array) -> String:
	var span := from.distance_to(to)
	if span < 1e-4:
		return ""
	var dir := (to - from) / span
	for i in pool:
		var b: AABB = _boxes[i]["box"]
		if b.has_point(from) or b.has_point(to):
			continue
		var res = b.intersects_ray(from, dir)
		if res == null:
			continue
		var t: float = (res as Vector3).distance_to(from)
		if t > 0.02 and t < span - 0.02:
			return _boxes[i]["name"]
	return ""


# ------------------------------------------------------------------ report --

func _report_coverage() -> void:
	var occluded := 0
	var real := 0
	var vis := 0
	var wall := 0
	var out_of_frame := 0
	for m in _cells:
		if m["blocked"] > 0:
			occluded += 1
		real += int(m["hidden"])
		if m["vis_blocked"] > 0:
			vis += 1
		if m["wall_hit"]:
			wall += 1
		if m["in_frame"] < 3:
			out_of_frame += 1
	# HARNESS SANITY, PRINTED FIRST AND ON PURPOSE. A sweep whose camera
	# never moves produces a beautifully uniform table of the same frame
	# measured 3610 times, and nothing else in this report would show it.
	# Read this line before trusting a single number below: the camera's
	# own travel must be comparable to the world's own size. (The camera
	# to ask is Game.camera, the rig's own -- get_viewport().get_camera_3d()
	# reports a fixed point near the home threshold whatever the game does,
	# which is exactly how a dead sweep looks alive.)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for m in _cells:
		var eye := Vector3(m["cx"], m["cy"], m["cz"])
		lo = Vector3(minf(lo.x, eye.x), minf(lo.y, eye.y), minf(lo.z, eye.z))
		hi = Vector3(maxf(hi.x, eye.x), maxf(hi.y, eye.y), maxf(hi.z, eye.z))
	print("")
	print("=== HARNESS CHECK ===")
	print("camera moved over  x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f  (span %.1f x %.1f x %.1f m)" % [
		lo.x, hi.x, lo.y, hi.y, lo.z, hi.z, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z,
	])
	if hi.x - lo.x < 5.0 and hi.z - lo.z < 5.0:
		printerr("FATAL: the camera barely moved across the whole sweep -- every sample is the same frame. Fix the harness before reading anything below.")

	print("")
	print("=== COVERAGE ===")
	print("standing positions measured : %d  (%.0f m^2 of walkable ground at %.2f m spacing)" % [
		_cells.size(), _cells.size() * STEP * STEP, STEP,
	])
	print("cells where the child is HIDDEN from the camera (any of 3 body samples, layers 1+2): %d (%.1f%%)" % [
		occluded, 100.0 * occluded / maxi(_cells.size(), 1),
	])
	print("  ... of which the shipped layer-2-only test would notice        : %d (%.1f%%)" % [
		wall, 100.0 * wall / maxi(_cells.size(), 1),
	])
	print("cells where RENDER geometry stands between camera and child      : %d (%.1f%%)" % [
		vis, 100.0 * vis / maxi(_cells.size(), 1),
	])
	print("cells where BOTH agree the child is hidden (the honest number)   : %d (%.1f%%)" % [
		real, 100.0 * real / maxi(_cells.size(), 1),
	])
	print("cells where part of the child is outside the camera frustum      : %d (%.1f%%)" % [
		out_of_frame, 100.0 * out_of_frame / maxi(_cells.size(), 1),
	])


## Which of world_bounds.gd's rooms a standing position is in. The park is
## split at z=-14 because that is where a 10.5 m northward throw stops
## fitting between the player and the park's own north boundary wall
## (z=-4) -- north of it the shot is clamped, south of it it is not, and
## reporting them as one number hides exactly the fault this sweep exists
## to find.
func _region(x: float, z: float) -> String:
	if z > 8.0:
		return "HOME"
	if z > -4.0:
		return "LANE"
	if x > 11.0:
		return "GARDEN" if z > -16.0 else "SE LAWN"
	if z > -14.0:
		return "PARK north"
	return "PARK south"


const REGIONS := ["HOME", "LANE", "PARK north", "PARK south", "GARDEN", "SE LAWN"]


func _report_regions() -> void:
	print("")
	print("=== WHERE THE FAULTS ARE ===")
	print("%-12s %7s | %10s %10s %10s %10s %9s" % [
		"region", "cells", "hidden", "off-frame", "ratio<.35", "wall<0.6m", "med dist",
	])
	print("-".repeat(80))
	for region in REGIONS:
		var n := 0
		var hidden := 0
		var off := 0
		var tight := 0
		var near := 0
		var dists: Array = []
		for m in _cells:
			if _region(m["px"], m["pz"]) != region:
				continue
			n += 1
			hidden += int(m["hidden"])
			if m["in_frame"] < 3:
				off += 1
			if float(m["ratio"]) < RATIO_FLOOR:
				tight += 1
			if float(m["clear"]) < 0.6:
				near += 1
			dists.append(float(m["dist"]))
		if n == 0:
			continue
		dists.sort()
		print("%-12s %7d | %5d %4.0f%% %5d %4.0f%% %5d %4.0f%% %5d %4.0f%% %9.2f" % [
			region, n,
			hidden, 100.0 * hidden / n, off, 100.0 * off / n,
			tight, 100.0 * tight / n, near, 100.0 * near / n,
			dists[dists.size() / 2],
		])


func _stat(key: String) -> Array:
	var values: Array = []
	for m in _cells:
		values.append(float(m[key]))
	values.sort()
	if values.is_empty():
		return [0.0, 0.0, 0.0, 0.0, 0.0]
	return [
		values[0],
		values[int(values.size() * 0.5)],
		values[int(values.size() * 0.9)],
		values[int(values.size() * 0.99)],
		values[values.size() - 1],
	]


func _count_worse(key: String, limit: float, above: bool) -> int:
	var n := 0
	for m in _cells:
		if above and float(m[key]) > limit:
			n += 1
		elif not above and float(m[key]) < limit:
			n += 1
	return n


func _report_distributions() -> void:
	print("")
	print("=== THE TABLE (every walkable cell) ===")
	print("%-26s %8s %8s %8s %8s %8s   %s" % ["metric", "min", "median", "p90", "p99", "max", "over threshold"])
	print("-".repeat(100))
	var rows := [
		["angle off-behind (deg)", "angle", ANGLE_LIMIT, true],
		["camera<->player (m)", "dist", 0.0, false],
		["distance / authored", "ratio", RATIO_FLOOR, false],
		["pitch below horiz (deg)", "pitch", 0.0, false],
		["frame below horizon (%)", "below", 0.0, false],
		["near geometry (% frame)", "near", NEAR_LIMIT, true],
		["near, floor excluded (%)", "standing", NEAR_LIMIT, true],
		["largest near object (%)", "top_near", 25.0, true],
		["body samples in frame", "in_frame", 3.0, false],
		["camera height y (m)", "cy", 0.0, false],
		["clearance to wall (m)", "clear", 0.6, false],
		["arm shortened to (m)", "arm_got", 0.0, false],
	]
	for row in rows:
		var s := _stat(row[1])
		var note := ""
		if row[2] != 0.0:
			var n := _count_worse(row[1], row[2], row[3])
			note = "%d cells %s %.2f" % [n, ">" if row[3] else "<", row[2]]
		print("%-26s %8.2f %8.2f %8.2f %8.2f %8.2f   %s" % [row[0], s[0], s[1], s[2], s[3], s[4], note])


func _rank(key: String, descending: bool, count: int, label: String) -> void:
	var sorted := _cells.duplicate()
	sorted.sort_custom(func(a, b):
		return float(a[key]) > float(b[key]) if descending else float(a[key]) < float(b[key]))
	print("")
	print("--- worst %s ---" % label)
	print("%9s %9s | %8s %8s %8s | %7s %7s %6s %6s %6s %5s  %s" % [
		"player x", "z", "cam x", "cam y", "cam z", "dist", "ratio", "angle", "pitch", "near%", "shown", "blocked by",
	])
	for i in range(mini(count, sorted.size())):
		var m: Dictionary = sorted[i]
		var who: String = m["blocker"]
		if who == "" and m["vis_name"] != "":
			who = "(render) %s" % m["vis_name"]
		print("%9.2f %9.2f | %8.2f %8.2f %8.2f | %7.2f %7.2f %6.1f %6.1f %6.1f %5d  %s" % [
			m["px"], m["pz"], m["cx"], m["cy"], m["cz"],
			m["dist"], m["ratio"], m["angle"], m["pitch"], m["standing"], m["in_frame"], who,
		])


func _report_worst() -> void:
	print("")
	print("=== RANKED WORST OFFENDERS ===")
	_rank("hidden", true, 8, "occlusion agreed by collider AND render geometry")
	_rank("blocked", true, 14, "occlusion by collider (3 = child completely hidden)")
	_rank("in_frame", false, 10, "child out of shot (0 = not in the frustum at all)")
	_rank("angle", true, 12, "angle off dead-behind")
	_rank("ratio", false, 12, "camera collapsed onto the player")
	_rank("standing", true, 10, "near geometry filling the frame (floor excluded)")
	_rank("clear", false, 12, "camera jammed against a camera-blocking wall")
	_rank("pitch", true, 10, "steepest look-down (staring at the dirt)")
	_rank("pitch", false, 10, "flattest/upward look (staring past the child)")

	# Which objects hide the child, and how often.
	var tally := {}
	for m in _cells:
		if m["hidden"] == 1:
			var who: String = "%s / %s" % [m["blocker"], m["vis_name"]]
			tally[who] = tally.get(who, 0) + 1
	var ranked: Array = []
	for k in tally:
		ranked.append([k, tally[k]])
	ranked.sort_custom(func(a, b): return a[1] > b[1])
	print("")
	print("--- what actually hides the child, by cell count ---")
	for entry in ranked:
		print("%6d cells  %s" % [entry[1], entry[0]])


## The discontinuity pass. A 0.5 m step in player position should move the
## camera about 0.5 m; anywhere it moves much more, the camera SNAPS as you
## walk across that line, and that is far more noticeable in play than a
## merely badly-placed camera.
func _neighbour_pass() -> void:
	var pairs: Array = []
	for m in _cells:
		var cell: Vector2i = m["cell"]
		for delta in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other_index := _index(cell + delta)
			if not _slot.has(other_index):
				continue
			var n: Dictionary = _cells[_slot[other_index]]
			var move := Vector3(m["cx"] - n["cx"], m["cy"] - n["cy"], m["cz"] - n["cz"]).length()
			var dyaw := absf(rad_to_deg(angle_difference(m["yaw"], n["yaw"])))
			pairs.append({"a": m, "b": n, "move": move, "dyaw": dyaw})

	var moves: Array = []
	var yaws: Array = []
	for pair in pairs:
		moves.append(pair["move"])
		yaws.append(pair["dyaw"])
	moves.sort()
	yaws.sort()
	var over := 0
	for v in moves:
		if v > JUMP_LIMIT:
			over += 1

	print("")
	print("=== DISCONTINUITY (each cell vs its +x/+z neighbour, %.2f m apart) ===" % STEP)
	print("%d neighbour pairs" % pairs.size())
	print("camera travel per step : median %.3f m  p90 %.3f  p99 %.3f  max %.3f" % [
		moves[int(moves.size() * 0.5)], moves[int(moves.size() * 0.9)],
		moves[int(moves.size() * 0.99)], moves[moves.size() - 1],
	])
	print("camera yaw change/step : median %.2f deg  p90 %.2f  p99 %.2f  max %.2f" % [
		yaws[int(yaws.size() * 0.5)], yaws[int(yaws.size() * 0.9)],
		yaws[int(yaws.size() * 0.99)], yaws[yaws.size() - 1],
	])
	print("pairs where the camera moves more than %.1f m for one step: %d" % [JUMP_LIMIT, over])

	pairs.sort_custom(func(a, b): return a["move"] > b["move"])
	print("")
	print("--- worst camera jumps ---")
	print("%9s %9s -> %9s %9s | %7s %8s | %s" % ["player x", "z", "x", "z", "jump m", "dyaw deg", "camera moved"])
	for i in range(mini(16, pairs.size())):
		var pair: Dictionary = pairs[i]
		var a: Dictionary = pair["a"]
		var b: Dictionary = pair["b"]
		print("%9.2f %9.2f -> %9.2f %9.2f | %7.2f %8.2f | (%.2f,%.2f,%.2f) -> (%.2f,%.2f,%.2f)" % [
			a["px"], a["pz"], b["px"], b["pz"], pair["move"], pair["dyaw"],
			a["cx"], a["cy"], a["cz"], b["cx"], b["cy"], b["cz"],
		])


func _report_single(x: float, z: float) -> void:
	await _settle_at(x, z)
	var m := _measure()
	print("")
	print("=== SINGLE CELL (%.2f, %.2f) ===" % [x, z])
	for key in ["cx", "cy", "cz", "dist", "authored", "ratio", "angle", "pitch", "below",
			"near", "top_near", "top_name", "blocked", "blocker", "wall_hit",
			"vis_blocked", "vis_name", "arm_want", "arm_got"]:
		print("  %-12s %s" % [key, m[key]])


# ------------------------------------------------------------------- drive --

## A genuine continuous drive through every region -- real simulated WASD
## via tests/helpers/drive.gd, never teleportation. Teleport sampling and
## driven motion find different bugs: the rig's damping and the SpringArm's
## springback only exist while moving, and a settled sweep cannot see them.
## Every waypoint below was confirmed reachable by the flood before being
## written down, and the legs deliberately steer AROUND the tower stairs
## (world_bounds.gd's {x:-6.197,z:-12.25} box, whose west end is a climb
## trigger) -- a leg that walks into it hands the player to player.gd's
## CLIMBING verb and the "drive" stops being a walk.
const DRIVE_ROUTE := [
	[0.0, 13.0],    # up to the door -- the home room end to end
	[0.0, 9.0],     # back down to the lane mouth
	[-3.5, 4.0],    # down the lane, hugging one wall
	[3.5, -1.0],    # and cross to the other
	[0.0, -5.0],    # into the park through the mouth
	[-9.0, -5.5],   # west along the north edge, under the canopy trees
	[-14.0, -7.0],
	[-19.0, -9.0],  # far west lawn
	[-21.0, -20.0], # deep south-west corner
	[-14.0, -21.0], # past the west park tree
	[-3.4, -16.0],  # east along the park's south, under the left tower
	[-11.0, -15.5], # back west, giving the stairs a wide berth: the climb
	[-11.0, -9.0],  #   trigger is a 0.55 m circle at (-8.04, -12.25) and a
	[-6.0, -8.0],   #   leg that clips it turns the walk into a tower climb
	[0.0, -10.0],   # chalk circle
	[3.4, -16.0],   # under the right tower
	[6.5, -21.5],   # south, past the canopy tree at (4.6, -20.4)
	[13.0, -21.0],  # south-east lawn
	[20.0, -20.5],  # far south-east corner
	[16.0, -17.5],  # back along the pocket's south wall
	[8.0, -17.5],
	[9.6, -12.0],   # past the canopy tree at (9.6,-14.6)
	[12.0, -8.0],   # through the garden gap
	[16.0, -10.0],  # into the pocket
	[20.0, -6.0],   # the pocket's far corner
	[12.0, -8.0],   # back out through the gap
	[0.0, -8.0],    # watch marker
	[0.0, 0.0],     # back up the lane
	[0.0, 10.0],    # home
]


func _drive() -> void:
	_player.set("external_control", false)
	_player.global_position = Vector3(0.0, _player.get("locked_y"), 10.0)
	_rig.set("_initialized", false)
	await physics_frame

	# A Dictionary, not plain locals: GDScript lambdas capture outer LOCALS
	# by value, so `ticks += 1` inside on_tick would mutate a private copy
	# invisible out here. test_camera_never_in_geometry.gd's own on_tick
	# records the same gotcha; this probe reproduced it the first time it
	# ran (it reported "0 of 0 ticks" and a nonsense per-tick jump because
	# `last_cam` never advanced).
	var s := {
		"jump": 0.0, "jump_at": Vector2.ZERO,
		"angle": 0.0, "angle_at": Vector2.ZERO,
		"ratio": INF, "ratio_at": Vector2.ZERO,
		"occluded": 0, "wall": 0, "seen": 0,
		"last_cam": _camera.global_position,
	}
	var jumps: Array = []
	var angles: Array = []
	var ratios: Array = []
	var blockers := {}

	var on_tick := func() -> void:
		s["seen"] += 1
		var p := _player.global_position
		var eye := _camera.global_position
		var jump: float = eye.distance_to(s["last_cam"])
		s["last_cam"] = eye
		jumps.append(jump)
		if jump > s["jump"]:
			s["jump"] = jump
			s["jump_at"] = Vector2(p.x, p.z)

		var profile: Dictionary = CameraProfile.profile(p.z)
		var offset := Vector2(eye.x - p.x, eye.z - p.z)
		var back := Vector2(sin(profile["authored_yaw"]), cos(profile["authored_yaw"]))
		if offset.length() > 0.05:
			var angle := absf(rad_to_deg(back.angle_to(offset)))
			angles.append(angle)
			if angle > s["angle"]:
				s["angle"] = angle
				s["angle_at"] = Vector2(p.x, p.z)
		var ratio := eye.distance_to(p) / float(profile["distance"])
		ratios.append(ratio)
		if ratio < s["ratio"]:
			s["ratio"] = ratio
			s["ratio_at"] = Vector2(p.x, p.z)

		for h in BODY_SAMPLES:
			var q := PhysicsRayQueryParameters3D.create(eye, p + Vector3(0.0, h, 0.0))
			q.exclude = _exclude
			q.collision_mask = 3
			var hit := _space.intersect_ray(q)
			if not hit.is_empty():
				s["occluded"] += 1
				var who: String = _labels.get(hit["rid"], str(hit["collider"].name))
				blockers[who] = blockers.get(who, 0) + 1
				break
		var wq := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, HEAD_HEIGHT, 0.0), eye)
		wq.exclude = _exclude
		wq.collision_mask = 2
		if not _space.intersect_ray(wq).is_empty():
			s["wall"] += 1

	print("")
	print("=== CONTINUOUS DRIVE (%d legs, real simulated input) ===" % DRIVE_ROUTE.size())
	var started := Time.get_ticks_msec()
	var ticks: int = await DriveRoute.run(_runner, _player, DRIVE_ROUTE, on_tick)
	jumps.sort()
	angles.sort()
	ratios.sort()
	print("ticks driven: %d (%.1f s of play, measured in %.1f s)" % [
		ticks, ticks / 60.0, (Time.get_ticks_msec() - started) / 1000.0,
	])
	print("child hidden from the camera on %d of %d ticks (%.1f%%)" % [
		s["occluded"], s["seen"], 100.0 * float(s["occluded"]) / maxf(float(s["seen"]), 1.0),
	])
	print("  layer-2-only (what the shipped test asserts) : %d ticks" % s["wall"])
	if not jumps.is_empty():
		print("camera travel per tick : median %.4f m  p99 %.4f  max %.4f m at (%.2f, %.2f)" % [
			jumps[int(jumps.size() * 0.5)], jumps[int(jumps.size() * 0.99)],
			s["jump"], s["jump_at"].x, s["jump_at"].y,
		])
	if not angles.is_empty():
		print("angle off-behind       : median %.2f  p99 %.2f  max %.2f deg at (%.2f, %.2f)" % [
			angles[int(angles.size() * 0.5)], angles[int(angles.size() * 0.99)],
			s["angle"], s["angle_at"].x, s["angle_at"].y,
		])
	if not ratios.is_empty():
		print("distance / authored    : median %.3f  p1 %.3f  min %.3f at (%.2f, %.2f)" % [
			ratios[int(ratios.size() * 0.5)], ratios[int(ratios.size() * 0.01)],
			s["ratio"], s["ratio_at"].x, s["ratio_at"].y,
		])
	var ranked: Array = []
	for k in blockers:
		ranked.append([k, blockers[k]])
	ranked.sort_custom(func(a, b): return a[1] > b[1])
	print("what hid the child while walking (ticks):")
	for entry in ranked:
		print("  %6d  %s" % [entry[1], entry[0]])
