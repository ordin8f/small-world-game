extends SceneTree
## Throwaway diagnostic (not wired into verify.ps1): classifies every clip in
## the character .glb as a CYCLE or a static POSE, and reports whether its
## endpoints match closely enough to loop without a visible pop.
##
## The point is to decide which clips should have loop_mode set by MEASURING
## rather than by reading their names. "crouch" and "holding-both" sound like
## states you would hold, but if their tracks never change value then looping
## them is a no-op, and a test asserting they loop would be asserting nothing
## about how the game looks.
##
##   godot --headless --path godot -s res://tools/_probe_cycles.gd

const GLB_PATH := "res://assets/kenney/character-male-a.glb"
const SAMPLES := 24
const MOVEMENT_EPSILON := 0.001  ## quaternion dot distance from the first sample
const SEAM_EPSILON := 0.02       ## how closely the last frame must match the first to loop cleanly


func _initialize() -> void:
	var packed: PackedScene = load(GLB_PATH)
	var model: Node3D = packed.instantiate()
	get_root().add_child(model)
	var anim := _find(model)
	if anim == null:
		print("no AnimationPlayer")
		quit(1)
		return

	print("%-24s %-6s %-8s %-8s %s" % ["clip", "len", "kind", "seam", "peak movement"])
	for clip_name in anim.get_animation_list():
		var a: Animation = anim.get_animation(clip_name)
		var peak := 0.0
		var seam := 0.0
		for i in range(a.get_track_count()):
			if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var first: Quaternion = a.rotation_track_interpolate(i, 0.0)
			var last: Quaternion = a.rotation_track_interpolate(i, a.length)
			seam = maxf(seam, 1.0 - absf(first.dot(last)))
			for s in range(SAMPLES + 1):
				var q: Quaternion = a.rotation_track_interpolate(i, a.length * float(s) / SAMPLES)
				peak = maxf(peak, 1.0 - absf(first.dot(q)))

		var kind := "CYCLE" if peak > MOVEMENT_EPSILON else "pose"
		var seam_note := "clean" if seam <= SEAM_EPSILON else "POPS"
		print("%-24s %5.2f %-8s %-8s %.4f (seam %.4f)" % [clip_name, a.length, kind, seam_note, peak, seam])

	quit(0)


func _find(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find(child)
		if found != null:
			return found
	return null
