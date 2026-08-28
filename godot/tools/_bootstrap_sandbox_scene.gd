extends SceneTree
## One-shot generator: builds scenes/sandbox.tscn -- a self-contained,
## position-parametrized sand pit (Gate 1: "the sandbox should let you
## build something that persists -- a sandcastle that stays built"). A
## flattened "Pit" mesh plus four low border planks, all static; the
## sandcastle mounds/flag scripts/sandbox.gd spawns at runtime are NOT
## baked here, same reasoning puddles.gd's rings aren't baked into
## puddles.tscn -- things that appear during play are spawned, not authored.
##
## Script deliberately NOT attached here -- same load()-in---script-mode
## "Identifier not found: Game" issue every other generator in this folder
## already works around; attached as a plain ExtResource text edit after.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_sandbox_scene.gd

const SAND_COLOR := Color(0.82, 0.72, 0.52)
const BORDER_COLOR := Color(0.62, 0.38, 0.20)  ## WOOD_LIGHT, matches swing.tscn's own posts for a cohesive "playground kit" palette
const ROUGHNESS := 0.9

## PIT_HALF must match scripts/sandbox.gd's own PIT_HALF constant -- that
## script needs the pit's radius for its build-clamp math and this
## generator needs it for the visual footprint; two files, one authored
## number, same duplication-with-a-cross-reference-comment convention
## world_affordances.gd already uses against _bootstrap_courtyard.gd.
const PIT_HALF := 1.6
const PIT_DEPTH := 0.06
const BORDER_HEIGHT := 0.18
const BORDER_THICK := 0.12


func _init() -> void:
	var root := Node3D.new()
	root.name = "Sandbox"

	var sand_mat := _material(SAND_COLOR)
	var border_mat := _material(BORDER_COLOR)

	_box(root, root, "Pit", Vector3(0.0, PIT_DEPTH * 0.5, 0.0), Vector3(PIT_HALF * 2.0, PIT_DEPTH, PIT_HALF * 2.0), sand_mat)

	var outer := PIT_HALF + BORDER_THICK * 0.5
	_box(root, root, "BorderNorth", Vector3(0.0, BORDER_HEIGHT * 0.5, outer), Vector3(PIT_HALF * 2.0 + BORDER_THICK * 2.0, BORDER_HEIGHT, BORDER_THICK), border_mat)
	_box(root, root, "BorderSouth", Vector3(0.0, BORDER_HEIGHT * 0.5, -outer), Vector3(PIT_HALF * 2.0 + BORDER_THICK * 2.0, BORDER_HEIGHT, BORDER_THICK), border_mat)
	_box(root, root, "BorderEast", Vector3(outer, BORDER_HEIGHT * 0.5, 0.0), Vector3(BORDER_THICK, BORDER_HEIGHT, PIT_HALF * 2.0), border_mat)
	_box(root, root, "BorderWest", Vector3(-outer, BORDER_HEIGHT * 0.5, 0.0), Vector3(BORDER_THICK, BORDER_HEIGHT, PIT_HALF * 2.0), border_mat)

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/sandbox.tscn")
	if err != OK:
		printerr("Failed to save sandbox.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/sandbox.tscn")
	quit()


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = ROUGHNESS
	mat.metallic = 0.0
	return mat


func _box(parent: Node3D, scene_root: Node, box_name: String, position: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.surface_set_material(0, mat)
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	instance.owner = scene_root
