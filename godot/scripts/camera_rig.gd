extends Node3D
## Port of src/game.mjs's updateCamera() (lines 384-411) onto a pivot (this
## node) -> SpringArm3D -> Camera3D chain. Verbatim except for the home-end
## pull-in fix inside _physics_process's `desired_x`/`desired_z` block below
## -- see its comment; game.mjs's own per-axis clamp is still the common path.
##
## The pivot sits at the look-at target (matching the source's
## threeCamera.lookAt(target)); the SpringArm3D is oriented from the pivot
## toward the damped desired camera position, with spring_length set to
## that distance -- so SpringArm3D's own collision shapecast pulls the
## camera inward exactly when geometry would otherwise clip it. That's the
## thing Saturday Afternoon's hand-rolled camera got wrong (follow camera
## left outside the starting room's walls).
##
## MOUSE-LOOK (camera-fix task, 2026-08-28): restored from game.mjs's
## pointerdown/pointermove/pointerup drag-look (lines 309-325, 386-392),
## dropped by the original M1.4 port ("no orbit/mouse-look in this pass",
## a deliberate simplification while the world was one room the player
## always faced the same authored direction across). The world is now four
## connected places; the player needs to be able to look around while
## exploring. `_look_yaw`/`_look_pitch` accumulate from left-mouse-drag
## motion (project.godot's `camera_look` action gates the drag, matching
## the source's single-pointer model), clamped to the source's own cone
## (yaw +-0.36 rad, pitch -0.12..0.2) and springing back to the authored
## angle (lambda 2.0/2.3) whenever the button is released -- so the
## authored zone framing (ART_DIRECTION.md's "camera placement is part of
## the visual identity") is always what the camera returns to, never a
## free third-person orbit. Reduced-motion disables the look entirely
## (matches the source's own `if (!dragActive || reducedMotion) return`).
##
## Deliberately NOT threaded into player.gd's own movement-relative-camera
## yaw (which the source *did* couple: dragging also rotated which way "W"
## walks). Movement staying authored-yaw-only is player.gd's own explicit,
## repeated design choice (three call sites, each commented "mouse-look yaw
## omitted") predating this task and shared with the wall-walk/platform
## verbs; re-plumbing it is a materially bigger change than "give the
## camera back" and out of this task's scope. The practical cost is small --
## the look cone is only +-0.36 rad (~20 deg) and springs back the moment
## the button is released, so a brief mismatch between where the camera
## looks and which way "forward" walks is the extent of it, not a durable
## disorientation.

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _smoothed_desired: Vector3 = Vector3.ZERO
var _initialized: bool = false
var _excluded_player: bool = false

## game.mjs:127-129's lookYaw/lookPitch/dragActive, ported verbatim.
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _drag_active: bool = false

## How far the shot has been turned off its authored angle to find a better
## one -- see the orbit block in _physics_process. Zero everywhere the
## authored angle is already the best available, which is most of the world.
var _orbit_yaw: float = 0.0

const LOOK_YAW_LIMIT := 0.36     # game.mjs:322
const LOOK_PITCH_MIN := -0.12    # game.mjs:323
const LOOK_PITCH_MAX := 0.2      # game.mjs:323
## game.mjs:322-323 (per pixel of drag), left verbatim rather than guessed
## at a second time (camera-fix task, round 2). Reconsidered whether to
## rescale for this window: the source itself has no fixed reference size
## either (game.mjs:43 builds its camera off canvas.clientWidth/
## window.innerWidth, whatever the browser happens to be, and clamps
## devicePixelRatio rather than assuming one) -- pixel-space sensitivity
## was already going to feel different across browser windows in the
## original, so there is no single "correct" original feel to port a
## correction factor against, only a guess in one direction or the other.
## Reaching the full +-0.36 rad cone in ~80 px does read as quick by feel
## alone, but the mechanic is a bounded glance while exploring, not a slow
## orbit -- quick may be the point. Changing it on that hunch risks making
## it worse exactly as easily as better. Left alone; still genuinely
## unverified, and the developer's own hands-on read should overrule this
## the moment it's played.
const LOOK_YAW_SENSITIVITY := 0.0045
const LOOK_PITCH_SENSITIVITY := 0.0025
const LOOK_YAW_SPRINGBACK := 2.0       # game.mjs:387
const LOOK_PITCH_SPRINGBACK := 2.3     # game.mjs:388
const LOOK_PITCH_HEIGHT_SCALE := 2.8   # game.mjs:397


func _ready() -> void:
	Game.camera = camera


## game.mjs:309-325 -- pointerdown/pointermove/pointerup/pointercancel,
## ported onto Godot's own mouse events. _unhandled_input (not _input)
## matches every other input handler in this project (game.gd, pause_menu.gd,
## debug_overlay.gd) and means a drag that starts on a HUD button (which
## consumes the event first, standard Control behaviour) never also spins
## the camera.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_look"):
		_drag_active = true
	elif event.is_action_released("camera_look"):
		_drag_active = false
	elif event is InputEventMouseMotion and _drag_active and not Game.reduced_motion:
		var motion := event as InputEventMouseMotion
		_look_yaw = clampf(_look_yaw - motion.relative.x * LOOK_YAW_SENSITIVITY, -LOOK_YAW_LIMIT, LOOK_YAW_LIMIT)
		_look_pitch = clampf(_look_pitch + motion.relative.y * LOOK_PITCH_SENSITIVITY, LOOK_PITCH_MIN, LOOK_PITCH_MAX)


func _physics_process(delta: float) -> void:
	var player := Game.player
	if not is_instance_valid(player):
		return

	# Deferred rather than done in _ready(): sibling _ready() order (Player
	# vs CameraRig, both children of Main) isn't something to depend on --
	# this runs as soon as Game.player is actually set, whichever order
	# _ready() calls land in.
	if not _excluded_player:
		spring_arm.add_excluded_object(player.get_rid())
		_excluded_player = true

	# game.mjs:386-389 -- while not actively dragging (or under reduced
	# motion, which overrides an in-progress drag too -- source's own
	# `if (!dragActive || reducedMotion)`), both look axes damp back to the
	# authored angle. This is what makes the authored zone framing the
	# thing the camera always returns to rather than a free orbit.
	if not _drag_active or Game.reduced_motion:
		_look_yaw = CameraProfile.damp(_look_yaw, 0.0, LOOK_YAW_SPRINGBACK, delta)
		_look_pitch = CameraProfile.damp(_look_pitch, 0.0, LOOK_PITCH_SPRINGBACK, delta)

	var p := player.global_position
	var profile := CameraProfile.profile(p.z)
	# Pulled into explicitly-typed floats (not used inline from the
	# Dictionary) -- Vector3 has no operator overload for Variant, so an
	# inline `forward * profile["lead"]` can't be statically typed and
	# fails GDScript's `:=` inference. Same pattern as player.gd's yaw.
	# Movement (player.gd) intentionally stays authored_yaw-only, without
	# _look_yaw -- see this file's class doc comment.
	var yaw: float = profile["authored_yaw"] + _look_yaw
	var distance: float = profile["distance"]
	var height: float = profile["height"]
	var target_height: float = profile["target_height"]
	var fov: float = profile["fov"]
	var lateral: float = profile["lateral"]
	var lead: float = profile["lead"]

	# Garden-gap flip fix (camera-fix task, round 2, 2026-08-29). Found by a
	# fine sweep through the 2 m gap (world_bounds.gd's x=11 wall, opening
	# z in [-9,-7]) after the boundary-architecture retune, not by this
	# round's screenshots alone: REVEAL's lead (1.2) shifts the look-at
	# pivot 1.2 m south of the player before the spring arm even extends
	# north toward `desired` -- fine everywhere the arm has room, but inside
	# the gap the arm's own collision shapecast against the NORTH wall
	# segment (near face z=-7) can shorten it to under 1.2 m, leaving the
	# final camera position SOUTH of the player -- in front, not behind.
	# Measured: angle-off-behind swung to -179.6 deg (dist 1.52 m) at
	# player (11.32,-8.00), and the driven test route passes right through
	# this band (min_ratio 0.1240 there, same route as test_camera_never_
	# in_geometry.gd's own ROUTE). This is a different failure mode and a
	# different code path than the home-end pull-in fix above -- this is
	# the ordinary unclamped branch, degenerating purely from SpringArm3D's
	# own collision, not the manual world-envelope clamp.
	#
	# Fix: fade `lead` toward 0 near the gap, so the pivot stays at the
	# player instead of starting south of them -- confirmed by re-running
	# the same fine sweep with lead=0 in this band: angle-off-behind never
	# exceeded ~3 deg (still a tight, close shot -- the 2 m gap genuinely
	# doesn't fit a 10.5 m REVEAL throw -- but never on the wrong side).
	# Smoothed (not a hard cutoff) on both axes so crossing the band during
	# normal play is a gradual pull-in rather than a pop: `gap_x_term` fades
	# out 2 m either side of the wall's own x=11 line; `gap_z_term` is full
	# strength inside the opening itself and fades out 2 m past each
	# segment's near face (z=-9/-7). Scoped narrowly (only `lead`, only
	# this one small box) rather than touching `distance` again -- an
	# earlier attempt at a wider place-aware patch on `distance` pulled the
	# camera close enough to clip the wall outright (a real raycast hit at
	# (11.35, 1.79, -7), test_camera_never_in_geometry.gd caught it) and
	# was reverted; this is deliberately smaller and independently verified
	# (fine sweep, the real driven route, and the full suite) before
	# keeping it.
	var gap_x_term := 1.0 - LensMath.smoothstep(0.0, 2.0, absf(p.x - 11.0))
	var gap_z_dist := maxf(0.0, maxf(-9.0 - p.z, p.z + 7.0))
	var gap_z_term := 1.0 - LensMath.smoothstep(0.0, 2.0, gap_z_dist)
	lead = lerpf(lead, 0.0, gap_x_term * gap_z_term)

	# Garden-gap VOID fix (camera-fix task, round 2, 2026-08-29) -- a
	# different failure mode from the flip fix just above, sharing the same
	# player-position regime but not the same mechanism, so it needs its
	# own term rather than reusing gap_x_term/gap_z_term.
	#
	# The "gap" screenshot beat (player 10.46,-7.97, south of and just
	# outside the opening) was still a dead frame after the boundary retune
	# and the swing relocation (2ef80f1/23664c0) -- neither touched this.
	# Raycast-identified this time, not guessed from pixels
	# (tools/_probe_gap_raycast.gd, not committed): the camera sits at
	# (10.17, 2.60, 2.54), 10.5 m north of the player as REVEAL's authored
	# `distance` intends, but that lands it inside world_bounds.gd's own
	# WIDE INVISIBLE FLANK (the lane's camera_blocks=FALSE collider sealing
	# the lane against the playground/pocket, {"x":16.5,"z":2.0,"half_x":
	# 13.2,"half_z":6.0} in world_bounds.gd) -- deliberately nothing
	# rendered there (that collider's own doc comment: "there is nothing
	# rendered out there for a camera to clip through"), which is exactly
	# why nothing SpringArm3D-relevant stops the camera from reaching it:
	# camera_blocks=false means layer 2 never sees it, so the arm never
	# shortens and the full 10.5 m throw lands dead centre in the one
	# patch of the map built to have nothing in it.
	#
	# An earlier attempt this same task fixed this by halving `distance`
	# in a wide box (x in [8,12], z < -4) -- it improved this beat but the
	# box overlapped the gap OPENING itself (z in [-9,-7]) where the
	# player can ALSO be, and pulling the already-short REVEAL throw even
	# shorter there put the camera close enough to clip the gap's own
	# solid wall segment outright (a real raycast hit at (11.35, 1.79, -7),
	# caught by test_camera_never_in_geometry.gd). Reverted at the time.
	#
	# This attempt is deliberately gentler and, more importantly, verified
	# this time against the exact scenario that broke the last one: the
	# fine sweep through the opening itself (tools/_probe_gap_detail.gd,
	# not committed), a dedicated route-level probe checking every tick's
	# raycast rather than trusting one gdUnit4 run
	# (tools/_probe_camera_scale.gd, not committed), and the full suite --
	# all before keeping it. That extra probe earned its keep: an initial
	# 0.7x factor passed the official suite outright but the probe still
	# caught a real (if single-tick) hit at player (11.80,-8.47), camera
	# pulled close enough to graze the garden pocket's own NORTH wall
	# (z=-4, a different wall than the one this fix was written against) --
	# the official gdUnit4 run's own DriveRoute happens not to trace that
	# exact sub-metre path through the gap, but a changed step order or
	# timing could, so "the shipped test suite passed" wasn't good enough
	# evidence on its own here. 0.8x reproduced cleanly hit-free across
	# repeated probe runs and the full suite; kept with that margin rather
	# than pushing closer to the edge for a marginally better frame.
	# `void_x_term` reuses the same 2 m falloff as the flip fix (same wall
	# line); `void_z_term` is deliberately DIFFERENT from `gap_z_term`
	# above -- full strength for player z <= -4 (APPROACH/REVEAL
	# territory, where the "throw 10.5 m north" formula is actually in
	# effect) and fading out by z=-1 rather than reusing the opening-only
	# band, so it also covers players approaching the seam from further
	# inside the playground, not just standing in the opening.
	var void_x_term := 1.0 - LensMath.smoothstep(0.0, 2.0, absf(p.x - 11.0))
	var void_z_term := 1.0 - LensMath.smoothstep(-4.0, -1.0, p.z)
	distance = lerpf(distance, distance * 0.8, void_x_term * void_z_term)

	# ---- MOVE THE SHOT AROUND WHEN THE ANGLE IT HAS IS A BAD ONE --------
	# Camera-orbit task (2026-08-30). The developer's words after playing
	# round 5: "the only time it is struggling is that the default position
	# of the camera looking is the same as the one facing wall. It might be
	# worth considering moving it around a bit."
	#
	# Round 5 fixed the camera COLLAPSING against a wall behind the player.
	# It did not change the fact that the shot only ever moves ALONG the
	# authored axis -- shorter and higher -- so where that one axis is a bad
	# one there was nothing it could do. Measured over all 3610 walkable
	# cells (tools/_probe_camera_sweep.gd's new `open`/`gain` columns):
	# 1251 of them (34.7%) frame a window that sees under 0.45 of 15 m, and
	# at 1461 (40.5%) a bounded turn of the shot reached a materially better
	# one. The worst were not the places round 5 was written against at all:
	# the whole column against the park's west wall (x=-22) scored 0.45
	# openness with 0.42 available -- camera pressed 0.4 m off the wall face,
	# 100% of the picture wall, and forty metres of open park one turn to the
	# left.
	#
	# SCORED, NOT STEERED. Round 3 tried an unconditional yaw redirect near
	# the garden seam and it clipped the gap's own corners in five variants
	# (this file's own history). What is different here: nothing is
	# redirected anywhere. Candidate angles either side of the authored one
	# are MEASURED against the real world -- how much of the authored throw
	# actually fits that way, and how much the frame would then see -- and
	# the shot slides toward whichever measured better, if any did. Where the
	# authored angle is already good (the whole open park: every candidate
	# scores the same, so ORBIT_CENTRE_COST decides) the answer is exactly
	# zero and nothing moves. The seam that beat round 3 is excluded
	# outright; see `authority` in _choose_orbit().
	#
	# It goes through TWO stages of damping -- ORBIT_LAMBDA here, then
	# `_smoothed_desired`'s own lambda 7.3 below -- because an orbit that
	# finds a better angle by snapping to it is worse than one that stays
	# put. 2.0 is a half-second time constant: a full swing reads as the
	# camera deciding to move, over about a second and a half.
	var orbit_target := _choose_orbit(p, yaw, distance, height)
	if _initialized:
		_orbit_yaw = CameraProfile.damp(_orbit_yaw, orbit_target, ORBIT_LAMBDA, delta)
	else:
		# `_initialized` means "there is no continuity to preserve" -- the
		# same tick on which `_smoothed_desired` snaps onto `desired` below.
		# tools/_probe_camera_sweep.gd clears it to read a settled state in
		# two physics ticks instead of ninety; without this the orbit would
		# still be crawling out of the PREVIOUS cell's answer and every
		# number in that sweep would be a smear of two positions.
		_orbit_yaw = orbit_target
	yaw += _orbit_yaw

	var s := sin(yaw)
	var c := cos(yaw)
	var back := Vector3(s, 0.0, c)
	var lat := Vector3(c, 0.0, -s)
	var forward := Vector3(-s, 0.0, -c)

	# game.mjs:407-409 -- look-at target, ahead of the player by `lead`.
	# Hoisted above `desired` (the source builds it after) because the
	# room-fitting below has to aim from it and then move it.
	var target := Vector3(p.x, target_height, p.z) + forward * lead

	# ---- FIT THE SHOT TO THE ROOM BEHIND THE PLAYER ---------------------
	# Camera sweep (camera-fix task, round 4, 2026-08-30;
	# tools/_probe_camera_sweep.gd). Measured over all 3610 walkable
	# positions rather than the six authored beats, this was the single
	# worst thing the camera did: 560 of them (15.5% of the world) had the
	# camera under 0.35 of its authored distance, and the frames are dead
	# -- at the park's north edge (-9.5,-6) the camera sat 2.40 m from the
	# child with 80% of the picture filled by the inside face of the
	# boundary wall; on the south-east lawn (16,-17) it sat 1.48 m away
	# with the child not fully in frame at all.
	#
	# The mechanism is NOT that the shot is too long for the room. It is
	# WHERE the shortening happens. SpringArm3D shortens the whole arm --
	# a shot authored at 7.5 m back and 3.2 m up becomes 1.7 m back and
	# 1.4 m up, because the arm keeps its direction and loses its length,
	# so the height collapses in exact proportion with the distance and
	# the camera ends up at the child's own head height, at arm's length,
	# staring at the back of their neck. That is why the park's whole
	# northern strip shoots like this: the north boundary wall (z=-4) is
	# behind the player for every position with x outside the lane mouth.
	#
	# Fit the horizontal reach to the room that exists and KEEP THE
	# AUTHORED HEIGHT. The camera then climbs as it is pushed in -- 0.4 m
	# behind and 3.2 m up is a raised over-the-shoulder shot with the
	# child comfortably in frame and 3.2 m of real separation, where 0.4 m
	# behind and 1.2 m up is a shot of the back of a head. `lateral` and
	# `lead` scale by the same factor, so this is a dolly along the
	# authored aim (the same direction-preserving move the home-doorway
	# branch below already makes), never a swing to one side.
	#
	# Two more things fall out of doing it here rather than leaving it to
	# the spring arm, and they matter as much as the framing:
	#   - The arm's shortening is applied to the final transform with no
	#     damping at all, so crossing the edge of a wall SNAPPED. Measured
	#     at the lane mouth (z=-7), one metre of sideways walking, from
	#     x=4.5 to x=5.5, moved the camera 7.07 m instantly -- and the two
	#     frames either side of that line are a decent 3.4 m
	#     over-the-shoulder and a shot with half the screen filled by the
	#     lane wall. Folding the same measurement into `desired` puts it
	#     through `_smoothed_desired`'s existing damping instead.
	#   - The camera stops arriving pressed against wall faces, so the
	#     near-plane no longer sits inside rendered geometry.
	#
	# Deliberately NOT a yaw redirect: round 3 established with evidence
	# that steering the camera around the garden seam clips the wall
	# corners at (11,-9)/(11,-7) in every variant tried, and movement is
	# authored-yaw-only besides (this file's class doc comment).
	var room := _room_behind(p, back, distance)
	if room < distance:
		var fit := room / distance
		distance = room
		lateral *= fit
		lead *= fit
		target = Vector3(p.x, target_height, p.z) + forward * lead

		# Keeping the authored height is most of the fix, but not all of
		# it: the APPROACH->REVEAL blend is only ~16% of the way to REVEAL
		# at the park's own north edge (z=-5), so the height it preserves
		# there is 1.67 m, and 0.35 m back at 1.67 m up is still only 1.7 m
		# of separation -- measured, before this clause, at every position
		# along the garden pocket's north wall. Buy the separation the room
		# cannot give horizontally back as height instead.
		#
		# Two bounds on that climb, and the second one was found by looking
		# rather than by arithmetic. LIFT_MAX keeps the camera under the
		# park's own 4.2 m boundary wall. MAX_LIFT_PITCH exists because the
		# first version had none: at (16,-17), where the pocket's south
		# wall leaves 0.35 m of ground behind the player, the unbounded
		# lift put the camera 4.3 m up looking 83 deg down, and the frame
		# was the top of the child's head -- separation restored, shot
		# still useless. Capping the climb at what a 70 deg look-down can
		# use trades a little separation for a shot that reads as a high
		# follow rather than a floor plan.
		#
		# A version that instead pushed the look-at target FORWARD to flatten
		# that angle was tried and rejected on the frames it produced: with
		# the camera nearly on top of the child, moving the aim away from
		# them drops the child toward the BOTTOM of frame (further from the
		# camera reads as lower under a steep lens), and it walked the child
		# straight off the bottom edge at 20 of the 928 sampled positions.
		# Both directions were shot and looked at; this one keeps the child
		# centred.
		var aim_reach := room + lead
		var lifted := target_height + sqrt(maxf(
			MIN_SEPARATION * MIN_SEPARATION - room * room, 0.0))
		var pitch_ceiling := target_height + aim_reach * tan(MAX_LIFT_PITCH)
		height = clampf(minf(lifted, pitch_ceiling), height, height + LIFT_MAX)

	# game.mjs:394-400 -- desired camera position. `distance` and `lateral`
	# are offsets along two orthonormal directions relative to the player:
	# `back` (unit vector; game.mjs's own (sin yaw, cos yaw)) and `lat`
	# (unit vector, perpendicular to `back`; game.mjs's (cos yaw, -sin yaw)).
	# Kept as explicit Vector3s, rather than inlined the way game.mjs writes
	# desired.x/desired.z directly, because the doorway fix just below
	# reuses both directions.
	var raw_offset := back * distance + lat * lateral
	var raw_x := p.x + raw_offset.x
	var raw_z := p.z + raw_offset.z

	# The courtyard's own world-space envelope -- test_camera_never_in_
	# geometry.gd asserts the FINAL camera position never exceeds these, so
	# they stay the hard outer bound no matter what happens below.
	# Re-tuned for the 2026-08-28 world expansion (world_bounds.gd's own
	# doc comment has the four-room layout).
	#
	# UNLIKE the single-room version's pair, these are NOT "just inside
	# can_move_to's own envelope" -- an earlier version of this pass tried
	# exactly that (a uniform ~0.35 m margin off can_move_to's own
	# [-16.6,22.6]/[-20.3,16.3]) and it silently reproduced the doorway
	# collapse bug documented below, because that margin put the clamp
	# PAST the nearest real wall face instead of short of it. Each bound
	# below is instead picked to sit clear of the SPECIFIC nearest solid
	# thing a shot in that direction could reach: z min clears the park's
	# own back wall (near face -23.4); x min/max clear the park's west wall
	# (-22.4) and the garden pocket's east wall (21.65) respectively -- the
	# two widest rooms, and so the two real bounds a wide REVEAL-zone shot
	# could actually reach.
	#
	# Moved out with the park (2026-08-30, world_bounds.gd's PARK block).
	# These are not decoration: they are what stops a shot being composed
	# from outside the world, so a room that grows and clamps that did not
	# would leave a REVEAL camera pinned 7 m east of a player standing at
	# the new west boundary, shooting them side-on. Same rule as before --
	# 1.0 m short of the nearest wall face on each axis, and z max is
	# untouched because the home end did not move.
	#
	# z max is the home end's own bound, and is NOT the doorway piers
	# (front face 14.0) -- camera-fix task (2026-08-28): the piers only
	# mattered as a bound while the fallback below could swing `desired_x`
	# out several metres (the superseded sideways-swing fix, this file's
	# `else` branch below has the full history), which could put the
	# fallback target's own X inside the piers' footprint even though the
	# PLAYER was centered in the 2.4 m gap between them. This file's
	# pull-in fallback instead keeps `desired_x` close to the player at all
	# times (bounded by `raw_offset.x`, which is only ever a few tenths of
	# a metre for THRESHOLD/APPROACH/REVEAL's own authored `lateral`) --
	# for a centered player it can no longer reach the piers' footprint at
	# all, so the piers stop being the binding constraint. What remains is
	# the home room's own back cap (z=16.3, half_z 0.05, near face 16.25,
	# world_bounds.gd's true end-of-room wall) -- 15.9 sits 0.35 m short of
	# it, comfortably outside SpringArm3D's own 0.15 m shapecast margin.
	# Screenshot- and probe-verified (tools/shots.ps1's "door" beat;
	# tools/_probe_camera_swing.gd, camera-fix task, not committed): the
	# tighter 13.5 bound left almost no room for the pull-in fallback to
	# work with at the door beat (z~12.5, deep enough in the room that the
	# old bound was already only ~1 m of z away) -- distance 0.97 m,
	# visually the character's own head filling the frame. At 15.9 the same
	# beat gets ~3.3 m, matching the threshold beat's own well-composed
	# framing instead of collapsing near it.
	#
	# A player deliberately mouse-look-dragging toward the full +-0.36 rad
	# cone CAN still push `raw_offset.x` past the gap's own 1.2 m
	# half-width at this depth -- that's the spring arm's own shapecast
	# correctly shortening the shot against the pier the player just aimed
	# at, the exact "geometry clips it, so the arm pulls in" behaviour this
	# rig is built on (see this file's class doc comment), not a
	# regression of the bug above: it only happens on deliberate extreme
	# input, never at the authored default.
	var desired_z := clampf(raw_z, -23.0, 15.9)
	var desired_x: float
	if desired_z == raw_z:
		# Common case: the courtyard has room for the full authored shot
		# in its intended direction.
		desired_x = clampf(raw_x, -22.0, 21.0)
	else:
		# Doorway collapse fix (Gate 1 camera item; 780c690's commit
		# message: "at the home doorway the SpringArm3D camera collapses
		# into the player"). Diagnosed with a throwaway probe script
		# (godot/tools/_probe_camera_debug.gd, deleted after use, not
		# committed): SpringArm3D's own shapecast never fires here --
		# measured collision shrink was 0.0000 at every route beat,
		# including the door beat. The collapse is entirely this clamp:
		# near the home threshold the player is already only ~1m from the
		# z=12.3 wall this zone's camera formula wants to sit *beyond* (by
		# `distance`, THRESHOLD's own 5.5 authored below), so clamping
		# desired.z alone silently threw away nearly all of the horizontal reach
		# while `height` stayed at its full authored value -- the spring
		# arm's horizontal leg collapsed to a handful of centimeters while
		# its vertical leg stayed meters tall, producing a near-vertical
		# look-down that fills the frame with the back of the player's
		# head.
		#
		# 780c690's own fix (superseded below, camera-fix task 2026-08-28):
		# preserve the authored shot's XZ-plane *radius* and let the
		# shortfall the wall imposes swing sideways along `lat` instead of
		# vanishing. That traded the vertical collapse for a *lateral* one
		# nobody had measured: at the home porch's OWN start position
		# (player.gd's START_POSITION, z=10 -- not an edge case, the game's
		# literal opening frame) it parks the camera ~4.8 m to the side of
		# the player, so the shot reads as beside the child rather than
		# behind them, every time the player is anywhere in the home room
		# (probed across z=8..16: this clamp branch is not a rare doorway
		# edge case here, it is the ENTIRE home room, because THRESHOLD/
		# APPROACH's authored distance -- 5.5-7 m -- simply doesn't fit
		# between the room's own start depth and the piers). Worse, once the
		# player is far enough in that the clamp bound (13.5) sits BEHIND
		# them (z > ~13.5, reachable through the 2.4 m doorway gap itself),
		# `used_z` goes negative and the radius-preserving swing still
		# throws the camera ~5 m to one side -- but "one side" is ambiguous
		# by design (`side_sign` picks whichever side `raw_offset.x`
		# leans, which for a centered player is close to a coin flip) and
		# BOTH sides are a solid pier there. Reproduced with this file's own
		# probe (godot/tools/_probe_camera_swing.gd, camera-fix task, not
		# committed): at z=15.93 the swung target sat inside the right
		# pier's footprint, SpringArm3D's shapecast (correctly) yanked it
		# back to a 1.8 m point-blank shot, and the resulting angle was
		# 127.6 deg off dead-behind -- in front of the player, not behind.
		#
		# Fix: preserve *direction* instead of radius -- scale the whole
		# raw offset (x and z together) toward the player by the same
		# factor `k` that brings its z-component exactly onto the wall
		# bound, rather than solving for whatever sideways x makes the
		# radius match. This is a dolly-in along the authored angle (arm
		# gets shorter, aim doesn't change), the same thing a SpringArm3D's
		# own shapecast does when it shortens on contact -- so at the start
		# position it now sits 3.2 deg off dead-behind at 3.5 m (58% of
		# authored, well clear of test_camera_never_in_geometry.gd's 0.10
		# floor) instead of 53.7 deg at 6.0 m. `raw_offset.z` is always
		# positive and dominated by `distance` (a few metres) for every
		# authored yaw this zone blends across, including the full
		# mouse-look range added above (+-0.36 rad, cos >= 0.93) -- safe to
		# divide by. `k` can go negative once `used_z` does (the player is
		# deep enough that even the wall bound sits ahead of them); since
		# `raw_offset.x` is always small (it's only ever `lateral`'s own
		# contribution, ~0.15-0.55 m, THRESHOLD/APPROACH/REVEAL never lean
		# far sideways), scaling it by a `k` in [-1,1] can't reproduce the
		# old wide swing -- worst case (deep in the doorway gap) it's a few
		# centimetres either side of centered, comfortably inside the 2.4 m
		# gap and clear of both piers, not a fresh collision. That deep
		# pocket is not visited by either narrative beat near this zone
		# (screenshot-measured: threshold z=10, door z=12.53, both short of
		# where the clamp bound crosses the player's own position at
		# z~13.5) -- same honest-limit treatment test_camera_never_in_
		# geometry.gd already gives the garden gap: the common case is
		# fixed outright, the rare deep-exploration pocket degrades to a
		# close, centered shot instead of a wrong one.
		var used_z := desired_z - p.z
		var k := clampf(used_z / raw_offset.z, -1.0, 1.0)
		desired_x = clampf(p.x + raw_offset.x * k, -22.0, 21.0)

	var desired := Vector3(desired_x, height + _look_pitch * LOOK_PITCH_HEIGHT_SCALE, desired_z)

	# game.mjs:402-403 -- position damped toward `desired`, not snapped to it.
	if not _initialized:
		_smoothed_desired = desired
		_initialized = true
	else:
		var alpha := 1.0 - exp(-delta * (16.0 if Game.reduced_motion else 7.3))
		_smoothed_desired = _smoothed_desired.lerp(desired, alpha)

	global_position = target
	# SpringArm3D extends its children along its local +Z axis (verified
	# empirically -- NOT -Z, despite -Z being every other node's "forward"
	# in Godot). look_at() orients -Z toward its argument, so to make +Z
	# point at `_smoothed_desired`, look_at() the point that's
	# _smoothed_desired reflected through target instead.
	#
	# look_at() errors (rather than no-op) if origin and target coincide --
	# possible in principle if the player is wedged into a tight corner and
	# the damped desired position degenerates onto the look-at target.
	# Skip that single tick's reorientation rather than crash; the previous
	# rotation stays, imperceptible at 60Hz.
	var mirrored_desired := 2.0 * target - _smoothed_desired
	if not target.is_equal_approx(mirrored_desired):
		look_at(mirrored_desired, Vector3.UP)
	spring_arm.spring_length = target.distance_to(_smoothed_desired)

	# game.mjs:410 -- lookAt(target); SpringArm3D only translates its child,
	# so the camera's own rotation is set explicitly here every tick.
	if not camera.global_position.is_equal_approx(target):
		camera.look_at(target, Vector3.UP)
	camera.fov = CameraProfile.damp(camera.fov, fov, 5.5, delta)


## How far the shot can actually reach behind the player before it meets a
## camera-blocking wall, capped at `wanted`. One sphere cast per tick, on
## the same physics layer SpringArm3D itself watches -- this measures the
## same obstruction the arm would, just early enough to compose around it
## (see the fit block in _physics_process for why that matters).
##
## Cast HORIZONTALLY, from the player, one metre up -- not along the arm's
## own slanted line. Every camera_blocks collider in this world is a 5 m
## box standing on the ground (tools/_bootstrap_courtyard.gd's
## _wall_collider), so the clearance measured at 1 m is exactly the
## clearance the camera meets at 3 m, and measuring it on a fixed
## horizontal line keeps this independent of the height it is about to
## decide -- a cast along the arm would depend on the answer it is
## computing.
##
## PROBE_RADIUS must stay UNDER the player's own collision radius (0.32,
## scenes/player.tscn) and PROBE_Y at the height where the capsule is
## actually that wide. A first attempt used 0.40 at y=1.0 and was wrong in
## a way the sweep caught immediately: the player can stand 0.32 m from a
## wall, so a 0.40 m sphere centred on them STARTS in contact with a wall
## beside them, cast_motion returns a safe fraction of zero, and the whole
## west edge of the park (x=-22, nothing at all behind the player) reported
## no room and shot from 2.6 m directly overhead. y=0.55 is mid-capsule,
## where the radius is the full 0.32 rather than the 0.21 the hemispherical
## cap leaves at y=1.0; every camera_blocks collider is a 5 m box standing
## on the ground, so the height the clearance is measured at is free to be
## chosen for this reason alone.
##
## PROBE_RADIUS must stay UNDER the player's own collision radius (0.32,
## scenes/player.tscn) and PROBE_Y at the height where the capsule is
## actually that wide. A first attempt used 0.40 at y=1.0 and was wrong in
## a way the sweep caught immediately: the player can stand 0.32 m from a
## wall, so a 0.40 m sphere centred on them STARTS in contact with a wall
## beside them, cast_motion returns a safe fraction of zero, and the whole
## west edge of the park (x=-22, nothing at all behind the player)
## reported no room and shot from directly overhead. y=0.55 is
## mid-capsule, where the radius is the full 0.32 rather than the 0.21 the
## hemispherical cap leaves at y=1.0; every camera_blocks collider is a 5 m
## box standing on the ground, so the height the clearance is measured at
## is free to be chosen for exactly this reason.
##
## This asks "is the path behind the player clear", NOT "does the camera
## have room around it at the far end", and the difference is a real
## remaining fault, not an oversight -- see this file's own report of the
## lane-mouth frame. A fat (0.65 m) swept sphere was tried to cover both
## and made the world worse on every other measure at once (child partly
## out of frame at 47 of 928 sampled positions instead of 0, closest shot
## 1.32 m instead of 2.16, 102 neighbour pairs jumping over 1.5 m instead
## of 76), because a swept sphere stops the camera BEFORE a pinch it would
## have flown through to open ground beyond. The camera needs a clear END
## POINT, not a clear path, and those are different queries; the sweep
## measures the endpoint one (`clearance to wall`) so the gap is visible
## rather than assumed away.
##
## FLOOR, not zero: `lateral` and `lead` scale with this, so a literal zero
## would put `desired` directly above `target` and look_at() errors on a
## direction parallel to UP. 0.35 m is small enough to be a genuinely
## pinned shot and large enough that the arm is never vertical; if the
## player is somehow closer to a wall than that, SpringArm3D still trims
## the last few centimetres exactly as it always has.
const PROBE_RADIUS := 0.28
## A prop may pull the shot in only as far as this, and only if it can
## be cleared at all -- see _room_behind() for what happens when it cannot.
const PROP_MIN_ROOM := 3.0
const PROBE_Y := 0.55
const MIN_ROOM := 0.35

## How far the camera should stay from its own look-at target when the room
## behind the player cannot give it horizontally, how much height it may
## climb to get there, and how steeply it is allowed to end up looking.
## 3.2 m is comfortably outside "the child fills the frame" at REVEAL's
## 58 deg lens (the child is 1.08 m). 1.4 m of lift keeps the steepest
## forced shot below the park's own 4.2 m boundary wall. 70 deg is the
## angle past which the frame stops reading as a high follow shot and
## starts reading as a floor plan -- picked by shooting the pinned wall
## positions at several values and looking, not from the arithmetic.
const MIN_SEPARATION := 3.2
const LIFT_MAX := 1.4
const MAX_LIFT_PITCH := deg_to_rad(70.0)

## ---- ORBIT (camera-orbit task, 2026-08-30) ------------------------------
## How far around the child the shot may be turned, and how quickly.
##
## 32 deg is bounded by two things, neither of them the measurements. The
## first is test_camera_never_in_geometry.gd's "behind, not beside" -- it
## asserts the camera stays within 45 deg of dead-behind along the story
## route, and that assertion is worth more than the last few degrees of
## frame. The second matters more in the hand: player.gd walks by the
## AUTHORED yaw only (this file's class doc comment has the three call sites
## and why), so every degree the camera turns is a degree "forward" walks
## off screen-up. The existing mouse-look cone is +-20.6 deg and springs
## back; this is half again as much and does not, so it is deliberately
## close to it rather than to what the sweep says is available. The same
## sweep says a +-40 deg scan finds up to 0.46 of openness to win; +-32
## takes most of that and leaves the two bounds above intact.
const ORBIT_MAX := deg_to_rad(32.0)
const ORBIT_LAMBDA := 2.0
## Odd, so one candidate is always the authored angle itself.
const ORBIT_CANDIDATES := 11

## Scoring. `room` is round 4's own question asked in each candidate
## direction -- how much of the authored throw actually fits that way --
## SATURATED at ROOM_ENOUGH rather than measured linearly, and that shape is
## the whole design. A linear room term makes the orbit refuse every corner:
## backing toward open ground is always the direction with the most room and
## always the direction that fills the frame with the corner, so a term that
## keeps rewarding 5 m over 3.5 m beats the view term every time. Saturated,
## it says what it actually means -- "3.2 m of separation is enough, past
## that stop asking" (the same 3.2 m MIN_SEPARATION above already treats as
## enough) -- and leaves the view free to choose among the angles that clear
## the bar. Below the bar it bites hard, and it is what stops the shot
## turning into a wall it cannot back away from.
const ORBIT_ROOM_ENOUGH := 3.2
const ORBIT_ROOM_WEIGHT := 1.0
## `view` -- how much the frame would then SEE past the child.
##
## KEPT AFTER BEING TESTED AT ZERO, and the honest reading of that test is
## that it is the smaller half of this feature. A/B over the whole walkable
## plane (tools/_probe_camera_sweep.gd --step 1.0, 928 cells, everything
## else identical): at 0.9 the world has 327 cells whose frame sees under
## 0.45 of 15 m and 356 with a materially better angle going unused; at 0.0,
## 330 and 380. It also costs a little of what the clearance term below buys
## -- 371 cells with the camera inside 0.6 m of a wall against 361 -- because
## the open side and the side with room are often opposite sides.
##
## Both differences are about one percent, and the bulk of what this orbit
## actually wins comes from `room` and `clear`, not from this. It stays
## because it is the term that answers the question that was ASKED (the shot
## is pointed at a wall) rather than the one that was easy (the camera is
## standing on one), and it moves the metric it is there to move. It is not
## carrying the feature and this comment should not be read as claiming it
## does.
const ORBIT_VIEW_WEIGHT := 0.9

## ...and how far the camera ends up STANDING from a wall, which is a
## different question from how far it travelled and had to be added after
## looking at what the first version did without it. `room` saturates at
## 3.2 m, so a candidate that runs three metres PARALLEL to a wall and
## finishes half a metre off its face scores exactly as well as one that
## finishes in open ground -- and at (-20,-20) that is what the orbit chose,
## because the view term wanted the frame pointed east and the only way to
## point it east is to put the camera west, hard against the park's west
## wall. The frame that came back had the child completely hidden behind the
## boundary treeline planted just outside it. Shot and looked at; every
## other number said the cell had improved.
##
## 2.0 m for a WALL because the treelines outside every wall have no
## colliders at all (world_bounds.gd: "an unreachable collider is only a
## thing for the camera to snag on"), so nothing else in this rig can see
## them -- but they are only ever just beyond a wall, and a camera kept two
## metres off the wall face is kept away from them too.
##
## 3.0 m for a PROP, and the difference is not a fudge. A wall's collider is
## the wall; a canopy tree's is a 1 m trunk footprint under a crown about
## five metres across (world_bounds.gd's CANOPY TREES block says so
## outright, and says why -- "the whole point of a canopy is that you get to
## walk under it"). Two metres from a trunk centre is still inside the
## crown. Found the same way as the term itself: at (-20,-20) the first
## version with walls only put the camera 1.39 m from the canopy tree at
## (-17.6,-13.4) and half the frame came back as one dark branch.
const ORBIT_CLEAR_WALL := 2.0
const ORBIT_CLEAR_PROP := 3.0
const ORBIT_CLEAR_WEIGHT := 0.7

## ...and, last, whether the child can be SEEN from there at all. The
## clearance term keeps the camera from standing on things; this asks the
## different question of whether one of them ended up between the camera and
## the child, which a camera with plenty of room around it can still manage.
## One ray per candidate, on both layers, from the candidate camera to the
## child's chest -- the middle of the three body samples
## tools/_probe_camera_sweep.gd measures occlusion with.
##
## Added because the gated build without it made occlusion WORSE, which is
## the one thing this rig must never trade away: the child is what the frame
## is for. A/B over the walkable plane (--step 1.0, 928 cells): the child was
## hidden by a collider at 46 cells before any orbit, 50 with the orbit and
## no sight term, and 30 with it. On the sweep's own honest number -- both a
## collider AND a rendered thing agreeing something is in the way -- 26, 28
## and 16. So this term does not merely repay what the orbit cost; it makes
## the orbited camera better at showing the child than the un-orbited one
## was, because the orbit finally has a reason to prefer the side of the
## trunk the child is on.
##
## WHAT THIS RAY CANNOT SEE, recorded because a later round will be tempted
## to fix it the way this one was. Crowns are invisible to it: the canopy
## tree at (-17.6,-13.4) is an 11.5 m tree with a 6.7 m spread whose collider
## is, deliberately, one metre across (world_bounds.gd's CANOPY TREES block
## -- "A canopy you cannot walk under is just a wall with leaves", and layer
## 1 is the MOVEMENT layer, so a crown-sized collider would wall the player
## out of the shade the trees exist to give). Measured at the cell where that
## tree hid the child: this ray passed 4.0 m clear of the trunk.
##
## Modelling the crowns instead of the trunks was tried twice and neither
## model shipped -- see ORBIT_VIEW_TOLERANCE below, which reaches the same
## place by bounding the outcome rather than guessing at the cause.
const ORBIT_SIGHT_WEIGHT := 0.5
const ORBIT_SIGHT_CHEST := 0.85

## How much of the frame's own reach the shot is allowed to GIVE UP to gain
## the room and the clearance the terms above want. Zero, within noise.
##
## This is the constraint that had to exist and did not, and the way it was
## found is worth recording. The first build with everything else right
## turned the shot at the park's west edge from a close, steep, awkward frame
## that SHOWED the child into a well-proportioned one that did not -- the
## render at (-22,-14) came back with no child in it at all. Measured at that
## cell, window openness went 0.45 -> 0.28: the orbit had bought room and
## clearance by pointing the frame further INTO the corner, which is the one
## trade it must never make, because the whole reason to turn a shot is to
## improve what is in it.
##
## Two occlusion models were tried first and both are gone. A sphere at each
## rendered crown's centre put that tree 4.9 m clear of the sightline and let
## the orbit through; the render disagreed. The raw AABB called it blocked --
## and also called the child hidden whenever they merely stood UNDER a
## canopy, which had the rig turning 26.9 degrees away from a clean frame at
## (-10,-11) to escape a tree that was not in the way. Neither could tell
## "behind a crown" from "under one", which is the distinction that matters
## and is not cheaply available to any query this rig can afford at 60 Hz.
##
## This constraint reaches the same place without modelling occlusion at all:
## it does not know what is hiding the child, only that the frame got worse,
## which at every cell that produced a child-less shot was true and was the
## reason. Stated as a bound on the OUTCOME rather than a guess at the cause.
const ORBIT_VIEW_TOLERANCE := 0.02
## Which of world_bounds.gd's non-camera_blocks boxes are PROPS rather than
## the LANE's two wide invisible flanks. The flanks are 24 m across, are
## deliberately unrendered, and the camera is deliberately allowed to fly
## through them (their own doc comment: "there is nothing rendered out there
## for a camera to clip through") -- scoring them as things to stand clear of
## would penalise exactly the airspace the rig is meant to use. Nothing else
## in that list is anywhere near this size: the widest real prop is a tower
## at 1.35.
const ORBIT_PROP_MAX_HALF := 2.0
## What turning off the authored angle costs, at full deflection. Small, but
## it is what makes "no orbit" the answer everywhere the world is open: out
## in the park every candidate measures identically, so this is the only
## term left and it points straight back at the authored shot.
## docs/ART_DIRECTION.md's "camera placement is part of the visual identity"
## is the reason it exists at all rather than the orbit being free.
const ORBIT_CENTRE_COST := 0.12
## ...and, on top of it, HOW BAD THE AUTHORED ANGLE HAS TO BE before the
## shot turns at all. This is the term that was missing from the first
## version and it is the difference between a fix and a tax.
##
## Without it the softmax is a near-argmax over candidates whose scores
## differ by a hair almost everywhere -- the world is never perfectly flat,
## some wall is always fractionally nearer one way than the other -- so the
## measured result was a rig that turned the shot more than a degree at 84.5%
## of all 3610 walkable cells, ran to the full 32 deg clamp at some, and
## bought almost nothing for it: window openness improved at 56 cells out of
## 3610 while render geometry stood between camera and child at 888 instead
## of 631. A camera that is permanently 12 deg off its authored angle
## everywhere, to fix the tenth of the world where the angle is genuinely
## bad, is a worse camera.
##
## Gated on the margin the best candidate beats the AUTHORED one by, after
## both have paid their centre cost -- so it asks the question the developer
## asked ("the only time it is struggling is...") rather than "is anything
## fractionally better". 0.20 to start turning and 0.60 to turn fully, on
## scores that run 0-3.1: at the park's west wall the margin is 0.85 and the
## shot turns all the way; in the open park it is a few hundredths and the
## shot does not move. Measured after: 22% of cells turn more than a degree
## and the median turn in every one of the six regions is 0.0, against 84.5%
## and a 12.4 deg median in PARK south before the gate existed.
const ORBIT_ENGAGE_MIN := 0.20
const ORBIT_ENGAGE_FULL := 0.60
## Softmax temperature for the weighted mean over candidates. An argmax over
## a discrete candidate set snaps as the winner changes; a plain mean picks
## the midpoint between two good angles, which in a corner is the one angle
## facing the corner. 0.05 against scores that span ~0-2 is near enough to a
## choice to avoid the midpoint and smooth enough to slide between
## neighbouring candidates rather than jump, and ORBIT_LAMBDA is behind it
## either way.
const ORBIT_TEMPERATURE := 0.05

## The view fan: how far the frame can see past the child, in each direction
## the shot might be turned. Layer 2 (the arm's own mask) ONLY -- walls, not
## props. A trunk 4 m past the child is something to look at, and chasing
## one would have the camera swinging every time the player walked past a
## tree; a boundary wall is an absence of anything and does not move.
const VIEW_CAP := 15.0
## Horizontal half-angle of REVEAL's 58 deg vertical frame at 16:9.
const VIEW_HALF_FOV := deg_to_rad(44.6)
const VIEW_RAYS := 17
## Cast from the zone's own look-at height, not the ground: at ankle height
## the park's kerbs and planting beds read as horizons.
const VIEW_EYE_Y := 1.1

## Where the orbit deliberately does not run -- see _choose_orbit().
const ORBIT_HOME_FADE_NEAR := 6.0
const ORBIT_HOME_FADE_FAR := 10.0
## The garden seam's own exclusion, DELIBERATELY WIDER than the `lead` fade
## in _physics_process that shares its centre line (2 m there, 4 m here).
## They are answering different questions: `lead` only has to stop the pivot
## starting a metre south of the player, and is nearly harmless slightly off
## its ideal width; this has to keep a turned camera away from the gap
## corners at (11,-9)/(11,-7) that beat round 3 in five variants, and at the
## narrower width it was still handing a player standing one metre east of
## the wall half a degree of authority for every degree of orbit.
const ORBIT_SEAM_X := 4.0
const ORBIT_SEAM_Z := 4.0

var _probe_params: PhysicsShapeQueryParameters3D = null


## Which way to turn the shot, in radians off the authored angle. Zero means
## "the authored angle is the best one available", which is the answer over
## most of the world.
func _choose_orbit(p: Vector3, base_yaw: float, wanted: float, eye_y: float) -> float:
	# TWO PLACES THIS MUST NOT RUN, both of them prior rounds' scar tissue.
	#
	# The garden seam (world_bounds.gd's x=11 wall, opening z in [-9,-7]).
	# Round 3 established with measurements, not guesses, that swinging the
	# camera from a player standing in that 3.4 m gap puts the arm through
	# the corner at (11,-9) or (11,-7) in one direction or the other, in
	# every one of five variants tried. Nothing about scoring candidates
	# instead of steering them makes that geometry any wider. Excluded, and
	# the gap keeps the close, straight-on shot the flip and void fixes
	# above already tuned it to.
	#
	# The home end (z > ~6). Not because it was tried and failed, but
	# because the shot there does not come out of the ordinary path at all:
	# `desired_z`'s clamp branch below scales the whole offset by
	# `used_z / raw_offset.z` to dolly in along the authored angle, and that
	# division assumes raw_offset.z stays comfortably positive -- true for
	# the authored yaws plus the mouse-look cone, and no longer obviously
	# true with another 32 deg on top. The park is where the fault the
	# developer reported lives; the home room is a 12.8 m authored corridor
	# the player crosses in seconds. Left alone on purpose.
	var seam_x := 1.0 - LensMath.smoothstep(0.0, ORBIT_SEAM_X, absf(p.x - 11.0))
	var seam_z := 1.0 - LensMath.smoothstep(
		0.0, ORBIT_SEAM_Z, maxf(0.0, maxf(-9.0 - p.z, p.z + 7.0)))
	var authority := (1.0 - seam_x * seam_z) * (1.0 - LensMath.smoothstep(
		ORBIT_HOME_FADE_NEAR, ORBIT_HOME_FADE_FAR, p.z))
	if authority <= 0.01:
		return 0.0

	_ensure_probe()
	var fan := _view_fan(p, base_yaw)
	var offsets := PackedFloat32Array()
	var scores := PackedFloat32Array()
	var best := -INF
	var authored_landing := Vector3.ZERO
	for i in range(ORBIT_CANDIDATES):
		var psi := lerpf(-ORBIT_MAX, ORBIT_MAX, float(i) / float(ORBIT_CANDIDATES - 1))
		var turned := base_yaw + psi
		# The same shape cast _room_behind() places the shot with, asked in
		# this candidate's direction. Walls only: props get their own
		# floored treatment in _room_behind() and orbiting for a 1 m-wide
		# trunk is not something this should be doing.
		var back_c := Vector3(sin(turned), 0.0, cos(turned))
		var reach := _cast_back(p, back_c, wanted, spring_arm.collision_mask)
		var room_term := minf(reach / ORBIT_ROOM_ENOUGH, 1.0)
		var view_term := _window_openness(fan, psi)
		# Where this candidate would actually put the camera. `lateral` is
		# left out deliberately -- it is a few tenths of a metre and it
		# scales with the fit, so including it would be precision this
		# estimate does not have.
		var landing := Vector3(p.x + back_c.x * reach, eye_y, p.z + back_c.z * reach)
		if i == (ORBIT_CANDIDATES - 1) / 2:
			authored_landing = landing
		var clear_term := _clearance_score(landing.x, landing.z)
		var sight_term := 0.0 if _sight_blocked(landing, p) else 1.0
		var off_centre := psi / ORBIT_MAX
		var score := ORBIT_ROOM_WEIGHT * room_term + ORBIT_VIEW_WEIGHT * view_term \
			+ ORBIT_CLEAR_WEIGHT * clear_term + ORBIT_SIGHT_WEIGHT * sight_term \
			- ORBIT_CENTRE_COST * off_centre * off_centre
		offsets.append(psi)
		scores.append(score)
		best = maxf(best, score)

	var total := 0.0
	var weighted := 0.0
	for i in range(offsets.size()):
		# Subtracting `best` first is not cosmetic: exp() of a raw score over
		# a 0.05 temperature overflows to inf and the mean comes back NaN.
		var w := exp((scores[i] - best) / ORBIT_TEMPERATURE)
		total += w
		weighted += w * offsets[i]
	if total <= 0.0:
		return 0.0
	# ORBIT_CANDIDATES is odd so the middle one IS the authored angle, which
	# is what makes this margin exactly "how much better than doing nothing".
	var engage := LensMath.smoothstep(
		ORBIT_ENGAGE_MIN, ORBIT_ENGAGE_FULL, best - scores[(ORBIT_CANDIDATES - 1) / 2])
	var turn := clampf(weighted / total, -ORBIT_MAX, ORBIT_MAX) * engage * authority

	# ---- AND IT HAS TO BE ABLE TO SWING THERE ----------------------------
	# Every measurement above is about where the camera would END UP. None of
	# them is about the path it sweeps to get there, and that path is what
	# beat round 3 at the garden corners and what beat the first version of
	# this orbit at the lane mouth.
	#
	# Found by test_camera_never_in_geometry.gd, which is the whole reason
	# that test is worth having: one tick of the story route, player at
	# (5.68,-7.19), the camera threading the corner where the lane's east
	# wall (x=5, z -4..8) meets the park's north wall (x 5..11.5, z=-4). Both
	# ENDS were legal -- the authored shot sits in open park east of the lane
	# and the turned one is a perfectly good spot 8 m away inside it -- and
	# the line between them goes through the corner post. SpringArm3D could
	# not save it either: the arm casts from the look-at pivot at 1.1 m and
	# threaded the same corner the head-height ray at 1.5 m hit.
	#
	# So: cast between the two ENDS of the swing, on the arm's own layer, and
	# if a wall stands between them halve the turn and ask again. The shot
	# turns as far as it can get to and no further; where it cannot get
	# anywhere it stays authored, which is exactly the answer round 3 was
	# unable to give.
	#
	# ANCHORED AT THE AUTHORED POSITION, NOT THE LIVE CAMERA, and that choice
	# is deliberate. Casting from `camera.global_position` was tried first
	# and works in play, but it makes the orbit depend on where the camera
	# happens to have come FROM -- so a teleport (which is how
	# tools/_probe_camera_sweep.gd measures 3610 cells, and how every play
	# test settles a position) arrives with the camera on the far side of the
	# world and the ray blocked by everything, and the whole feature measures
	# as absent. A rig whose answer cannot be measured is a rig nobody can
	# check. Both ends of this version are functions of the player's position
	# alone.
	#
	# It is a chord across an arc, so it is an approximation, and the arc
	# bows outward from it. What it is not is a guess: it is the same two
	# endpoints the failure had, tested against the same layer.
	#
	# ---- AND IT MUST NOT LOSE THE CHILD, OR THE FRAME, TO GET THERE -----
	# Two conditions, found by two different cells, and each one is the only
	# thing that catches its own.
	#
	# The first is the child. At (11,-17) the shot turned the full 32 degrees
	# into an angle whose sightline runs down the length of the canopy tree
	# at (9.6,-14.6) -- a shot that measured better on every other term with
	# a trunk squarely over the child. Conditional on the authored shot being
	# clear, so that where the authored angle ALREADY hides the child (behind
	# the tower staircase at (-6,-15), say) it says nothing and the orbit does
	# the job it exists for. It only ever forbids trading a visible child for
	# a hidden one.
	#
	# The second is the frame. `room` and `clear` are about
	# where the CAMERA stands; left to themselves they will happily buy a
	# roomier position by pointing the frame further into a corner, and at
	# the park's west edge that is exactly what they did -- window openness
	# 0.45 -> 0.28, and the rendered frame came back with no child in it.
	# See ORBIT_VIEW_TOLERANCE for the two occlusion models that were tried
	# and rejected before this one.
	#
	# Half a metre apart, these two cells needed different guards: (10.5,-17.5)
	# keeps its full turn under both and its frame is the best of the six
	# hardest turns in the world. That is the argument for bounding outcomes
	# separately rather than looking for the one rule that covers everything.
	var authored_view := _window_openness(fan, 0.0)
	var authored_shows_child := not _sight_blocked(authored_landing, p)
	while absf(turn) > 1e-3:
		var turned_star := base_yaw + turn
		var back_star := Vector3(sin(turned_star), 0.0, cos(turned_star))
		var reach_star := _cast_back(p, back_star, wanted, spring_arm.collision_mask)
		var landing_star := Vector3(
			p.x + back_star.x * reach_star, eye_y, p.z + back_star.z * reach_star)
		var path := PhysicsRayQueryParameters3D.create(authored_landing, landing_star)
		path.collision_mask = spring_arm.collision_mask
		path.exclude = _probe_params.exclude
		var can_swing := get_world_3d().direct_space_state.intersect_ray(path).is_empty()
		var keeps_view := _window_openness(fan, turn) >= authored_view - ORBIT_VIEW_TOLERANCE
		var keeps_child := not authored_shows_child or not _sight_blocked(landing_star, p)
		if can_swing and keeps_view and keeps_child:
			return turn
		turn *= 0.5
	return 0.0


## Is anything between a candidate camera position and the child's chest?
## Layers 1 AND 2, unlike everywhere else in this file -- a tower or a trunk
## hides the child exactly as completely as a wall does, and the reason props
## are off the arm's own mask is that they should not STOP the camera, not
## that they are see-through.
func _sight_blocked(from: Vector3, p: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		from, Vector3(p.x, p.y + ORBIT_SIGHT_CHEST, p.z))
	query.collision_mask = 3
	query.exclude = _probe_params.exclude
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## How much room a candidate camera position has AROUND it, as a fraction of
## how much it needs: 1.0 is "standing clear of everything", 0.0 is "inside
## something". Measured against WorldBounds.COLLIDERS' own boxes rather than
## by another physics query -- they are the exact boxes
## tools/_bootstrap_courtyard.gd builds the bodies from, every one of them is
## 5 m tall standing on the ground so a camera under 5 m gets no vertical
## relief, and 30 box tests are cheaper than one shape cast.
## tools/_probe_camera_sweep.gd's own `clear` column is the wall half of the
## same arithmetic, which is what makes the sweep's before/after comparable.
func _clearance_score(x: float, z: float) -> float:
	var worst := 1.0
	for box in WorldBounds.COLLIDERS:
		var wall: bool = box.get("camera_blocks", false)
		if not wall and (box["half_x"] > ORBIT_PROP_MAX_HALF or box["half_z"] > ORBIT_PROP_MAX_HALF):
			continue
		var dx: float = maxf(absf(x - box["x"]) - box["half_x"], 0.0)
		var dz: float = maxf(absf(z - box["z"]) - box["half_z"], 0.0)
		var enough := ORBIT_CLEAR_WALL if wall else ORBIT_CLEAR_PROP
		worst = minf(worst, sqrt(dx * dx + dz * dz) / enough)
	return worst


## How far the world runs in each direction the frame might be pointed,
## as a fraction of VIEW_CAP. Indexed the same way _window_openness() reads
## it: sample i is at offset lerp(-span, span, i/(n-1)) off `base_yaw`.
##
## One fan, shared by every candidate, rather than one per candidate: the
## directions a turned frame covers are the same set of world directions
## whichever candidate asks for them, only the window over them moves.
func _view_fan(p: Vector3, base_yaw: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var space := get_world_3d().direct_space_state
	var origin := Vector3(p.x, VIEW_EYE_Y, p.z)
	var span := ORBIT_MAX + VIEW_HALF_FOV
	for i in range(VIEW_RAYS):
		var psi := lerpf(-span, span, float(i) / float(VIEW_RAYS - 1))
		var yaw := base_yaw + psi
		# The rig's own `forward` for that yaw -- away from the camera, past
		# the child.
		var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * VIEW_CAP)
		query.collision_mask = spring_arm.collision_mask
		query.exclude = _probe_params.exclude
		var hit := space.intersect_ray(query)
		out.append(1.0 if hit.is_empty() else origin.distance_to(hit["position"]) / VIEW_CAP)
	return out


## Mean reach across the frame a shot turned by `centre` would cover. A
## mean, not a minimum: a shot with a wall down one edge and the length of
## the park down the other is a good shot, and a minimum scores it the same
## as one facing the wall square on -- which is the whole difference this
## orbit exists to find.
func _window_openness(fan: PackedFloat32Array, centre: float) -> float:
	var span := ORBIT_MAX + VIEW_HALF_FOV
	var total := 0.0
	var n := 0
	for i in range(fan.size()):
		var psi := lerpf(-span, span, float(i) / float(fan.size() - 1))
		if absf(psi - centre) <= VIEW_HALF_FOV:
			total += fan[i]
			n += 1
	return total / maxf(float(n), 1.0)


func _ensure_probe() -> void:
	if _probe_params == null:
		var sphere := SphereShape3D.new()
		sphere.radius = PROBE_RADIUS
		_probe_params = PhysicsShapeQueryParameters3D.new()
		_probe_params.shape = sphere
		_probe_params.collide_with_areas = false
		_probe_params.collide_with_bodies = true
	_probe_params.exclude = [Game.player.get_rid()] if is_instance_valid(Game.player) else []


func _room_behind(p: Vector3, back: Vector3, wanted: float) -> float:
	_ensure_probe()
	# Walls (the arm's own layer) may pin the shot all the way in: there is
	# genuinely nowhere else for it to be.
	var wall_room := _cast_back(p, back, wanted, spring_arm.collision_mask)
	# Props (layer 1 only -- trunks, towers, the bench, the staircase) get a
	# floor instead. They are the reason the child was hidden from 27% of
	# the southern park's standing positions, so the camera does have to
	# come in front of them, but they are also 1 m wide, so a shot that
	# slams all the way in every time one crosses behind the player pumps.
	# Measured on the driven route: unbounded, this pulled the worst
	# transient angle off-behind to 48.3 deg -- past the 45 deg
	# test_camera_never_in_geometry.gd asserts -- and doubled the typical
	# per-tick camera motion. Floored, the dolly is a move between two shots
	# that both read, not a slam onto the child's back.
	#
	# The floor is also what keeps the prop layer's honesty problem
	# harmless: every layer-1 box is a uniform 2.4 m tall whatever it
	# renders as (world_bounds.gd's own warning about putting props on the
	# camera layer), so the 0.9 m bench and the open staircase "block"
	# sightlines that really pass over them. Bounded at PROP_MIN_ROOM the
	# worst that costs is a shot that comes in to 3 m near a bench.
	var prop_room := _cast_back(p, back, wanted, 1)
	if prop_room < PROP_MIN_ROOM:
		# Too close to compose in front of. Leave the shot at its authored
		# length and accept that this prop is in the way -- do NOT clamp
		# `room` up to the floor, which is what a first version did and
		# which put the camera INSIDE the left tower at (-3.4,-16): the
		# floor pushed the shot to 3 m behind a player standing 1.85 m
		# south of a 2.7 m-wide box, layer 1 is not on the arm's own mask
		# so nothing stopped it, and the rendered frame came back solid
		# black. Caught by shooting it and looking; every number in the
		# sweep said that cell had improved.
		prop_room = wanted
	return maxf(minf(wall_room, prop_room), MIN_ROOM)


func _cast_back(p: Vector3, back: Vector3, wanted: float, mask: int) -> float:
	_probe_params.collision_mask = mask
	_probe_params.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, p.y + PROBE_Y, p.z))
	_probe_params.motion = back * wanted
	var hit: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(_probe_params)
	if hit.size() < 1:
		return wanted
	return wanted * hit[0]

