extends SceneTree
## Scratch probe: measures a vendored model's real shape, so a collider or a
## placement can be sized to what the model actually IS rather than to a
## guess. Two questions the AABB alone cannot answer:
##
##  - bench.gltf: how high is the SEAT (the AABB's top is the backrest), and
##    how deep/wide is the part a body actually occupies.
##  - stairs-wood-handrail.glb: which horizontal axis does it CLIMB, and what
##    is its rise over that run.
##
## Both are answered by slicing the mesh's vertices and reporting, per slice,
## the height reached and how much surface sits at each height.
##
## Run: godot --headless --path godot --script res://tools/_probe_prop_bounds.gd

const MODELS := [
	"res://assets/park/bench.gltf",
	"res://assets/kenney_town/stairs-wood-handrail.glb",
]


func _init() -> void:
	for path in MODELS:
		var packed: Resource = load(path)
		if packed == null or not (packed is PackedScene):
			printerr("could not load ", path)
			continue
		var root: Node = (packed as PackedScene).instantiate()
		print("\n== ", path)
		var verts: PackedVector3Array = PackedVector3Array()
		_collect(root, root as Node3D, verts)
		print("   vertices: ", verts.size())
		_height_histogram(verts)
		_axis_climb(verts, "x")
		_axis_climb(verts, "z")
		root.free()
	quit()


func _collect(n: Node, root: Node3D, out: PackedVector3Array) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var xf := root.global_transform.affine_inverse() * mi.global_transform
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var arrays := mi.mesh.surface_get_arrays(i)
				for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					out.append(xf * v)
	for c in n.get_children():
		_collect(c, root, out)


## How much of the model sits at each 5 cm height band, and how wide/deep
## that band is -- a seat shows up as a wide, deep band well below the top.
func _height_histogram(verts: PackedVector3Array) -> void:
	var bands := {}
	for v in verts:
		var key := int(floor(v.y / 0.05))
		if not bands.has(key):
			bands[key] = {"n": 0, "x0": INF, "x1": -INF, "z0": INF, "z1": -INF}
		var b: Dictionary = bands[key]
		b["n"] += 1
		b["x0"] = minf(b["x0"], v.x)
		b["x1"] = maxf(b["x1"], v.x)
		b["z0"] = minf(b["z0"], v.z)
		b["z1"] = maxf(b["z1"], v.z)
	var keys := bands.keys()
	keys.sort()
	print("   height bands (y0..y1  count  x-span  z-span):")
	for k in keys:
		var b: Dictionary = bands[k]
		print("     %.2f..%.2f  n=%4d  x %.2f..%.2f  z %.2f..%.2f" % [
			k * 0.05, k * 0.05 + 0.05, b["n"], b["x0"], b["x1"], b["z0"], b["z1"],
		])


## Max height reached in each 10 cm slice along `axis` -- a staircase climbs
## along whichever axis this rises monotonically on.
func _axis_climb(verts: PackedVector3Array, axis: String) -> void:
	var slices := {}
	for v in verts:
		var a: float = v.x if axis == "x" else v.z
		var key := int(floor(a / 0.1))
		slices[key] = maxf(slices.get(key, -INF), v.y)
	var keys := slices.keys()
	keys.sort()
	var line := "   max y per 0.1 slice along %s: " % axis
	for k in keys:
		line += "[%.1f]%.2f " % [k * 0.1, slices[k]]
	print(line)
