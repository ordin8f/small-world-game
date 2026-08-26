extends Node3D
## M3.3: bumps the Tiny Treats glTF props (park/house, M3.2) up to the
## environment's >=0.78 matte roughness floor. Applied live in _ready(),
## not baked into courtyard.tscn by the generator -- see
## tools/_bootstrap_courtyard.gd's _prop() for why the pack()-time
## approach was reverted (it orphaned nodes and hung the test suite).
## Mirrors character_visual.gd's _tune_materials(), including duplicating
## before mutating: prop scenes are instanced more than once
## (tree_large.gltf x3) and share their Mesh/Material resources.

func _ready() -> void:
	_tune_materials(self)


func _tune_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mesh: Mesh = mesh_instance.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				var mat: Material = mesh.surface_get_material(i)
				if mat is StandardMaterial3D:
					var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					sm.roughness = maxf(sm.roughness, 0.78)
					mesh_instance.set_surface_override_material(i, sm)
	for child in node.get_children():
		_tune_materials(child)
