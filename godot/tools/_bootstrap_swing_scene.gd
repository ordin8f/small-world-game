extends SceneTree
## One-shot generator: builds scenes/swing.tscn -- a self-contained,
## position-parametrized playground swing (Gate 1: "swing and sandbox both
## need geometry that doesn't exist"). Two A-frames (four struts + a top
## bar) support a Pivot at the bar's own height; the Pivot carries two
## chains and a seat as ITS children, authored hanging straight down
## (theta=0). scripts/swing.gd only ever rotates Pivot.rotation.x at
## runtime (see scripts/logic/swing_math.gd for the pendulum step) -- the
## chains/seat's WORLD position/rotation fall out of Godot's own transform
## hierarchy rather than being hand-computed in the gameplay script, so
## dropping this whole scene at any position/rotation (main.tscn today, or
## wherever the world-expansion agent's map places it later) just works.
##
## Script deliberately NOT attached here -- same load()-in---script-mode
## "Identifier not found: Game" issue every other generator in this folder
## already works around; attached as a plain ExtResource text edit after.
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_swing_scene.gd

const WOOD := Color(0.34, 0.20, 0.12)
const WOOD_LIGHT := Color(0.62, 0.38, 0.20)
const ROUGHNESS := 0.88

## scripts/swing.gd does not need to know any of these -- it only reads
## $Pivot/Seat.global_position and rotates $Pivot -- so, unlike
## world_affordances.gd's numbers (re-derived from _bootstrap_courtyard.gd
## because player.gd's verb triggers need them too), nothing here has to
## stay in sync with a second file.
const TOP_BAR_HEIGHT := 2.15
const FRAME_HALF_WIDTH := 1.05
const LEG_BOTTOM_X_OUTSET := 0.35
const LEG_BOTTOM_Z := 0.5
const CHAIN_LENGTH := 1.55
const CHAIN_X_OFFSET := 0.11
const SEAT_SIZE := Vector3(0.34, 0.05, 0.26)
const POST_RADIUS := 0.07
const CHAIN_RADIUS := 0.018


func _init() -> void:
	var root := Node3D.new()
	root.name = "Swing"

	var post_mat := _material(WOOD_LIGHT)
	var chain_mat := _material(Color(0.3, 0.3, 0.32))
	var seat_mat := _material(WOOD)

	_strut(root, root, "TopBar", Vector3(-FRAME_HALF_WIDTH, TOP_BAR_HEIGHT, 0.0), Vector3(FRAME_HALF_WIDTH, TOP_BAR_HEIGHT, 0.0), POST_RADIUS, post_mat)

	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var side_name := "L" if side < 0.0 else "R"
		var top := Vector3(side * FRAME_HALF_WIDTH, TOP_BAR_HEIGHT, 0.0)
		var bottom_x: float = side * (FRAME_HALF_WIDTH + LEG_BOTTOM_X_OUTSET)
		_strut(root, root, "Leg%s_Front" % side_name, top, Vector3(bottom_x, 0.0, LEG_BOTTOM_Z), POST_RADIUS, post_mat)
		_strut(root, root, "Leg%s_Back" % side_name, top, Vector3(bottom_x, 0.0, -LEG_BOTTOM_Z), POST_RADIUS, post_mat)

	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)
	pivot.owner = root
	pivot.position = Vector3(0.0, TOP_BAR_HEIGHT, 0.0)

	for side in sides:
		var side_name := "L" if side < 0.0 else "R"
		_strut(pivot, root, "Chain%s" % side_name, Vector3(side * CHAIN_X_OFFSET, 0.0, 0.0), Vector3(side * CHAIN_X_OFFSET, -CHAIN_LENGTH, 0.0), CHAIN_RADIUS, chain_mat)

	var seat_mesh := BoxMesh.new()
	seat_mesh.size = SEAT_SIZE
	seat_mesh.surface_set_material(0, seat_mat)
	var seat := MeshInstance3D.new()
	seat.name = "Seat"
	seat.mesh = seat_mesh
	seat.position = Vector3(0.0, -CHAIN_LENGTH - SEAT_SIZE.y * 0.5, 0.0)
	pivot.add_child(seat)
	seat.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/swing.tscn")
	if err != OK:
		printerr("Failed to save swing.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/swing.tscn")
	quit()


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = ROUGHNESS
	mat.metallic = 0.0
	return mat


## Places a cylinder from `from` to `to` (both in `parent`'s local space),
## aligning the cylinder's own default long axis (local +Y) with that
## segment -- reused for the A-frame legs, the top bar, and the two
## chains, all of which are just "a cylinder between two points" at
## different radii. `scene_root` is the TRUE PackedScene root (matching
## _bootstrap_courtyard.gd's own _marker()/_wall_collider() convention):
## every node's .owner must be set to that exact node, not just any
## ancestor, or pack() silently drops it -- which matters here specifically
## because the two chain struts are parented under `pivot`, not `root`.
func _strut(parent: Node3D, scene_root: Node, strut_name: String, from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var length: float = from.distance_to(to)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 8
	mesh.surface_set_material(0, mat)

	var instance := MeshInstance3D.new()
	instance.name = strut_name
	instance.mesh = mesh
	instance.position = (from + to) * 0.5
	instance.basis = _align_y_to(to - from)
	parent.add_child(instance)
	instance.owner = scene_root


func _align_y_to(direction: Vector3) -> Basis:
	var d := direction.normalized()
	if d.is_equal_approx(Vector3.UP):
		return Basis.IDENTITY
	if d.is_equal_approx(-Vector3.UP):
		return Basis(Vector3.RIGHT, PI)
	var axis := Vector3.UP.cross(d).normalized()
	var angle := Vector3.UP.angle_to(d)
	return Basis(axis, angle)
