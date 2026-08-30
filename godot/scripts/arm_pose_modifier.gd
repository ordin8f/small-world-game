class_name ArmPoseModifier
extends SkeletonModifier3D
## Holds a fixed pose on a named set of bones, on top of whatever the
## AnimationPlayer is doing to the rest of the skeleton. This is what makes
## carrying the ball and balancing on the garden edging possible with one
## AnimationPlayer and no AnimationTree: the legs keep their walk cycle, the
## arms hold still.
##
## It has to be a SkeletonModifier3D rather than a plain
## set_bone_pose_rotation() from some node's _process(). That was the first
## attempt and it looks like it works -- the write lands, and reading the
## bone back on the very next line returns the value just written -- but
## Skeleton3D restores bone poses around its own modifier pass, so by the
## time anything downstream (or a test) looks at the skeleton the pose is
## the mixer's again and the arms are back to swinging. A modifier writes
## inside that pass, which is the only place a write survives it.
##
## `influence` (0..1, inherited) is the crossfade: Skeleton3D blends this
## modifier's output against the un-modified pose by that amount, so easing
## the arms in and out is a property animation rather than hand-rolled
## quaternion slerping. `active` off means the modifier costs nothing.

## Skeleton bone indices to hold, resolved once by the owner.
var bone_ids: PackedInt32Array = PackedInt32Array()

## One rotation per entry in bone_ids, in the same order.
var rotations: Array[Quaternion] = []


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or bone_ids.size() != rotations.size():
		return
	for i in range(bone_ids.size()):
		skeleton.set_bone_pose_rotation(bone_ids[i], rotations[i])
