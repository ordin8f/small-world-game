extends Node
## Gate 0: "splashing through a puddle should do something -- sound, a
## ripple, a visual beat. Cheap, high charm." WorldAffordances.PUDDLES are
## bootstrap's three decorative puddle discs, currently walked over like
## any other patch of ground. Pure poller (same pattern as
## stepping_stones.gd): detects entering a new puddle and fires a splash
## -- AudioDirector.play_splash() plus a short-lived expanding ring mesh
## spawned right at the puddle -- never a collision or navigation change.

const RING_LIFETIME := 0.55
const RING_START_SCALE := 0.9
const RING_END_SCALE := 5.0
const RING_COLOR := Color(0.82, 0.9, 0.95, 0.55)

## Exposed for tests: how many splashes have fired since this node loaded.
var splash_count: int = 0

var _last_puddle: int = -1
var _rings: Array = []  # [{"node": MeshInstance3D, "age": float}]


func _physics_process(delta: float) -> void:
	if is_instance_valid(Game.player):
		var p := Game.player.global_position
		var index := WorldAffordances.puddle_index_at(p.x, p.z)
		if index >= 0 and index != _last_puddle:
			_splash(index)
		_last_puddle = index

	_advance_rings(delta)


func _splash(index: int) -> void:
	splash_count += 1
	AudioDirector.play_splash()
	var puddle: Dictionary = WorldAffordances.PUDDLES[index]
	_spawn_ring(Vector3(puddle["x"], 0.03, puddle["z"]))


## A flat torus that scales up and fades over RING_LIFETIME -- the
## "visual beat" the brief asks for. One-shot and self-freeing, so a
## flurry of splashes never accumulates permanent nodes.
func _spawn_ring(pos: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.10
	mesh.outer_radius = 0.16

	var mat := StandardMaterial3D.new()
	mat.albedo_color = RING_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = RING_COLOR
	mat.emission_energy_multiplier = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = Vector3.ONE * RING_START_SCALE
	add_child(instance)
	_rings.append({"node": instance, "age": 0.0})


func _advance_rings(delta: float) -> void:
	var alive: Array = []
	for entry in _rings:
		entry["age"] += delta
		var t: float = entry["age"] / RING_LIFETIME
		var mesh_instance: MeshInstance3D = entry["node"]
		if t >= 1.0 or not is_instance_valid(mesh_instance):
			if is_instance_valid(mesh_instance):
				mesh_instance.queue_free()
			continue

		var s: float = lerpf(RING_START_SCALE, RING_END_SCALE, t)
		mesh_instance.scale = Vector3(s, 1.0, s)
		var mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, RING_COLOR.a * (1.0 - t))
		alive.append(entry)
	_rings = alive
