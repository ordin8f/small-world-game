extends SceneTree
## Throwaway diagnostic (not wired into verify.ps1): answers "is it safe to
## set loop_mode on an imported Animation at runtime?"
##
## Animations imported from a .glb live in an AnimationLibrary on the
## imported scene, and PackedScene.instantiate() shares sub-resources between
## instances by default. So mutating one instance's clip can mutate every
## other instance's. This prints whether that is actually happening here, and
## whether the same .glb loaded twice hands back the same Animation object --
## the two cases that decide whether the fix needs per-instance duplication.
##
##   godot --headless --path godot -s res://tools/_probe_shared_anims.gd

const SAME_GLB := "res://assets/kenney/character-male-a.glb"   ## Player AND Priya both use this one
const OTHER_GLB := "res://assets/kenney/character-female-b.glb" ## Mina


func _initialize() -> void:
	var a1 := _anim_of(SAME_GLB)
	var a2 := _anim_of(SAME_GLB)
	var b1 := _anim_of(OTHER_GLB)

	var w1: Animation = a1.get_animation("walk")
	var w2: Animation = a2.get_animation("walk")
	var wb: Animation = b1.get_animation("walk")

	print("two instances of the SAME glb share the walk Animation object: %s" % [w1 == w2])
	print("  instance 1 walk rid: %s" % w1.get_instance_id())
	print("  instance 2 walk rid: %s" % w2.get_instance_id())
	print("a DIFFERENT glb has its own walk Animation object: %s" % [wb != w1])

	# The consequence, demonstrated rather than asserted: set it on one and
	# read it back off the other.
	print("before: instance1=%d instance2=%d other=%d" % [w1.loop_mode, w2.loop_mode, wb.loop_mode])
	w1.loop_mode = Animation.LOOP_LINEAR
	print("after setting instance 1: instance1=%d instance2=%d other=%d" % [w1.loop_mode, w2.loop_mode, wb.loop_mode])

	# And whether the resource refuses the write at all (imported resources
	# can be read-only in some Godot configurations).
	print("write took effect: %s" % [w1.loop_mode == Animation.LOOP_LINEAR])

	quit(0)


func _anim_of(path: String) -> AnimationPlayer:
	var packed: PackedScene = load(path)
	var root: Node = packed.instantiate()
	get_root().add_child(root)
	return _find(root)


func _find(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find(child)
		if found != null:
			return found
	return null
