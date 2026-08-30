extends GdUnitTestSuite
## The tower's staircase must actually be built, actually reach the deck, and
## actually stand where the climb walks.
##
## Developer, 2026-08-30: "there should be a better way to climb up to the
## tower with the slide, than just via the slide itself". There already was a
## climb -- a 0.55 m trigger circle at a blank tower face -- and nothing at
## all was built for it, so the ascent read as a teleport and the slide
## looked like the only route. Same shape of test as
## test_slide_ride_on_the_plank.gd: the geometry the player walks
## (WorldAffordances) measured against the geometry that got generated
## (scenes/courtyard.tscn), never against itself.

var _courtyard: Node3D = null


func before_test() -> void:
	_courtyard = auto_free(load("res://scenes/courtyard.tscn").instantiate())
	add_child(_courtyard)


func test_three_flights_are_built_and_tile_without_a_gap() -> void:
	for index in range(WorldAffordances.STAIR_FLIGHTS):
		var flight := _flight(index)
		assert_object(flight).is_not_null()
		assert_vector(flight.position).is_equal_approx(WorldAffordances.stair_flight_origin(index), Vector3.ONE * 0.001)
		# Uniform, and exactly the module -- the kit model is a 1x1 m stair,
		# so this is what makes three of them land on a 2.875 m deck.
		assert_float(flight.scale.x).is_equal_approx(WorldAffordances.STAIR_MODULE, 0.001)
		assert_float(flight.scale.y).is_equal_approx(WorldAffordances.STAIR_MODULE, 0.001)


func test_the_staircase_climbs_from_the_ground_to_the_deck() -> void:
	var bounds := _stairs_bounds()
	# Starts on the ground, not floating above it.
	assert_float(bounds.position.y).is_equal_approx(0.0, 0.05)
	# Its treads reach deck height; the handrail carries on above, which is
	# what a handrail at the top of a flight does.
	assert_float(bounds.end.y).is_greater(WorldAffordances.PLATFORM_TOP_Y)
	assert_float(bounds.end.y).is_less(WorldAffordances.PLATFORM_TOP_Y + 0.6)
	# ...and it runs the full authored length, foot to deck edge.
	assert_float(bounds.position.x).is_equal_approx(WorldAffordances.STAIR_FOOT_X, 0.05)
	assert_float(bounds.end.x).is_equal_approx(WorldAffordances.STAIR_TOP_X, 0.05)


## The ramp player.gd walks up has to be the surface of the thing that got
## built, at both ends of it.
func test_the_climb_ramp_matches_the_built_staircase_at_both_ends() -> void:
	var bounds := _stairs_bounds()
	assert_float(WorldAffordances.stair_surface_y_at_x(bounds.position.x)).is_equal_approx(0.0, 0.02)
	assert_float(WorldAffordances.stair_surface_y_at_x(bounds.end.x)).is_equal_approx(WorldAffordances.PLATFORM_TOP_Y, 0.02)
	# And the top of the climb is level with the deck, not short of it or
	# hovering over it.
	assert_float(WorldAffordances.CLIMB_TOP.y).is_equal_approx(WorldAffordances.PLATFORM_TOP_Y, 0.001)


## Up one side, down the other. The stairs went on the tower's WEST flank
## precisely because the south face is the slide's; if a later change moves
## either onto the other, they occupy the same air and both stop working.
func test_the_staircase_does_not_stand_in_the_slide() -> void:
	var plank := _courtyard.find_child("SlidePlank", true, false) as MeshInstance3D
	assert_object(plank).is_not_null()
	var slide_bounds: AABB = plank.global_transform * plank.get_aabb()
	assert_bool(_stairs_bounds().intersects(slide_bounds)).is_false()


## The climb starts at the FOOT of the stairs -- walk into the bottom step
## and you go up. Before this it fired at a blank tower face several metres
## away from anything climbable.
func test_the_climb_trigger_sits_at_the_foot_of_the_stairs() -> void:
	var bounds := _stairs_bounds()
	assert_float(WorldAffordances.CLIMB_TRIGGER.y).is_equal_approx(0.0, 0.001)
	# Just off the bottom step: outside the staircase's own footprint (so
	# WorldBounds' collider for it cannot stop the player short of the
	# trigger) but within the trigger radius of it.
	var gap: float = bounds.position.x - WorldAffordances.CLIMB_TRIGGER.x
	assert_float(gap).is_greater(0.0)
	assert_float(gap).is_less(WorldAffordances.CLIMB_TRIGGER_RADIUS)
	# Lined up with the staircase's own width, not off to one side of it.
	assert_float(absf(WorldAffordances.CLIMB_TRIGGER.z - WorldAffordances.STAIR_Z)).is_less(WorldAffordances.STAIR_HALF_WIDTH)


func _flight(index: int) -> Node3D:
	return _courtyard.find_child("TowerStair%d" % index, true, false) as Node3D


## World-space AABB of everything the three flights are made of.
func _stairs_bounds() -> AABB:
	var total := AABB()
	var first := true
	for index in range(WorldAffordances.STAIR_FLIGHTS):
		for box in _mesh_bounds(_flight(index)):
			if first:
				total = box
				first = false
			else:
				total = total.merge(box)
	return total


func _mesh_bounds(node: Node) -> Array[AABB]:
	var out: Array[AABB] = []
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		out.append(mi.global_transform * mi.get_aabb())
	for child in node.get_children():
		out.append_array(_mesh_bounds(child))
	return out
