extends SceneTree
## One-shot generator: wires scenes/courtyard.tscn into scenes/main.tscn with
## a temporary static overview Camera3D, purely so M1.2's geometry can be
## screenshotted and visually sanity-checked before the real SpringArm3D
## camera rig lands in M1.4 (which will replace this temporary camera).
##
## Run with: godot --headless --path godot --script res://tools/_bootstrap_main_scene.gd

func _init() -> void:
	var root := Node3D.new()
	root.name = "Main"

	var courtyard_packed: PackedScene = load("res://scenes/courtyard.tscn")
	var courtyard: Node = courtyard_packed.instantiate()
	root.add_child(courtyard)
	courtyard.owner = root

	# TEMPORARY overview camera (M1.4 replaces this with the real SpringArm3D
	# rig driven by CameraProfile). High and pulled back so the whole
	# courtyard -- shell, playground, garden-wall gap, home threshold -- is
	# visible in one shot for a human sanity check.
	var cam := Camera3D.new()
	cam.name = "TempOverviewCamera"
	cam.transform = Transform3D.IDENTITY
	cam.look_at_from_position(Vector3(2.0, 14.0, 10.0), Vector3(0.0, 0.5, -3.0), Vector3.UP)
	cam.fov = 60.0
	root.add_child(cam)
	cam.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, "res://scenes/main.tscn")
	if err != OK:
		printerr("Failed to save main.tscn: ", err)
		quit(1)
		return
	print("Wrote scenes/main.tscn with courtyard + temp overview camera")
	quit()
