import io

p = r'godot/tools/_bootstrap_courtyard.gd'
s = io.open(p, encoding='utf-8').read()


def one(old, new):
    global s
    assert s.count(old) == 1, 'not unique: %r' % old[:80]
    s = s.replace(old, new)


# _mesh() returns the instance it built, so callers that need to name or tag it
# can, without a second lookup. Existing callers ignore the return unchanged.
one('func _mesh(root: Node3D, kind: String, position: Vector3, scale: Vector3, color: Color, rotation_rad: Vector3 = Vector3.ZERO, emissive: float = 0.0, surface: String = "") -> void:',
    'func _mesh(root: Node3D, kind: String, position: Vector3, scale: Vector3, color: Color, rotation_rad: Vector3 = Vector3.ZERO, emissive: float = 0.0, surface: String = "") -> MeshInstance3D:')
one('''		_:
			push_error("Unknown shape kind: %s" % kind)
			return''',
    '''		_:
			push_error("Unknown shape kind: %s" % kind)
			return null''')
one('''	instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	if textured and surface == "cloth":
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF''',
    '''	instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	if textured and surface == "cloth":
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance''')

# Ground slabs say whether they are walkable. Whether the child's feet can land
# on a surface is a fact only this file knows -- a test measuring the built
# scene can see that a slab is thin, wide and flat, but not that a kerb stops
# you standing in the bed it holds. Naming it here is that fact written down.
one('''## One flat ground patch. `top` is the surface height, so a caller writes
## the height it wants to see rather than a centre plus half a thickness.
func _ground(root: Node3D, cx: float, cz: float, w: float, d: float, top: float, color: Color, surface: String, rot_y: float = 0.0) -> void:
	const THICK := 0.16
	_mesh(root, "cube", Vector3(cx, top - THICK * 0.5, cz), Vector3(w, THICK, d), color, Vector3(0.0, rot_y, 0.0), 0.0, surface)''',
'''## One flat ground patch. `top` is the surface height, so a caller writes
## the height it wants to see rather than a centre plus half a thickness.
##
## `walkable` names what only this file knows: whether the child's feet can
## land on this patch. A walkable patch MUST top out at or below player.gd's
## locked_y or the child walks inside it (test_ground_datum.gd holds that
## line); a kerbed bed is deliberately proud and nobody stands in it. A test
## reading the built scene can see that a slab is thin, wide and flat, but not
## which of those two it is, so it is written down here rather than guessed.
func _ground(root: Node3D, cx: float, cz: float, w: float, d: float, top: float, color: Color, surface: String, rot_y: float = 0.0, walkable: bool = true) -> void:
	const THICK := 0.16
	var slab := _mesh(root, "cube", Vector3(cx, top - THICK * 0.5, cz), Vector3(w, THICK, d), color, Vector3(0.0, rot_y, 0.0), 0.0, surface)
	if slab != null:
		slab.name = "GroundWalkable" if walkable else "GroundRaised"''')

# The planting beds are the one raised patch: a kerb round them means you look
# into them, not stand in them.
one('	_ground(root, cx, cz, w, d, Y_SOIL, SOIL, "soil")',
    '	_ground(root, cx, cz, w, d, Y_SOIL, SOIL, "soil", 0.0, false)')

io.open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('ground slabs tagged')
