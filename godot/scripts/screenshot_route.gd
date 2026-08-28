extends SceneTree
## screenshot_route.gd -- drives the real, running game through the six
## named story beats from GODOT_REBUILD_PLAN.md's 3.4 ("Screenshot A/B":
## "windowed run drives the 1.4 route, saves six PNGs (threshold, watch,
## gap, ball, circle, door)") and saves one PNG per beat at the real play
## camera, for visual review against docs/reference/*.jpg.
##
## Must run WITHOUT --headless -- headless mode never renders a frame, so
## get_root().get_texture().get_image() comes back blank. Windows GDI
## screen-capture of the game window returns black too, so this in-engine
## Viewport.get_texture().get_image() capture is the only reliable route.
## See tools/shots.sh / tools/shots.ps1 for the exact invocation.
##
## Drives with real simulated WASD input via gdUnit4's own scene-runner
## machinery (tests/helpers/drive.gd's DriveRoute -- the same code
## tests/play/test_playthrough.gd and test_camera_never_in_geometry.gd
## drive the player with) rather than teleporting it, per the plan's
## working agreement ("real input, not a debug-command shortcut"). The
## runner is constructed directly here, not via GdUnitTestSuite's
## scene_runner() helper (addons/gdUnit4/src/GdUnitTestSuite.gd:269),
## because that helper only exists as a method on a running test suite
## instance -- GdUnitSceneRunnerImpl.new(scene, verbose) is exactly what it
## calls internally, and GdUnitSceneRunner is a plain, globally-registered
## (class_name) RefCounted, usable from any script once the project has
## been imported once.
##
## Beat positions and the safe route between them come straight from the
## already-proven play tests, not re-derived here:
##   - threshold: player.gd:25 START_POSITION (the doorway threshold).
##   - watch/ball/door: test_playthrough.gd's ROUTE_TO_WATCH/ROUTE_TO_BALL/
##     ROUTE_TO_DOOR.
##   - gap/circle: test_camera_never_in_geometry.gd's ROUTE comment block
##     spells out *why* a direct line from BallEnd to Group isn't safe --
##     world_bounds.gd:30-31's two garden-wall colliders sit at
##     x in [5.05, 5.75], and a straight line from either Watch or BallEnd
##     to the far side clips that corner. Both tests funnel through
##     (6.5, -3.0) first; this script does the same, then takes one short
##     final hop to the exact authored gap position for the "gap" shot.

const SCENE_PATH := "res://scenes/main.tscn"
const OUT_DIR := "user://shots"

## camera_rig.gd:73 damps the desired camera position each physics tick
## with alpha = 1 - exp(-delta * 7.3); at 60 ticks/sec that's exp(-7.3)
## ~= 0.00068 of the original error left after 60 ticks (~1s real time) --
## effectively fully converged. Matches the plan's own "settle >= 60
## frames before capturing" instruction.
const SETTLE_TICKS := 60

## Extra warm-up before the very first capture only, on top of the normal
## per-beat settle above -- the proven-working technique this script is
## built from waited 150 frames before its first (and only) capture, and
## this script's own first capture happens sooner than that (after just
## simulate_frames(2) + one SETTLE_TICKS wait) since everything after it
## is paced by driving/dispatching instead. Cheap insurance against
## capturing before the window has actually produced a real composited
## frame -- the exact failure mode (a black frame) this tool exists to
## catch, not just cause elsewhere.
const WARMUP_TICKS := 150

## ball.gd:13's FLIGHT_SECONDS is 1.8s of real, unscaled engine time. This
## script deliberately never touches Engine.time_scale the way
## test_playthrough.gd does to keep its own runtime down -- doing so here
## would also compress game.gd:110-114's 2.6s OBSERVED -> ball_kicked
## auto-schedule() into a fraction of a second, racing this script's own
## manual dispatch("ball_kicked") call below. Running at real speed avoids
## that whole class of timing bug; 300 ticks (5s real) is generous
## headroom over the 1.8s flight it's actually waiting for.
const MAX_WAIT_TICKS := 300

var _runner: GdUnitSceneRunner = null
var _main: Node = null
var _player: Node3D = null
var _hide_ui := true
var _failures: Array[String] = []

## The Game autoload, fetched via get_node() rather than referenced as the
## bare identifier `Game` -- a --script entry point (this file, as
## SceneTree's own _initialize()) compiles before the project's autoload
## globals are registered for GDScript's static analyzer, even though the
## actual /root/Game node already exists by the time _run() executes.
## Same constraint tools/_bootstrap_main_scene.gd's doc comment calls out
## ("Game autoload isn't registered this early in a bare --script run") --
## that script avoids it by never referencing Game itself and only
## instantiating PackedScenes whose *own* attached scripts (compiled later,
## at instantiate() time) reference Game directly and safely. There's no
## equivalent PackedScene indirection available here, so this script routes
## every access through this untyped handle instead.
var _game: Node = null


func _initialize() -> void:
	_run()


func _run() -> void:
	# Custom flags must come after a literal "--" for Godot to hand them to
	# OS.get_cmdline_user_args() instead of trying (and failing) to parse
	# them as engine options -- see tools/shots.sh/.ps1's invocation.
	if OS.get_cmdline_user_args().has("--ui"):
		_hide_ui = false

	# See the class doc comment: instantiate + add-to-tree ourselves
	# (exactly what scene_runner() does), never change_scene_to_file() on
	# top of it -- that would load a second, competing copy of main.tscn
	# and whichever one's _ready() runs last would win Game.player/camera/
	# ball.
	_runner = GdUnitSceneRunnerImpl.new(SCENE_PATH, false)
	await _runner.simulate_frames(2)  # let every node's _ready() run (test_playthrough.gd:34)

	_main = _runner.scene()
	if _main == null:
		push_error("screenshot_route: failed to load/instantiate %s" % SCENE_PATH)
		_shutdown(1)
		return

	_hide_ui_layers()

	_game = get_root().get_node("Game")  # SceneTree has no get_node() of its own -- root is the actual Node
	_player = _game.player
	if not is_instance_valid(_player):
		push_error("screenshot_route: Game.player is null after scene load")
		_shutdown(1)
		return

	_game.start_episode(0.0)  # test_playthrough.gd:34's own call -- deterministic clock, real reason unrelated to time_scale above
	_hide_ui_layers()  # start_episode() fires Game.state_changed too -- see _dispatch()'s own comment

	for _i in range(WARMUP_TICKS):
		await physics_frame

	# 1. threshold -- player.gd:25 START_POSITION, ARRIVE (start_episode's
	# own reset), before any input at all.
	await _settle_and_capture(1, "threshold")

	# 2. watch -- test_playthrough.gd's ROUTE_TO_WATCH, then the "observe"
	# event (episode_director.gd:35) into OBSERVED.
	await _drive([[0.0, -1.2]])
	_dispatch("observe")
	await _settle_and_capture(2, "watch")

	# 3+4: the ball's flight is a real 1.8s Tween (ball.gd:60-67) that
	# dispatches "ball_landed" itself when it finishes. Wait for that
	# rather than dispatching it by hand, so the ball's rendered position
	# in the next two shots is wherever the tween actually left it.
	_dispatch("ball_kicked")
	await _wait_while_state(EpisodeDirector.State.BALL_IN_FLIGHT)

	# gap -- via (6.5,-3.0) first, the same safety-margin waypoint both
	# test_playthrough.gd (ROUTE_TO_BALL/ROUTE_TO_GROUP) and
	# test_camera_never_in_geometry.gd (ROUTE) route through before cutting
	# across the garden-wall gap, then one short hop to the authored gap
	# position itself.
	await _drive([[6.5, -3.0], [5.2, -3.0]])
	await _settle_and_capture(3, "gap")

	# ball -- test_playthrough.gd's ROUTE_TO_BALL's own final waypoint,
	# ball.gd:10's END position.
	await _drive([[8.6, -6.6]])
	await _settle_and_capture(4, "ball")

	# circle -- "ball_picked_up" into RETURN_BALL (ball.gd:53-54 starts
	# carrying), back through the same safety-margin waypoint (mirrors
	# ROUTE_TO_GROUP), then "ball_returned" into INVITED (ball.gd:55-57
	# snaps it to REST_POSITION immediately -- no tween to wait for here).
	_dispatch("ball_picked_up")
	await _drive([[6.5, -3.0], [0.0, -3.1]])
	_dispatch("ball_returned")
	await _settle_and_capture(5, "circle")

	# door -- "joined" into GO_HOME, then test_playthrough.gd's
	# ROUTE_TO_DOOR. Deliberately not dispatching "entered_home": the beat
	# is "going home", not "arrived home" -- COMPLETE is one event past
	# this frame.
	_dispatch("joined")
	await _drive([[0.0, 10.8]])
	await _settle_and_capture(6, "door")

	# Printed on both outcomes, tagged for easy grep -- tools/shots.sh/.ps1
	# parse this line out of stdout to find where to copy the PNGs from,
	# rather than hardcoding user://'s real path (which differs by OS and
	# depends on application/config/name in project.godot).
	print("SHOTS_DIR: %s" % ProjectSettings.globalize_path(OUT_DIR))

	if _failures.is_empty():
		print("screenshot_route: all 6 shots captured cleanly.")
		_shutdown(0)
	else:
		push_error("screenshot_route: %d shot(s) look broken: %s" % [_failures.size(), ", ".join(_failures)])
		_shutdown(1)


## quit(code) directly, with GdUnitSceneRunner (_runner) still alive,
## reliably segfaulted on exit (confirmed empirically: the team-lead-proven
## change_scene_to_file()-based snippet, with no GdUnitSceneRunner
## involved at all, exits 0 cleanly under the exact same --path/--script
## invocation; adding the runner back in is what reintroduces the crash).
##
## GdUnitSceneRunnerImpl's own _notification(NOTIFICATION_PREDELETE)
## (addons/gdUnit4/src/core/GdUnitSceneRunnerImpl.gd:90-99) removes and
## frees the scene it instantiated -- if that fires *after* quit() has
## already torn down the tree (and freed that same scene as an ordinary
## child of root along the way), it's a double free. Nulling _runner alone
## doesn't force that cleanup to happen early enough to matter: the
## constructor (GdUnitSceneRunnerImpl.gd:73) also does
## Engine.set_meta("GdUnitSceneRunner", self), a *second* reference that
## outlives the local variable and keeps the RefCounted alive regardless.
## Clearing that meta key too is what actually drops the last reference
## and runs PREDELETE's cleanup immediately, while the tree is still fully
## alive -- so quit()'s own teardown never touches an already-freed scene
## afterward. (RefCounted objects have no public free()/dispose(); dropping
## the last reference is the only way to trigger this.)
func _shutdown(code: int) -> void:
	_runner = null
	Engine.remove_meta("GdUnitSceneRunner")
	quit(code)


func _dispatch(event_name: String) -> void:
	if not _game.dispatch(event_name):
		push_error("screenshot_route: dispatch(%s) rejected in state %s" % [event_name, _game.director.state])
	# hud.gd:34-35 sets its own CanvasLayer.visible = true on every single
	# Game.state_changed -- which every successful dispatch() (and
	# start_episode()) fires -- undoing _hide_ui_layers(). Re-hide
	# immediately so nothing ever renders a frame with it back on.
	_hide_ui_layers()


func _wait_while_state(state: String) -> void:
	var waited := 0
	while _game.director.state == state and waited < MAX_WAIT_TICKS:
		await physics_frame
		waited += 1
	if _game.director.state == state:
		_failures.append("stuck in %s after %d ticks" % [state, MAX_WAIT_TICKS])
		push_error("screenshot_route: state stuck at %s after %d ticks" % [state, MAX_WAIT_TICKS])


## DriveRoute.run (tests/helpers/drive.gd:60) takes a per-tick Callable for
## the caller's own assertions (test_playthrough.gd tracks the ball's
## height with it); this script has none, so it's a no-op.
func _drive(waypoints: Array) -> void:
	await DriveRoute.run(_runner, _player, waypoints, func() -> void: pass)


## Every CanvasLayer under Main, at any depth -- main.tscn's own direct
## children (Vignette, Hud, TitleCard, EndCard -- scenes/main.tscn:59-68)
## today, but found recursively rather than via _main.get_children() alone
## so a CanvasLayer nested inside one of those (or added later) can't slip
## through un-hidden. DebugOverlay is a separate autoload sibling of Main,
## not a descendant of it, and already starts hidden (debug_overlay.gd:7,20),
## so it needs no handling here.
##
## Called after startup, after every _dispatch(), and again before every
## settle-and-capture window below -- hud.gd:34-35 sets its own
## CanvasLayer.visible = true on every single Game.state_changed, so a
## single hide-at-startup call gets undone the moment the first event
## fires. Calling this is cheap (a handful of nodes, one bool set each) so
## there's no reason to be clever about exactly which of those call sites
## is strictly necessary.
func _hide_ui_layers() -> void:
	if not _hide_ui:
		return
	_hide_canvas_layers_recursive(_main)


func _hide_canvas_layers_recursive(node: Node) -> void:
	if node is CanvasLayer:
		node.visible = false
	for child in node.get_children():
		_hide_canvas_layers_recursive(child)


func _settle_and_capture(shot_index: int, beat_name: String) -> void:
	# Hidden *before* the settle wait, not right before the capture: a
	# CanvasLayer.visible flip only shows up in whatever frame the
	# compositor renders next, and get_texture().get_image() below reads
	# back whatever the compositor already produced -- flipping it and
	# reading in the same tick with no frame boundary between risks
	# reading a frame rendered just before the flip took effect. Sixty
	# ticks of settle time afterward makes that a non-issue.
	_hide_ui_layers()
	for _i in range(SETTLE_TICKS):
		await physics_frame

	var img: Image = get_root().get_texture().get_image()
	if img == null or img.is_empty():
		_failures.append("%s (no image)" % beat_name)
		push_error("screenshot_route: %s produced no image" % beat_name)
		return

	if _looks_blank(img):
		_failures.append("%s (looks blank/black)" % beat_name)
		push_error("screenshot_route: %s looks blank/black" % beat_name)

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var rel_path := "%s/%02d_%s.png" % [OUT_DIR, shot_index, beat_name]
	var err := img.save_png(rel_path)
	if err != OK:
		_failures.append("%s (save_png error %d)" % [beat_name, err])
		push_error("screenshot_route: save_png(%s) failed: %d" % [rel_path, err])
		return

	var abs_path := ProjectSettings.globalize_path(rel_path)
	var p := _player.global_position
	var cam: Camera3D = _game.camera
	var cam_pos := cam.global_position if is_instance_valid(cam) else Vector3.INF
	print("[%s] state=%s player=(%.2f, %.2f, %.2f) camera=(%.2f, %.2f, %.2f) -> %s" % [
		beat_name, _game.director.state, p.x, p.y, p.z, cam_pos.x, cam_pos.y, cam_pos.z, abs_path,
	])


## Cheap smoke test for the exact failure mode this tool exists to avoid
## (a black frame from capturing before the window has actually rendered,
## or from a headless run slipping through despite the guard above) --
## downsamples to 8x8 and checks average brightness rather than every
## pixel of a full-resolution image.
func _looks_blank(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	if w == 0 or h == 0:
		return true
	var thumb: Image = img.duplicate()
	thumb.resize(8, 8, Image.INTERPOLATE_BILINEAR)
	var total := 0.0
	for y in range(8):
		for x in range(8):
			var c := thumb.get_pixel(x, y)
			total += c.r + c.g + c.b
	var avg := total / (8 * 8 * 3)
	return avg < 0.01
