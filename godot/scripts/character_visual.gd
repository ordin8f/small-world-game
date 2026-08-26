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
	},
	"Arun": {
		"glb_path": "res://assets/kenney/character-male-c.glb",
		"target_height": 1.0,
		"tint": Color(0.918, 0.851, 0.761),
		"reaction_state": "BALL_IN_FLIGHT",
		"reaction_clip": "attack-kick-right",
	},
	"Third": {
		"glb_path": "res://assets/kenney/character-male-a.glb",
		"target_height": 1.0,
		"tint": Color(0.788, 0.827, 0.878),
	},
}

const CROSSFADE_SECONDS := 0.2

var _anim_player: AnimationPlayer = null
var _current_clip: String = ""
var _reaction_state: String = ""
var _reaction_clip: String = ""


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
				# (the player and "Third" both use character-male-a.glb)
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
