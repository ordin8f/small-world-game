extends GdUnitTestSuite
## Every interaction in this game used to be silent: sandbox.gd, ball.gd,
## imagination_prop.gd, pocket_treasure.gd and interaction_zone.gd between
## them contained not one animation call, so the child built a sandcastle,
## pocketed a keepsake and carried a ball home without ever moving their
## arms. This suite is the guard against that coming back.
##
## Every assertion below reads CharacterVisual.current_clip(), which returns
## the AnimationPlayer's OWN assigned_animation rather than the script's
## bookkeeping -- so a test here fails if the clip was recorded but never
## played. And because play_pose() falls back to "idle" for a name that
## isn't in the .glb, asserting the exact expected clip also catches a
## MISSPELLED clip name, not just a missing call: a wrong name lands on
## "idle" and the assertion reports "idle" against what was expected. That
## is the specific defect this suite exists for -- "wave" sat in
## CHARACTER_DATA as Arun's talk pose for the life of the NPC feature, was
## never a clip in the pack at all, and nothing noticed.

const PICKUP_HOLD_FRAMES := 40   ## comfortably past pick-up's own 0.33s hold
const SETTLE_FRAMES := 12
const TIME_SCALE := 8.0      ## same acceleration test_playthrough.gd uses for the auto-timers
const MAX_WAIT_TICKS := 600  ## ceiling on ball.gd's own 1.8s flight tween


func after_test() -> void:
	Engine.time_scale = 1.0


# ------------------------------------------------------ the clip name audit --

## The test that would have caught "wave" on the day it was written, with
## nobody having to maintain a list: it walks CHARACTER_DATA itself and
## checks every clip name any character references against the animations
## actually present in that character's own .glb.
func test_every_clip_name_in_character_data_exists_in_that_characters_glb() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)

	var checked := 0
	for character_name: String in CharacterVisual.CHARACTER_DATA:
		var visual: CharacterVisual = _find_visual(runner, character_name)
		assert_object(visual).is_not_null()
		var data: Dictionary = CharacterVisual.CHARACTER_DATA[character_name]
		for key in ["reaction_clip", "talk_pose"]:
			if not data.has(key):
				continue
			var clip: String = data[key]
			checked += 1
			assert_bool(visual.has_clip(clip)) \
				.override_failure_message("%s's %s is '%s', which is not a clip in %s" % [
					character_name, key, clip, data["glb_path"],
				]) \
				.is_true()
	# Guards the guard: if CHARACTER_DATA is ever restructured so this loop
	# silently checks nothing, this fails rather than passing vacuously.
	assert_int(checked).is_greater_equal(5)


## The same audit for the clip names that live in the interaction scripts
## rather than in CHARACTER_DATA. Unlike the loop above this one IS a
## maintained list -- but a wrong entry here fails loudly, which is strictly
## better than the silent idle fallback it replaces.
func test_every_clip_name_the_interaction_scripts_reference_exists() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	assert_object(visual).is_not_null()

	var referenced := {
		"ball.gd CARRY_CLIP": Ball.CARRY_CLIP,
		"ball.gd PICKUP_CLIP": Ball.PICKUP_CLIP,
		"ball.gd RETURN_CLIP": Ball.RETURN_CLIP,
		"sandbox.gd PAT_CLIP": Sandbox.PAT_CLIP,
		"pocket_treasure.gd POCKET_CLIP": PocketTreasure.POCKET_CLIP,
		"imagination_prop.gd WONDER_CLIP": ImaginationProp.WONDER_CLIP,
		"interaction_zone.gd DEFAULT_POSE": InteractionZone.DEFAULT_POSE,
		"swing.gd RIDE_CLIP": Swing.RIDE_CLIP,
	}
	for where: String in referenced:
		var clip: String = referenced[where]
		assert_bool(visual.has_clip(clip)) \
			.override_failure_message("%s is '%s', which is not a clip in the character .glb" % [where, clip]) \
			.is_true()

	for zone_name: String in InteractionZone.ZONE_DATA:
		var pose: String = InteractionZone.ZONE_DATA[zone_name].get("pose", InteractionZone.DEFAULT_POSE)
		if pose == "":
			continue  # zones whose animation belongs to ball.gd -- see ZONE_DATA
		assert_bool(visual.has_clip(pose)) \
			.override_failure_message("interaction zone %s's pose is '%s', which is not a clip" % [zone_name, pose]) \
			.is_true()


## The clips that are continuous STATES must loop. Godot's glTF importer
## defaults every imported clip to LOOP_NONE, so before character_visual.gd
## set this, one 0.67s walk cycle played and the child then slid along frozen
## mid-stride for as long as the key was held -- which is exactly what the
## developer reported: "walk animation doesn't properly work, it shows
## initially but then it doesn't repeat".
##
## Every name below is spelled out rather than read from LOOPING_CLIPS /
## HELD_POSE_CLIPS / ONE_SHOT_CLIPS: emptying or rewriting those constants
## would otherwise change both sides at once and this test would pass while
## checking nothing.
func test_the_continuous_state_clips_loop() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var anim: AnimationPlayer = visual.get("_anim_player")
	assert_object(anim).is_not_null()

	for clip: String in [
		"idle", "walk", "sprint", "fall",
		"wheelchair-move-forward", "wheelchair-move-back",
		"wheelchair-move-left", "wheelchair-move-right",
		"crouch", "sit", "drive", "static",
		"holding-left", "holding-right", "holding-both", "wheelchair-sit",
	]:
		assert_int(anim.get_animation(clip).loop_mode) \
			.override_failure_message("%s does not loop -- a state clip that stops is a frozen child" % clip) \
			.is_not_equal(Animation.LOOP_NONE)


## ...and the clips that are EVENTS must not, which is not merely tidiness:
## "pick-up" ends 0.23 quaternion distance from where it starts and "die"
## 0.35, so looping either would visibly snap the child back every third of a
## second. Blanket-looping the whole library to fix walk would have traded one
## bug for sixteen.
func test_the_one_shot_clips_do_not_loop() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var anim: AnimationPlayer = visual.get("_anim_player")

	for clip: String in [
		"jump", "die", "pick-up", "emote-yes", "emote-no",
		"attack-melee-left", "attack-melee-right",
		"attack-kick-left", "attack-kick-right",
		"interact-left", "interact-right",
		"holding-left-shoot", "holding-right-shoot", "holding-both-shoot",
		"wheelchair-look-left", "wheelchair-look-right",
	]:
		assert_int(anim.get_animation(clip).loop_mode) \
			.override_failure_message("%s loops -- it is a one-shot and will restart forever" % clip) \
			.is_equal(Animation.LOOP_NONE)


## Nothing in the pack may be left unclassified: a clip that is in neither
## set is a clip whose loop mode nobody decided, and the next one Kenney adds
## should fail here rather than quietly inherit LOOP_NONE.
func test_every_clip_in_the_pack_is_classified() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var anim: AnimationPlayer = visual.get("_anim_player")

	var classified: Array = []
	classified.append_array(CharacterVisual.LOOPING_CLIPS)
	classified.append_array(CharacterVisual.HELD_POSE_CLIPS)
	classified.append_array(CharacterVisual.ONE_SHOT_CLIPS)

	var unclassified: Array = []
	for clip: String in anim.get_animation_list():
		if clip == "RESET":
			continue  # Godot's own generated rest-pose track, never played
		if not classified.has(clip):
			unclassified.append(clip)

	assert_array(unclassified) \
		.override_failure_message("clips with no decided loop mode: %s" % [unclassified]) \
		.is_empty()
	# ...and no name in the sets that isn't a real clip.
	for clip: String in classified:
		assert_bool(anim.has_animation(clip)) \
			.override_failure_message("'%s' is classified but is not a clip in the pack" % clip) \
			.is_true()


## The symptom itself, not the setting behind it: walk for well past one clip
## length and the legs must still be moving. This is the test that would have
## caught the original report -- asserting loop_mode alone would not, because
## a future change could set loop_mode correctly and still break the cycle
## some other way (a stray play() every frame, a paused mixer, a pose hold
## that never expires).
func test_walking_past_one_clip_length_keeps_cycling_instead_of_freezing() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var skeleton: Skeleton3D = visual.get("_skeleton")
	var anim: AnimationPlayer = visual.get("_anim_player")
	var walk_length: float = anim.get_animation("walk").length

	Game.start_episode(0.0)
	await runner.simulate_frames(SETTLE_FRAMES)
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_str(visual.current_clip()).is_equal("walk")

	# Sample the leg over a window that starts AFTER several clip lengths have
	# already elapsed. Before the fix the child froze on walk's last frame, so
	# every sample in this window was identical no matter how long the window.
	var tree := Engine.get_main_loop() as SceneTree
	var settle_frames := int(walk_length * 4.0 * Engine.physics_ticks_per_second)
	for _i in range(settle_frames):
		await tree.physics_frame
	var elapsed := float(settle_frames) / Engine.physics_ticks_per_second

	# Sample the playhead and the leg together over two further clip lengths.
	var leg_id := skeleton.find_bone("leg-left")
	var legs: Array[Quaternion] = []
	var deepest := 0.0
	var wraps := 0
	var previous := anim.current_animation_position
	for _i in range(int(walk_length * 2.0 * Engine.physics_ticks_per_second)):
		var position: float = anim.current_animation_position
		deepest = maxf(deepest, position)
		if position < previous - 0.001:
			wraps += 1
		previous = position
		legs.append(skeleton.get_bone_pose_rotation(leg_id))
		await tree.physics_frame
	runner.simulate_action_release("move_forward")

	# 1. The playhead gets deep into the clip. This is what separates a real
	#    loop from the tempting wrong fix -- dropping the change-guard and
	#    re-calling play() every physics frame. That "works" in the sense that
	#    the pose keeps changing, so a leg-moved-at-all assertion passes it,
	#    but the playhead never leaves the first frame or two and the child
	#    twitches in place instead of walking.
	assert_float(deepest) \
		.override_failure_message("after %.2fs of walking the playhead never got past %.3fs of walk's %.2fs -- the clip is being restarted, not looped" % [
			elapsed, deepest, walk_length,
		]) \
		.is_greater(walk_length * 0.6)

	# 2. It wraps. A one-shot that simply hasn't finished yet would satisfy
	#    (1) once and never again.
	assert_int(wraps) \
		.override_failure_message("the walk playhead never wrapped in %.2fs of walking -- it is playing once and stopping" % (walk_length * 2.0)) \
		.is_greater(0)

	# 3. And the body actually moves, measured off the skeleton rather than
	#    off the mixer's own bookkeeping.
	var spread := 0.0
	for q in legs:
		spread = maxf(spread, 1.0 - absf(legs[0].dot(q)))
	assert_float(spread) \
		.override_failure_message("after %.2fs of walking (%.1f clip lengths) leg-left barely moved (%.5f) -- the walk cycle has frozen on its last frame" % [
			elapsed, elapsed / walk_length, spread,
		]) \
		.is_greater(0.01)


## The fallback still has to be a fallback: a bad name must not crash a
## child's afternoon, it must warn and stand there.
func test_an_unknown_clip_name_falls_back_to_idle_instead_of_crashing() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	visual.play_pose("definitely-not-a-clip", 1.0)
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_str(visual.current_clip()).is_equal("idle")


# ------------------------------------------------------------------- the ball --

func test_picking_up_the_ball_plays_the_pick_up_clip_and_starts_the_carry() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var ball: Node3D = runner.scene().get_node("Ball")

	await _advance_to_find_ball(runner)
	assert_bool(Game.dispatch("ball_picked_up")).is_true()
	await runner.simulate_frames(SETTLE_FRAMES)

	assert_bool(ball.get("carrying")).is_true()
	assert_str(visual.current_clip()).is_equal("pick-up")
	assert_str(visual.arm_pose_clip()).is_equal("holding-both")


## The point of the carry being an arm OVERLAY rather than a clip: the child
## keeps hold of the ball while their legs walk and run. A carry implemented
## as a one-shot, or as a clip the locomotion machine can overwrite, fails
## here -- which is exactly what "the child walks with empty hands while
## holding a ball" looked like.
func test_the_carry_survives_walking_and_running() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var player: Node3D = Game.player

	await _advance_to_find_ball(runner)
	assert_bool(Game.dispatch("ball_picked_up")).is_true()
	await runner.simulate_frames(PICKUP_HOLD_FRAMES)

	# Walking.
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_bool(player.get("moving")).is_true()
	assert_str(visual.current_clip()).is_equal("walk")
	assert_str(visual.arm_pose_clip()).is_equal("holding-both")

	# Running.
	runner.simulate_action_press("run")
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_str(visual.current_clip()).is_equal("sprint")
	assert_str(visual.arm_pose_clip()).is_equal("holding-both")

	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_str(visual.current_clip()).is_equal("idle")
	assert_str(visual.arm_pose_clip()).is_equal("holding-both")


## Asserting on the requested clip name only proves an intention. This walks
## the rest of the chain: the clip name became a real sampled pose, that pose
## is on a live modifier parented to the real Skeleton3D at the real arm bone
## indices, the modifier is switched on and fully faded in, and running it
## puts the arms exactly where the carry clip holds them.
##
## It cannot simply read the arm bones back off the skeleton, which was the
## obvious first version and is a trap: Skeleton3D saves and restores bone
## poses around its modifier pass, so get_bone_pose_rotation() -- and
## get_bone_global_pose(), even after force_update_all_bone_transforms() --
## both report the ANIMATED pose no matter what any modifier did. Only the
## skinning that actually gets drawn uses the modified result, and there is
## no public getter for it. The first version of this test asserted on that
## read, failed against a feature that demonstrably works on screen, and
## would equally have "passed" a broken one had the expected value been
## copied from the same read. tools/interaction_shots.ps1 is the check that
## the drawn result is right; this is the check that everything feeding it is.
func test_the_carry_pose_actually_reaches_the_arm_bones_while_walking() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()

	await _advance_to_find_ball(runner)
	assert_bool(Game.dispatch("ball_picked_up")).is_true()
	await runner.simulate_frames(PICKUP_HOLD_FRAMES)
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(PICKUP_HOLD_FRAMES)  # long enough for the overlay to fully ease in

	assert_str(visual.current_clip()).is_equal("walk")

	var skeleton: Skeleton3D = visual.get("_skeleton")
	assert_object(skeleton).is_not_null()
	var modifier: ArmPoseModifier = visual.get("_arm_modifier")
	assert_object(modifier) \
		.override_failure_message("no arm-pose modifier was ever built -- nothing can hold the carry") \
		.is_not_null()
	# A SkeletonModifier3D that is not a direct child of the skeleton is
	# never run by it, silently.
	assert_object(modifier.get_parent()).is_same(skeleton)
	assert_bool(modifier.active) \
		.override_failure_message("the carry modifier is inactive -- it will not run") \
		.is_true()
	assert_float(modifier.influence) \
		.override_failure_message("the carry only faded in to %.2f -- the arms never fully arrive" % modifier.influence) \
		.is_greater(0.99)

	# Both arms, named here rather than read from CharacterVisual.ARM_BONES:
	# emptying that constant leaves a modifier that holds nothing, and a loop
	# over it would then assert nothing and pass.
	assert_int(modifier.bone_ids.size()) \
		.override_failure_message("the carry modifier holds %d bones, not the two arms" % modifier.bone_ids.size()) \
		.is_equal(2)

	# Run the modifier's own pass and read the bones it just wrote, before
	# the skeleton restores them.
	modifier._process_modification()
	var anim: AnimationPlayer = visual.get("_anim_player")
	var carry: Animation = anim.get_animation(Ball.CARRY_CLIP)
	for bone_name: String in ["arm-left", "arm-right"]:
		var expected := _bone_rotation_in(carry, bone_name)
		var actual := skeleton.get_bone_pose_rotation(skeleton.find_bone(bone_name))
		assert_float(absf(actual.dot(expected))) \
			.override_failure_message("%s ends up at %s, not the carry pose's %s" % [bone_name, actual, expected]) \
			.is_greater(0.999)

	# ...and it is genuinely an overlay, not the whole body: the LEGS must
	# still be walking. Sampled twice rather than compared against the rest
	# pose, because a walk cycle passes through rest twice per stride and a
	# single sample could land there by luck. If the carry had been played as
	# an ordinary clip, the legs would be pinned at holding-both's rest
	# rotation and these two samples would be identical.
	var leg_id := skeleton.find_bone("leg-left")
	var leg_before := skeleton.get_bone_pose_rotation(leg_id)
	await runner.simulate_frames(8)
	var leg_after := skeleton.get_bone_pose_rotation(leg_id)
	runner.simulate_action_release("move_forward")
	assert_float(absf(leg_before.dot(leg_after))) \
		.override_failure_message("leg-left did not move between frames while walking -- the carry replaced the walk cycle instead of layering over it") \
		.is_less(0.9999)


func test_giving_the_ball_back_ends_the_carry_and_plays_the_return_clip() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()

	await _advance_to_find_ball(runner)
	assert_bool(Game.dispatch("ball_picked_up")).is_true()
	await runner.simulate_frames(PICKUP_HOLD_FRAMES)
	assert_str(visual.arm_pose_clip()).is_equal("holding-both")

	assert_bool(Game.dispatch("ball_returned")).is_true()
	await runner.simulate_frames(SETTLE_FRAMES)

	assert_str(visual.current_clip()).is_equal("interact-right")
	assert_str(visual.arm_pose_clip()).is_equal("")


func test_a_fresh_run_does_not_leave_the_child_holding_an_invisible_ball() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()

	await _advance_to_find_ball(runner)
	assert_bool(Game.dispatch("ball_picked_up")).is_true()
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_str(visual.arm_pose_clip()).is_equal("holding-both")

	Game.start_episode(0.0)  # "Play again" mid-carry
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_str(visual.arm_pose_clip()).is_equal("")


# ------------------------------------------------- the free-roam interactions --

func test_patting_the_sand_makes_the_child_crouch() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var sandbox: Node3D = runner.scene().find_child("Sandbox", true, false)
	assert_object(sandbox).is_not_null()

	Game.start_episode(0.0)
	Game.player.global_position = sandbox.global_position
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_object(Game.active_free_interactable).is_same(sandbox)

	var mounds_before: int = sandbox.get("_mound_count")
	Game.interact()
	await runner.simulate_frames(SETTLE_FRAMES)

	# The mound still appears -- the animation is alongside the mechanic,
	# never in front of it.
	assert_int(sandbox.get("_mound_count")).is_greater(mounds_before)
	assert_str(visual.current_clip()).is_equal("crouch")


func test_pocketing_a_treasure_plays_the_pick_up_clip() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var marble: Node3D = runner.scene().find_child("Marble", true, false)
	assert_object(marble).is_not_null()

	Game.start_episode(0.0)
	Game.player.global_position = marble.global_position
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_object(Game.active_free_interactable).is_same(marble)

	var found_before: int = Game.treasures_found
	Game.interact()
	await runner.simulate_frames(SETTLE_FRAMES)

	assert_int(Game.treasures_found).is_equal(found_before + 1)
	assert_str(visual.current_clip()).is_equal("pick-up")


func test_an_imagination_transform_makes_the_child_react() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	var crate: Node3D = runner.scene().find_child("CrateProp", true, false)
	assert_object(crate).is_not_null()

	Game.start_episode(0.0)
	Game.player.global_position = crate.global_position + Vector3(0.0, 0.0, 1.0)
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_object(Game.active_free_interactable).is_same(crate)

	Game.interact()
	await runner.simulate_frames(SETTLE_FRAMES)

	assert_bool(crate.get("_imagined")).is_true()
	assert_str(visual.current_clip()).is_equal("emote-yes")


## The rail beats, not just the free-roam layer: an interaction zone must
## animate too, so no beat of the authored afternoon is inert.
func test_an_interaction_zone_beat_plays_its_own_pose() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var visual := CharacterVisual.of_player()
	# By path, not find_child: the courtyard has its own Marker3D named
	# "Watch" and find_child returns that one.
	var watch: InteractionZone = runner.scene().get_node("InteractionZones/Watch")
	assert_object(watch).is_not_null()

	Game.start_episode(0.0)
	Game.player.global_position = watch.global_position
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_object(Game.active_zone).is_same(watch)

	Game.interact()
	await runner.simulate_frames(SETTLE_FRAMES)

	# The beat still fires at the same moment -- the pose is alongside it.
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.OBSERVED)
	# The expected clip is spelled out here rather than read back out of
	# ZONE_DATA -- asserting a value against the very constant that produced
	# it would pass no matter what either of them said.
	assert_str(visual.current_clip()).is_equal("emote-yes")


# ---------------------------------------------------------------- the verbs --

func test_balancing_on_the_edging_holds_the_arms_out_and_drops_them_on_dismount() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var visual := CharacterVisual.of_player()

	Game.start_episode(0.0)
	# Same mount point test_player_verbs.gd and verb_shots.gd both use.
	player.global_position = Vector3(-4.15, 0.0, 13.2)
	await _wait_for_verb(runner, player, "WALL_WALKING", 90)

	# "static" spelled out rather than read back from player.BALANCE_ARM_CLIP:
	# comparing a value against the very constant that set it proves nothing.
	assert_str(visual.arm_pose_clip()) \
		.override_failure_message("balancing along the edging with the arms hanging down") \
		.is_equal("static")

	# Walking along it must not drop the arms -- the legs keep their walk
	# cycle, the arms stay out.
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_forward")
	assert_str(visual.arm_pose_clip()).is_equal("static")
	assert_str(visual.current_clip()).is_equal("walk")

	# Lean past the edging's half-width, which is what sustained sideways
	# input does, and let _process_wall_walk() notice and dismount on its
	# own. Setting the lean rather than pressing a key avoids reproducing
	# DriveRoute's camera-yaw-to-keys inversion just to find which key maps
	# to +x at this z; calling _start_wall_dismount() directly instead would
	# NOT work, because a dismount with no lean lands the child back inside
	# the mount range and the very next ground tick re-mounts them.
	player.set("_wall_offset", WorldAffordances.EDGING_HALF_WIDTH + 0.2)
	await _wait_for_verb(runner, player, "GROUND", 120)
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_str(visual.arm_pose_clip()) \
		.override_failure_message("still balancing on solid ground") \
		.is_equal("")


func test_riding_the_swing_sits_the_child_on_the_seat_not_inside_it() -> void:
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(2)
	var player: Node3D = Game.player
	var visual := CharacterVisual.of_player()
	var swing: Node3D = runner.scene().find_child("Swing", true, false)
	assert_object(swing).is_not_null()

	Game.start_episode(0.0)
	player.global_position = swing.global_position + Vector3(0.6, 0.0, 0.0)
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_object(Game.active_free_interactable).is_same(swing)

	# Where the body sits relative to the player's own origin when simply
	# standing there. Sitting on the seat has to keep that same relationship
	# -- the swing puts the origin AT the seat top, so a body that hangs
	# lower than this is a body inside the seat.
	var standing_offset := _root_bone_offset_from_origin(visual, player)

	Game.interact()
	await runner.simulate_frames(SETTLE_FRAMES)
	assert_bool(swing.get("_riding")).is_true()
	# "drive" spelled out, not read back from Swing.RIDE_CLIP. The first
	# version of this line asserted against the constant and was the one
	# assertion in this suite that survived its own mutation: swapping
	# RIDE_CLIP for "idle" changed both sides at once and the test stayed
	# green while the child rode the swing standing up.
	assert_str(visual.current_clip()).is_equal("drive")

	# Kenney's seated clips translate the root bone down to seat height,
	# assuming the seat is at the origin. Applied to a child whose feet are
	# already ON the seat, that sinks them ~0.24m into it. character_visual.gd
	# lifts the model by the clip's own root track to cancel that.
	#
	# Measured off the skeleton, not the mesh AABB: a skinned MeshInstance3D
	# keeps its rest-pose AABB regardless of what the bones are doing, so an
	# AABB-based check would report the same number sunk or not, and pass
	# either way.
	var riding_offset := _root_bone_offset_from_origin(visual, player)
	assert_float(riding_offset) \
		.override_failure_message("the rider's body hangs %.3f m below its own origin (standing reference %.3f) -- the seated clip's root drop is not being compensated, so the child is inside the seat rather than on it" % [
			-riding_offset, standing_offset,
		]) \
		.is_greater(standing_offset - 0.06)


# ------------------------------------------------------------------ helpers --

## The player's CharacterVisual is a child NAMED "Player" of a
## CharacterBody3D also named "Player" (that shared name is how
## CHARACTER_DATA is keyed), so a plain find_child returns the body, not the
## visual.
func _find_visual(runner: GdUnitSceneRunner, character_name: String) -> CharacterVisual:
	if character_name == "Player":
		return CharacterVisual.of_player()
	return runner.scene().find_child(character_name, true, false) as CharacterVisual


## ARRIVE -> FIND_BALL, skipping the 2.6s ball_kicked schedule (this suite
## is about what the child's body does at each beat, not the rail's timing,
## which test_playthrough.gd already covers end to end) but NOT the flight
## tween. ball_landed is deliberately left to ball.gd's own tween: hand-
## dispatching it races the tween, which then keeps driving the ball's
## position for the rest of its 1.8s while the child "carries" nothing.
func _advance_to_find_ball(runner: GdUnitSceneRunner) -> void:
	Game.start_episode(0.0)
	await runner.simulate_frames(4)
	assert_bool(Game.dispatch("observe")).is_true()
	assert_bool(Game.dispatch("ball_kicked")).is_true()

	# Same accelerate-and-poll-physics-frames shape test_playthrough.gd and
	# test_ending_screen.gd already use for this project's two auto-timers.
	var tree := Engine.get_main_loop() as SceneTree
	Engine.time_scale = TIME_SCALE
	var waited := 0
	while Game.director.state != EpisodeDirector.State.FIND_BALL and waited < MAX_WAIT_TICKS:
		await tree.physics_frame
		waited += 1
	Engine.time_scale = 1.0
	assert_str(Game.director.state).is_equal(EpisodeDirector.State.FIND_BALL)
	await runner.simulate_frames(SETTLE_FRAMES)


func _wait_for_verb(runner: GdUnitSceneRunner, player: Node3D, verb_name: String, max_frames: int) -> void:
	for _i in range(max_frames):
		if player.verb == player.Verb[verb_name]:
			return
		await runner.simulate_frames(1)
	assert_str(player.Verb.keys()[player.verb]) \
		.override_failure_message("never reached verb %s" % verb_name) \
		.is_equal(verb_name)


func _bone_rotation_in(anim: Animation, bone_name: String) -> Quaternion:
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		if str(anim.track_get_path(i)).ends_with(":" + bone_name):
			return anim.rotation_track_interpolate(i, anim.length * 0.5)
	return Quaternion.IDENTITY


## World-space height of the rig's root bone relative to the player node's
## own origin. Standing, this is ~0 (the model is normalized so its feet sit
## at the origin). A seated clip drops the root bone; the compensation in
## character_visual.gd lifts the model back by the same amount, so this
## number should stay ~0 whatever pose is playing.
func _root_bone_offset_from_origin(visual: CharacterVisual, player: Node3D) -> float:
	var skeleton: Skeleton3D = visual.get("_skeleton")
	var bone := skeleton.find_bone("root")
	var world: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	return world.origin.y - player.global_position.y
