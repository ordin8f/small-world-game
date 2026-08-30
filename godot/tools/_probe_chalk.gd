extends SceneTree

## Prints the world-space vertical extent of the chalk circle meshes in the
## built scene, and where they sit relative to the ground the child walks on.
##
## Written because three different readings of the chalk ring were in play at
## once -- a flat 2 mm mark, a 9 cm hoop, and a 26 mm ring on the ground -- and
## every one of them came from arithmetic rather than from the scene. The first
## version of this probe measured in _init(), before the tree exists, so
## global_transform was identity and it reported the raw mesh AABB with the
## node's 0.012 y-scale never applied: a 26 mm answer that was the same number
## whatever the scene said. Hence the await below, and hence printing the scale
## alongside the extent so a transform that never landed is visible as one.

const SCENE := "res://scenes/courtyard.tscn"


func _init() -> void:
	await process_frame  # global_transform is identity until the tree is up
	var root: Node3D = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(root)
	await process_frame

	var walk_plane := WorldAffordances.WALK_PLANE_Y
	for node in _rings(root):
		var aabb: AABB = node.get_aabb()
		var xf: Transform3D = node.global_transform
		var lo := INF
		var hi := -INF
		for i in range(8):
			var corner: Vector3 = xf * aabb.get_endpoint(i)
			lo = minf(lo, corner.y)
			hi = maxf(hi, corner.y)
		print("ring  y %+.4f .. %+.4f  (%.2f mm thick)  y_scale=%.4f  top is %+.1f mm vs the walking plane"
			% [lo, hi, (hi - lo) * 1000.0, xf.basis.get_scale().y, (hi - walk_plane) * 1000.0])

	root.free()
	quit()


func _rings(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is TorusMesh:
		found.append(node)
	for child in node.get_children():
		found.append_array(_rings(child))
	return found
