extends SceneTree

## Throwaway: prints the world-space vertical extent of the chalk circle meshes
## in the built scene. Two readings are in dispute -- a flat mark a couple of
## millimetres thick, or a hoop 9 cm tall standing through the children's shins.
## The scene can settle it.

const SCENE := "res://scenes/courtyard.tscn"


func _init() -> void:
	var root: Node3D = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(root)

	for node in _rings(root):
		var aabb: AABB = node.get_aabb()
		var xf: Transform3D = node.global_transform
		var lo := INF
		var hi := -INF
		for i in range(8):
			var corner: Vector3 = xf * aabb.get_endpoint(i)
			lo = minf(lo, corner.y)
			hi = maxf(hi, corner.y)
		print("%-22s y %.4f .. %.4f   (%.1f mm tall)  centre_y=%.4f"
			% [node.name, lo, hi, (hi - lo) * 1000.0, node.global_position.y])

	root.free()
	quit()


func _rings(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is TorusMesh:
		found.append(node)
	for child in node.get_children():
		found.append_array(_rings(child))
	return found
