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
		"talk_pose": "wave",
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
		"talk_pose": "idle",
		"talk_behavior": "wander_to_slide",
	},
}

const CROSSFADE_SECONDS := 0.2

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

	_anim_player = _find_animation_player(model)
	if _anim_player:
		_anim_player.play("idle")
		_current_clip = "idle"

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
	play_pose(_talk_pose)
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
	if not _talking:
		return
	_talk_timer -= delta
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
func set_motion(moving: bool, running: bool) -> void:
	if _anim_player == null:
		return
	var clip := "idle"
	if moving:
		clip = "sprint" if running else "walk"
	if clip == _current_clip:
		return
	_current_clip = clip
	_anim_player.play(clip, CROSSFADE_SECONDS)


## Gate 0: plays an arbitrary clip directly, bypassing set_motion()'s
## idle/walk/sprint selection -- for scripted beats (player.gd's slide)
## that want a specific pose the move-state machine doesn't cover. Falls
## back to idle if the requested clip isn't in this character's animation
## set (defensive: player.gd doesn't know which .glb is attached to any
## given CharacterVisual). The next ordinary set_motion() call (player.gd
## returns to its baseline loop once the scripted beat ends) transitions
## back out of it the same way any other clip change does.
func play_pose(clip_name: String) -> void:
	if _anim_player == null:
		return
	var target := clip_name if _anim_player.has_animation(clip_name) else "idle"
	if target == _current_clip:
		return
	_current_clip = target
	_anim_player.play(target, CROSSFADE_SECONDS)


func _on_state_changed(new_state: String) -> void:
	if new_state != _reaction_state or _anim_player == null or not _anim_player.has_animation(_reaction_clip):
		return
	_anim_player.play(_reaction_clip, CROSSFADE_SECONDS / 2.0)
	await _anim_player.animation_finished
	if is_instance_valid(_anim_player) and _current_clip != "":
		_anim_player.play(_current_clip, CROSSFADE_SECONDS)


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
