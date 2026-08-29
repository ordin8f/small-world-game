extends SceneTree
## Throwaway probe (not wired into verify.ps1): prints, for the imported
## character .glb, every clip's name / length / loop mode and the imported
## node names + track paths the rig actually exposes. Used to check the
## engine's own view of the clips rather than the raw glTF JSON's.
##   godot --headless --path godot --script res://tools/_probe_clips.gd

const GLB_PATH := "res://assets/kenney/character-male-a.glb"


func _initialize() -> void:
	var packed: PackedScene = load(GLB_PATH)
	var model: Node3D = packed.instantiate()
	get_root().add_child(model)

	print("--- node tree ---")
	_print_tree(model, 0)

	var anim := _find_animation_player(model)
	if anim == null:
		print("NO ANIMATION PLAYER")
		quit(1)
		return

	print("--- root_node: %s ---" % anim.root_node)
	print("--- clips (%d) ---" % anim.get_animation_list().size())
	for clip_name in anim.get_animation_list():
		var a: Animation = anim.get_animation(clip_name)
		print("%-26s len=%5.2f loop=%d tracks=%d" % [clip_name, a.length, a.loop_mode, a.get_track_count()])

	print("--- root translation at mid-clip (how far the clip moves the body) ---")
	for clip_name in anim.get_animation_list():
		var a2: Animation = anim.get_animation(clip_name)
		for i in range(a2.get_track_count()):
			if a2.track_get_type(i) == Animation.TYPE_POSITION_3D and str(a2.track_get_path(i)).ends_with(":root"):
				var v: Vector3 = a2.position_track_interpolate(i, a2.length * 0.5)
				print("  %-24s root=(%.3f, %.3f, %.3f)" % [clip_name, v.x, v.y, v.z])

	for clip_name in ["idle", "walk", "holding-both", "holding-right", "pick-up", "interact-right", "crouch", "sit"]:
		var a: Animation = anim.get_animation(clip_name)
		if a == null:
			continue
		print("--- tracks of %s ---" % clip_name)
		for i in range(a.get_track_count()):
			var value := "?"
			if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = a.rotation_track_interpolate(i, 0.0)
				var e := Basis(q).get_euler() * 180.0 / PI
				value = "euler(%.1f, %.1f, %.1f)" % [e.x, e.y, e.z]
			print("  [%d] %-10s %s  %s" % [i, a.track_get_type(i), a.track_get_path(i), value])

	quit(0)


func _print_tree(node: Node, depth: int) -> void:
	print("%s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()])
	for c in node.get_children():
		_print_tree(c, depth + 1)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
