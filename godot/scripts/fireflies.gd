extends Node3D
## Verbatim port of scene.mjs's createFireflies() (lines 150-179): 12
## small emissive spheres orbiting the ball on individually-authored
## paths (not a real particle system -- the source scripts each of the
## 12 explicitly by index, so a stochastic particle emitter wouldn't
## reproduce it). Visible count and alpha driven by curiosity_glow,
## active only during FIND_BALL.

const MAX := 12
const SPHERE_RADIUS := 0.045
const GLOW_COLOR := Color(1.0, 0.761, 0.278)  # 0xffc247

var _spheres: Array = []
var _time: float = 0.0


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = SPHERE_RADIUS
	mesh.height = SPHERE_RADIUS * 2.0

	for i in range(MAX):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = GLOW_COLOR
		mat.emission_enabled = true
		mat.emission = GLOW_COLOR
		mat.emission_energy_multiplier = 1.8
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.set_surface_override_material(0, mat)
		mesh_instance.visible = false
		add_child(mesh_instance)
		_spheres.append(mesh_instance)


func _process(delta: float) -> void:
	_time += delta

	var intensity := 0.0
	if Game.director.state == EpisodeDirector.State.FIND_BALL:
		intensity = Game.lens.get_visuals()["curiosity_glow"]

	var ball_pos := Vector3.ZERO
	if is_instance_valid(Game.ball):
		ball_pos = Game.ball.global_position

	var count := 0
	if intensity > 0.0:
		count = int(3 + intensity * 9)

	for i in range(MAX):
		var sphere: MeshInstance3D = _spheres[i]
		if i >= count:
			sphere.visible = false
			continue

		sphere.visible = true
		var angle := _time * 0.7 + i * 2.17
		var radius := 0.65 + float(i % 4) * 0.22
		sphere.global_position = Vector3(
			ball_pos.x + cos(angle) * radius,
			ball_pos.y + 0.45 + sin(angle * 1.7 + i) * 0.35,
			ball_pos.z + sin(angle) * radius
		)

		var mat := sphere.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			var c := mat.albedo_color
			mat.albedo_color = Color(c.r, c.g, c.b, 0.55 + intensity * 0.4)
