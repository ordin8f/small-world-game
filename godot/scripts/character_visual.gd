class_name CharacterVisual
extends Node3D
## Verbatim port of src/characters.mjs's loadCharacter() (normalizeToHeight,
## tuneImported, rotation.y = PI) plus a simplified animation-selection
## layer. Reused for both the player's visual and each NPC -- config
## (glb path/target height/tint/reaction) is looked up by node .name
## rather than @export properties, same reason as interaction_zone.gd:
## this script references Game, so it fails to compile inside the bare
## `--script` bootstrap run that builds player.tscn/main.tscn, which
## means @export values can't be set there either. .name is a plain Node
## property, unaffected, and always resolves correctly once the scene
## runs for real.
##
## Animation: game.mjs's switchAction() crossfades between three DISCRETE
## clips (idle/walk/run) on change, not a continuous speed-blended tree --
## AnimationPlayer.play(name, blend_time) reproduces that exactly, more
## faithfully than building an AnimationTree BlendSpace1D would (a
## different technique/behavior the source doesn't actually use).
##
## That three-clip machine is still the whole of LOCOMOTION, but it was also,
## until now, the whole of everything: sandbox.gd, ball.gd, pocket_treasure.gd,
## imagination_prop.gd and interaction_zone.gd between them contained no
## animation calls at all, so building a sandcastle, pocketing a keepsake and
## carrying a ball home were all performed by a child standing perfectly
## still. Three things were added for them, in increasing order of how much
## they change:
##
##  1. play_pose(clip, hold_seconds) -- a one-shot the locomotion machine
##     cannot stamp over for `hold_seconds`. Without the hold, an interaction's
##     clip lasted exactly one frame, because player.gd calls set_motion()
##     every physics tick.
##  2. set_arm_pose(clip) -- a persistent overlay on the arms only, so a
##     carried ball survives walking and running (scripts/arm_pose_modifier.gd).
##  3. A seat-height correction in _apply(), because Kenney's seated clips
##     drop the root bone rather than assuming a seat, which buried the slide
##     and swing riders inside the thing they were sitting on.
##
## None of it is allowed to gate anything: every caller plays its clip after
## the mechanic has already happened, and nothing awaits a clip.
##
## Gate 1 (mechanics agent): "talking to the other children" -- Mina, Arun,
## and Priya (the third child; she had no name before this change, just the
## node name "Third" -- renamed throughout, see main.tscn/CHARACTER_DATA)
## were animated statues that played "idle" once and never moved again.
## CHARACTER_DATA's new npc_lines/talk_pose/talk_behavior keys make each of
## them a free-roam interactable (Game.free_interactables, never gated on
## director.state): press interact nearby and they react, say one of a few
## authored lines (no runtime LLM -- docs/PRODUCT_CONTRACT.md), and DO
## something distinct per child, matching the brief's own three examples
## one-for-one -- Mina turns to face you and stays; Arun follows you for a
## few seconds; Priya walks off toward the tower/slide. All three reuse
## this script's existing set_motion()/play_pose() machinery rather than
## adding a parallel animation path, and the player's own CHARACTER_DATA
## entry has no npc_lines key at all, so none of this ever engages for the
## player's own CharacterVisual instance.

const CHARACTER_DATA := {
	"Player": {
		"glb_path": "res://assets/kenney/character-male-a.glb",
		"target_height": 1.08,
		"tint": Color(1.0, 1.0, 1.0),
	},
	"Mina": {
		"glb_path": "res://assets/kenney/character-female-b.glb",
		"target_height": 1.0,
		"tint": Color(0.945, 0.918, 0.863),
		"reaction_state": "INVITED",
		"reaction_clip": "emote-yes",
		"npc_lines": [
			"It only counts if it stays inside the chalk.",
			"You can have a turn if you want one.",
			"Arun always kicks it too hard.",
		],
		"talk_pose": "emote-yes",
		"talk_behavior": "turn",
	},
	"Arun": {
		"glb_path": "res://assets/kenney/character-male-c.glb",
		"target_height": 1.0,
		"tint": Color(0.918, 0.851, 0.761),
		"reaction_state": "BALL_IN_FLIGHT",
		"reaction_clip": "attack-kick-right",
		"npc_lines": [
			"I didn't mean to kick it that far.",
			"Race you to the wall!",
			"Priya climbs faster than both of us.",
		],
		# Was "wave", which is not one of the .glb's 32 clips at all, so
		# play_pose()'s fallback silently swapped it for "idle" and Arun
		# never moved when spoken to. The pack has no wave/greet/talk clip
		# to swap in; "emote-no" is a head shake, which is the closest
		# honest read of a child protesting "I didn't mean to kick it that
		# far", and it stays distinct from Mina's nod. See tools/anim_shots.ps1
		# for how the 32 clips were actually looked at rather than guessed.
		"talk_pose": "emote-no",
		"talk_behavior": "follow",
	},
	"Priya": {
		"glb_path": "res://assets/kenney/character-male-a.glb",
		"target_height": 1.0,
		"tint": Color(0.788, 0.827, 0.878),
		"npc_lines": [
			"I found a good stick over there.",
			"Bet you can't beat me down the slide.",
			"It's more fun when everyone plays.",
		],
		# Was "idle" -- a real clip, so no fallback warning would ever have
		# fired, but it meant "talk to Priya" visibly did nothing. "interact-right"
		# swings an arm out in front of her, which reads as pointing at the
		# stick / at the slide she is about to run off to.
		"talk_pose": "interact-right",
		"talk_behavior": "wander_to_slide",
	},
}

const CROSSFADE_SECONDS := 0.2

## The three clips the locomotion state machine cycles between. Godot's glTF
## importer gives every imported clip loop_mode LOOP_NONE unless the source
## file names it otherwise, and Kenney's does not -- so before this was set,
## holding a movement key played exactly one 0.67s walk cycle and then froze
## the child mid-stride until they stopped and started again. Set here at
## runtime rather than in the three .glb.import files: it applies to every
## character .glb this project loads without three near-identical
## _subresources blocks that the asset pipeline would have to keep in sync.
const LOOPING_CLIPS := ["idle", "walk", "sprint"]

## Bones whose rotation set_arm_pose() overrides. The Kenney rig is seven
## bones (root/torso/head/arm-left/arm-right/leg-left/leg-right), and the
## poses worth layering -- the two-handed carry, the arms-out balance -- are
## exactly the ones that touch nothing but these two.
const ARM_BONES := ["arm-left", "arm-right"]

## Below this, a clip's root-bone dip is the ordinary bob of a walk cycle
## (walk 0.005, sprint 0.011 in model units) rather than a deliberate drop
## to seat height (sit and drive are both -0.150). Only the latter gets
## compensated -- see _root_drop_for().
const ROOT_DROP_EPSILON := 0.02

## Gate 1: interact-driven conversation tuning. Kept here rather than in a
## per-entry CHARACTER_DATA value -- these are shared pacing constants, not
## per-child content (the content is npc_lines/talk_pose/talk_behavior
## above).
const TALK_LINE_SECONDS := 2.6
const TALK_TURN_HOLD_SECONDS := 2.8
const FOLLOW_SECONDS := 3.5
const FOLLOW_SPEED := 2.0
const FOLLOW_STOP_DISTANCE := 1.1
const WANDER_SPEED := 1.9
const WANDER_ARRIVE_DISTANCE := 0.5
const WANDER_TIMEOUT_SECONDS := 8.0  ## safety cap so a blocked path can't wander forever
const FACE_TURN_RATE := 6.0          ## radians/sec-ish ease, matches player.gd's own heading ease feel
const INTERACT_RADIUS := 1.7

var _anim_player: AnimationPlayer = null
var _current_clip: String = ""
var _reaction_state: String = ""
var _reaction_clip: String = ""

## The clip the idle/walk/sprint state machine currently wants, kept
## separately from _current_clip so a one-shot pose can own the body for a
## moment and then hand it straight back to the right locomotion clip
## without the caller having to remember what that was.
var _motion_clip: String = "idle"
var _pose_hold: float = 0.0

## Model handles kept for the seat-height compensation in _apply(): the
## normalized model's resting Y, and the scale factor _normalize_to_height()
## chose, which converts a clip's root track (authored in the .glb's own
## units) into world metres.
var _model: Node3D = null
var _model_rest_y: float = 0.0
var _model_scale: float = 1.0

## Arm-pose overlay state -- see set_arm_pose().
var _skeleton: Skeleton3D = null
var _arm_modifier: ArmPoseModifier = null
var _arm_pose_clip: String = ""

## Free-interactable contract (see game.gd's own doc comment on
## free_interactables): label/radius/interact(). Empty label/zero-behavior
## for the Player instance, which never registers at all (see _ready()).
var label: String = ""
var radius: float = INTERACT_RADIUS

var _npc_lines: Array = []
var _line_index: int = 0
var _behavior_kind: String = ""  ## "turn" | "follow" | "wander_to_slide", from CHARACTER_DATA; "" for the player
var _talk_pose: String = "idle"
var _talking: bool = false
var _talk_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO


func _ready() -> void:
	var data: Dictionary = CHARACTER_DATA[name]
	var packed: PackedScene = load(data["glb_path"])
	var model: Node3D = packed.instantiate()
	add_child(model)

	_tune_materials(model, data["tint"])
	_normalize_to_height(model, data["target_height"])
	model.rotation.y = PI  # characters.mjs:126 -- aligns model +z forward with heading=0 facing -z

	_model = model
	_model_rest_y = model.position.y
	_skeleton = _find_skeleton(model)

	_anim_player = _find_animation_player(model)
	if _anim_player:
		for clip_name in LOOPING_CLIPS:
			if _anim_player.has_animation(clip_name):
				_anim_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
		_anim_player.play("idle")
		_current_clip = "idle"
		_motion_clip = "idle"
	_build_arm_modifier()

	if data.has("reaction_state"):
		_reaction_state = data["reaction_state"]
		_reaction_clip = data["reaction_clip"]
		Game.state_changed.connect(_on_state_changed)

	if data.has("npc_lines"):
		label = "Talk to %s" % name
		_npc_lines = data["npc_lines"]
		_behavior_kind = data.get("talk_behavior", "turn")
		_talk_pose = data.get("talk_pose", "idle")
		Game.register_free_interactable(self)
		Game.state_changed.connect(_on_talk_state_changed)


func _exit_tree() -> void:
	if _behavior_kind != "":
		Game.unregister_free_interactable(self)


## Gate 1: Game.interact() calls this directly once this NPC is the nearest
## free interactable in range (see game.gd's _update_active_free_interactable()).
## Cycles through this child's authored lines (no runtime LLM --
## docs/PRODUCT_CONTRACT.md) and starts whichever one physical reaction
## CHARACTER_DATA assigned this child -- a second press mid-reaction just
## shows the next line and restarts that same reaction's timer, rather than
## stacking or ignoring the input.
func interact() -> void:
	if _npc_lines.is_empty():
		return
	var line: String = _npc_lines[_line_index % _npc_lines.size()]
	_line_index += 1
	Game.dialogue_shown.emit(name, line, TALK_LINE_SECONDS)
	play_pose_once(_talk_pose)
	match _behavior_kind:
		"turn":
			_talking = true
			_talk_timer = TALK_TURN_HOLD_SECONDS
		"follow":
			_talking = true
			_talk_timer = FOLLOW_SECONDS
		"wander_to_slide":
			_talking = true
			_wander_target = WorldAffordances.CLIMB_TRIGGER
			_talk_timer = WANDER_TIMEOUT_SECONDS


func _physics_process(delta: float) -> void:
	if _pose_hold > 0.0:
		_pose_hold = maxf(_pose_hold - delta, 0.0)
		if _pose_hold == 0.0:
			_apply(_motion_clip)

	if not _talking:
		return
	_talk_timer -= delta
	# The gesture finishes before the walk starts, for the two behaviours
	# that WALK. _talk_timer is decremented first, so a following/wandering
	# child still stops at exactly the same moment it did before -- it just
	# spends the first fraction of a second of that window doing its emote
	# standing still, instead of sliding away mid-pose with frozen legs
	# (none of the emote clips animate the legs at all). "turn" is excluded
	# because turning on the spot doesn't move the legs either way, so
	# there is nothing to look wrong, and delaying it would only make the
	# child feel slow to acknowledge you.
	if _pose_hold > 0.0 and _behavior_kind != "turn":
		return
	match _behavior_kind:
		"turn":
			_process_turn(delta)
		"follow":
			_process_follow(delta)
		"wander_to_slide":
			_process_wander(delta)


func _process_turn(delta: float) -> void:
	if is_instance_valid(Game.player):
		_face_toward(Game.player.global_position, delta)
	if _talk_timer <= 0.0:
		_talking = false
		set_motion(false, false)  # reverts off talk_pose (e.g. Mina's "emote-yes") back to idle


func _process_follow(delta: float) -> void:
	if not is_instance_valid(Game.player) or _talk_timer <= 0.0:
		_talking = false
		set_motion(false, false)
		return
	_step_toward(Game.player.global_position, FOLLOW_SPEED, FOLLOW_STOP_DISTANCE, delta)


func _process_wander(delta: float) -> void:
	var arrived := global_position.distance_to(_wander_target) <= WANDER_ARRIVE_DISTANCE
	if arrived or _talk_timer <= 0.0:
		_talking = false
		set_motion(false, false)
		return
	_step_toward(_wander_target, WANDER_SPEED, WANDER_ARRIVE_DISTANCE, delta)


## Shared by _process_follow()/_process_wander(): a plain x/z step toward
## `target`, guarded by WorldBounds.can_move_to() the same way a walking
## player is -- a live NPC step, not a scripted one, so following/wandering
## can never visibly clip an NPC through the garden wall or a tower. Reads
## WorldBounds only (owned by the world-expansion agent, unmodified here).
func _step_toward(target: Vector3, speed: float, stop_distance: float, delta: float) -> void:
	var dx := target.x - global_position.x
	var dz := target.z - global_position.z
	var dist := Vector2(dx, dz).length()
	if dist <= stop_distance:
		set_motion(false, false)
		return
	var next_x := global_position.x + (dx / dist) * speed * delta
	var next_z := global_position.z + (dz / dist) * speed * delta
	if WorldBounds.can_move_to(next_x, next_z):
		global_position.x = next_x
		global_position.z = next_z
	_face_toward(target, delta)
	set_motion(true, false)


## Same atan2(-dx, -dz) heading convention player.gd's own movement uses
## (this class's model.rotation.y = PI flip above aligns +z-forward with
## heading=0 facing -z for every CharacterVisual instance, player or NPC
## alike), so an NPC turning to face something looks identical in kind to
## the player's own turning, not a different convention that happens to
## look similar.
func _face_toward(target: Vector3, delta: float) -> void:
	var dx := target.x - global_position.x
	var dz := target.z - global_position.z
	if absf(dx) < 0.05 and absf(dz) < 0.05:
		return
	var target_heading := atan2(-dx, -dz)
	rotation.y += _angle_delta(target_heading, rotation.y) * minf(1.0, delta * FACE_TURN_RATE)


static func _angle_delta(target: float, current: float) -> float:
	return atan2(sin(target - current), cos(target - current))


## A fresh "Play again" must not leave an NPC mid-follow or mid-wander from
## the previous run -- same restart contract player.gd/ball.gd already
## hold to. Separate from _on_state_changed() above (which only exists for
## Mina/Arun's reaction_state pair and is keyed to a SPECIFIC state, not
## ARRIVE) so Priya, who has no reaction_state at all, still gets reset.
func _on_talk_state_changed(new_state: String) -> void:
	if new_state == EpisodeDirector.State.ARRIVE and _talking:
		_talking = false
		set_motion(false, false)


## Called by player.gd every physics tick -- mirrors game.mjs:435-437's
## `player.moving ? (player.running ? run : walk) : idle`.
##
## Records what the locomotion state machine wants even while a one-shot
## pose is holding the body, so the pose can hand back to the correct clip
## when it expires. Without that, a pose started while walking would drop
## the character into idle when it ended, and only recover on the next
## moving/running CHANGE -- which, holding one key, never comes.
func set_motion(moving: bool, running: bool) -> void:
	if _anim_player == null:
		return
	_motion_clip = "idle"
	if moving:
		_motion_clip = "sprint" if running else "walk"
	if _pose_hold > 0.0:
		return
	_apply(_motion_clip)


## Gate 0: plays an arbitrary clip directly, bypassing set_motion()'s
## idle/walk/sprint selection -- for scripted beats (player.gd's slide)
## that want a specific pose the move-state machine doesn't cover.
##
## `hold_seconds` is what makes this usable for an INTERACTION rather than
## only for a state the caller separately guarantees nothing will overwrite.
## player.gd calls set_motion() every single physics tick, so a bare
## play_pose() from an interaction script survives exactly one frame before
## the locomotion machine stamps idle back over it -- which is why picking
## up the ball, patting the sand and pocketing a treasure could all be
## "animated" and still show nothing. While a hold is running, set_motion()
## keeps tracking state but stops applying it; when the hold expires the
## body returns to whatever locomotion clip is current by then.
##
## hold_seconds defaults to 0.0, which is the pre-existing behaviour
## exactly: the caller (player.gd's slide, swing.gd's ride) owns a state in
## which set_motion() is not being called at all, so the pose persists on
## its own until that state ends.
##
## Falls back to idle if the requested clip isn't in this character's
## animation set -- defensive, because a missing clip must never take the
## game down -- but loudly, which is the whole point: this fallback was
## silent, and it hid "wave" (never a clip in this pack) as Arun's talk
## pose for the entire life of the NPC conversation feature.
func play_pose(clip_name: String, hold_seconds: float = 0.0, blend: float = CROSSFADE_SECONDS) -> void:
	if _anim_player == null:
		return
	_pose_hold = maxf(hold_seconds, 0.0)
	_apply(_resolve_clip(clip_name), blend)


## Plays `clip_name` for exactly its own length. The common case for an
## interaction: the child does the thing and returns to whatever they were
## doing, without a duration anyone has to keep in sync with the .glb.
func play_pose_once(clip_name: String, blend: float = CROSSFADE_SECONDS) -> void:
	if _anim_player == null:
		return
	var resolved := _resolve_clip(clip_name)
	play_pose(resolved, _anim_player.get_animation(resolved).length, blend)


## Reads the AnimationPlayer's own state rather than this script's
## bookkeeping, so a test asserting on it fails if the clip was merely
## recorded and never actually played. assigned_animation, not
## current_animation: the latter empties itself the moment a non-looping
## clip finishes, which would make every one-shot pose untestable.
func current_clip() -> String:
	return _anim_player.assigned_animation if _anim_player != null else ""


func has_clip(clip_name: String) -> bool:
	return _anim_player != null and _anim_player.has_animation(clip_name)


## The player's own CharacterVisual, or null before the play scene exists.
## Every free-roam interaction (ball, sandbox, treasures, imagination props,
## interaction zones) wants to animate the CHILD rather than itself, and
## none of them should have to know that the route there is
## Game.player.character_visual, or repeat the is_instance_valid guard that
## a headless unit test with no player in the scene needs.
static func of_player() -> CharacterVisual:
	if not is_instance_valid(Game.player):
		return null
	return Game.player.character_visual as CharacterVisual


# ------------------------------------------------------------ arm overlay --

## Holds `clip_name`'s arm bones on top of whatever the AnimationPlayer is
## doing, until clear_arm_pose(). This is how carrying works: "holding-both"
## puts both arms out in front and touches nothing else, so it layers over
## idle, walk and sprint alike and the child keeps their hands on the ball
## while they run. Playing it as an ordinary clip instead would freeze the
## legs, because Godot's importer fills every clip out to all eleven tracks
## -- the arms-only clip is arms-only in the .glb, not once imported.
##
## Also used for the garden-edging balance, where the clip is "static" (the
## rest T-pose: both arms straight out sideways). That composes with
## player.gd's existing procedural lean instead of fighting it -- the lean
## keeps doing the balancing, the arms just say out loud what it is.
##
## Unlike play_pose() there is no idle fallback here: an overlay is an
## addition, so the safe response to a name that isn't a clip is to warn and
## add nothing, not to stamp idle's arms over a perfectly good animation.
func set_arm_pose(clip_name: String) -> void:
	if clip_name == _arm_pose_clip:
		return
	if _anim_player == null or _arm_modifier == null:
		return
	if not _anim_player.has_animation(clip_name):
		push_warning("character_visual (%s): no arm-pose clip '%s' -- arms left as animated. Known clips: %s" % [
			name, clip_name, ", ".join(_anim_player.get_animation_list()),
		])
		return
	_arm_modifier.rotations = _sample_arm_rotations(clip_name)
	_arm_modifier.active = true
	_arm_pose_clip = clip_name


func clear_arm_pose() -> void:
	_arm_pose_clip = ""


## The overlay's own requested clip, "" when none. Distinct from
## current_clip(): both can be live at once, which is exactly the point.
func arm_pose_clip() -> String:
	return _arm_pose_clip


## How far the overlay has eased in, 0..1. Exposed so a test can wait for it
## to actually reach the pose rather than assert on the frame it was asked
## for, which would pass whether or not the pose ever landed on the bones.
func arm_pose_blend() -> float:
	return _arm_modifier.influence if _arm_modifier != null else 0.0


## Eases the overlay in and out over the same CROSSFADE_SECONDS the clip
## crossfade uses, so arms arriving at a carry look like part of the same
## transition rather than a snap. The pose itself is applied by the modifier
## inside Skeleton3D's own pass; all this does is drive the blend weight.
func _process(delta: float) -> void:
	if _arm_modifier == null:
		return
	var target := 1.0 if _arm_pose_clip != "" else 0.0
	if _arm_modifier.influence != target:
		_arm_modifier.influence = move_toward(_arm_modifier.influence, target, delta / CROSSFADE_SECONDS)
		# Fully faded out: stop the modifier entirely rather than leaving it
		# running at zero influence every frame for the rest of the game.
		if _arm_modifier.influence == 0.0:
			_arm_modifier.active = false


## Back to a clean slate: no held pose, no overlay, standing idle. Called on
## a fresh "Play again" (player.gd's _reset_to_start), same restart contract
## the ball and the player's own position already hold to -- a restart must
## not leave the child still holding an invisible ball.
func reset_pose() -> void:
	_pose_hold = 0.0
	_arm_pose_clip = ""
	if _arm_modifier != null:
		_arm_modifier.influence = 0.0
		_arm_modifier.active = false
	_motion_clip = "idle"
	_apply("idle")


# ------------------------------------------------------------- internals --

## The one place a clip name becomes a clip. Keeps the defensive fallback --
## a wrong name must never crash a child's afternoon -- but says so, with the
## offending name and the character it was asked of, so the next one surfaces
## on the first run instead of never.
func _resolve_clip(clip_name: String) -> String:
	if _anim_player.has_animation(clip_name):
		return clip_name
	push_warning("character_visual (%s): no clip '%s' -- falling back to idle. Known clips: %s" % [
		name, clip_name, ", ".join(_anim_player.get_animation_list()),
	])
	return "idle"


func _apply(clip: String, blend: float = CROSSFADE_SECONDS) -> void:
	if _anim_player == null or clip == _current_clip:
		return
	_current_clip = clip
	_anim_player.play(clip, blend)
	if _model != null:
		_model.position.y = _model_rest_y - _root_drop_for(clip)


## Kenney's seated clips (sit, drive, every wheelchair pose) do not put the
## character in a chair -- they translate the root bone DOWN by 0.150 model
## units, i.e. they assume the seat is at the origin and drop the body to it.
## Applied to a character whose feet are already at the mount point, that
## sinks them: at this project's normalize scale, 0.241 m of a 1.08 m child,
## which is why the slide rider is buried to the eyebrows in the chute and
## the swing rider's head sits at chain-bottom height. Compensating by the
## clip's own root track (rather than a hand-tuned constant per call site)
## keeps it correct for any clip and any character height.
func _root_drop_for(clip: String) -> float:
	if _anim_player == null or not _anim_player.has_animation(clip):
		return 0.0
	var anim := _anim_player.get_animation(clip)
	for i in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		if not str(anim.track_get_path(i)).ends_with(":root"):
			continue
		var y: float = anim.position_track_interpolate(i, anim.length * 0.5).y
		return y * _model_scale if absf(y) > ROOT_DROP_EPSILON else 0.0
	return 0.0


## The modifier has to be a direct child of the Skeleton3D to be part of its
## modifier pass at all, so it is built here rather than authored into the
## .glb-derived scene (which is regenerated from the asset and would lose it).
func _build_arm_modifier() -> void:
	if _skeleton == null:
		return
	var ids := PackedInt32Array()
	for bone_name in ARM_BONES:
		var id := _skeleton.find_bone(bone_name)
		if id < 0:
			push_warning("character_visual (%s): rig has no bone '%s' -- arm poses (carry, balance) will not apply." % [name, bone_name])
			return
		ids.append(id)

	_arm_modifier = ArmPoseModifier.new()
	_arm_modifier.name = "ArmPose"
	_arm_modifier.bone_ids = ids
	_arm_modifier.active = false
	_arm_modifier.influence = 0.0
	_skeleton.add_child(_arm_modifier)


## Samples the arm rotations the clip holds at its midpoint. These are all
## single-pose clips (0.17s, two identical keys), so the midpoint is the
## pose; sampling rather than assuming lets a future animated overlay clip
## at least land on something sensible.
func _sample_arm_rotations(clip_name: String) -> Array[Quaternion]:
	var anim := _anim_player.get_animation(clip_name)
	var result: Array[Quaternion] = []
	for bone_name in ARM_BONES:
		var found := Quaternion.IDENTITY
		for i in range(anim.get_track_count()):
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			if not str(anim.track_get_path(i)).ends_with(":" + bone_name):
				continue
			found = anim.rotation_track_interpolate(i, anim.length * 0.5)
			break
		result.append(found)
	return result


## Mina's nod of welcome (INVITED) and Arun's kick (BALL_IN_FLIGHT) -- the
## two reactions keyed to an episode state rather than to being spoken to.
## Routed through play_pose_once() rather than driving the AnimationPlayer
## directly and awaiting animation_finished, so that (a) _current_clip stays
## truthful, and (b) the reaction can't be stamped over one frame later by a
## set_motion() call, which was possible for any character that happened to
## be walking when its state fired. Half the usual crossfade: both of these
## are sharp physical beats that need to snap in, not ease in over a third
## of their own length.
func _on_state_changed(new_state: String) -> void:
	if new_state != _reaction_state:
		return
	play_pose_once(_reaction_clip, CROSSFADE_SECONDS / 2.0)


func _tune_materials(model: Node3D, tint: Color) -> void:
	for m in _find_all_mesh_instances(model):
		var mesh_instance: MeshInstance3D = m
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for i in range(mesh.get_surface_count()):
			var mat: Material = mesh.surface_get_material(i)
			if mat is StandardMaterial3D:
				# .duplicate() + set_surface_override_material(), not an
				# in-place edit -- multiple instances of the same .glb
				# (the player and Priya both use character-male-a.glb)
				# share the underlying Material resource by default,
				# same class of bug as the interaction-zone CylinderShape3D
				# sharing issue from M2.2.
				var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				sm.roughness = maxf(sm.roughness, 0.78)
				sm.metallic = 0.0
				sm.albedo_color = sm.albedo_color * tint
				mesh_instance.set_surface_override_material(i, sm)


func _normalize_to_height(model: Node3D, target_height: float) -> void:
	var aabb := _merged_aabb(model)
	if aabb.size.y > 0.0001:
		model.scale = Vector3.ONE * (target_height / aabb.size.y)
	_model_scale = model.scale.y
	aabb = _merged_aabb(model)
	model.position.y -= aabb.position.y


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


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null
