extends SceneTree
## Throwaway diagnostic: does AnimationPlayer.play() restart a clip that is
## already the assigned one?
##
## This decides whether "drop the change-guard and call play() every physics
## frame" is actually the destructive fix it sounds like. If play() resets the
## playhead, that fix pins the clip at frame 0 sixty times a second. If it
## does not, the guard is an optimisation rather than a correctness measure,
## and removing it is a behavioural no-op.
##
##   godot --headless --path godot -s res://tools/_probe_replay.gd

const GLB_PATH := "res://assets/kenney/character-male-a.glb"


func _initialize() -> void:
	_run()


func _run() -> void:
	var packed: PackedScene = load(GLB_PATH)
	var model: Node3D = packed.instantiate()
	get_root().add_child(model)
	var anim := _find(model)
	anim.get_animation("walk").loop_mode = Animation.LOOP_LINEAR

	anim.play("walk")
	anim.seek(0.30, true)  # partway into walk's 0.67s
	print("position after seeking to 0.30: %.4f" % anim.current_animation_position)

	anim.play("walk", 0.2)  # the same clip again, as the mutant would every frame
	print("position after re-play() of the SAME clip: %.4f" % anim.current_animation_position)

	anim.seek(0.0, true)
	print("position after an explicit seek(0): %.4f" % anim.current_animation_position)

	quit(0)


func _find(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find(child)
		if found != null:
			return found
	return null
