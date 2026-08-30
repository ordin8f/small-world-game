extends SceneTree

## Throwaway diagnostic: prints the imported loop_mode of every clip on the
## player's character model. Godot's glTF importer defaults animations to
## LOOP_NONE unless the clip name carries a -loop/-cycle suffix, which Kenney's
## do not -- so a clip played once by set_motion()'s change-guard runs through
## and freezes on its last frame instead of cycling.

const MODEL := "res://assets/kenney/character-male-a.glb"


func _init() -> void:
	var scene: PackedScene = load(MODEL)
	var root: Node = scene.instantiate()
	var player: AnimationPlayer = _find(root)
	if player == null:
		print("no AnimationPlayer found")
		quit()
		return

	var modes := {
		Animation.LOOP_NONE: "LOOP_NONE",
		Animation.LOOP_LINEAR: "LOOP_LINEAR",
		Animation.LOOP_PINGPONG: "LOOP_PINGPONG",
	}
	var looping := 0
	var names: PackedStringArray = player.get_animation_list()
	for n in names:
		var anim: Animation = player.get_animation(n)
		if anim.loop_mode != Animation.LOOP_NONE:
			looping += 1
		if n in ["idle", "walk", "sprint", "sit", "crouch", "holding-both", "pick-up", "jump"]:
			print("  %-14s loop=%-13s length=%.2fs" % [n, modes.get(anim.loop_mode, "?"), anim.length])
	print("clips: %d, of which looping: %d" % [names.size(), looping])
	root.free()
	quit()


func _find(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find(child)
		if found != null:
			return found
	return null
