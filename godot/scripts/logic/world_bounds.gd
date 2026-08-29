class_name WorldBounds
extends RefCounted
## Verbatim port of src/world.mjs -- palette, static colliders, bounds check.
## Static utility class.

const PALETTE := {
	"plaster": [0.68, 0.62, 0.52],
	"plaster_light": [0.78, 0.71, 0.58],
	"ground": [0.36, 0.37, 0.29],
	"path": [0.66, 0.57, 0.40],
	"wood": [0.34, 0.20, 0.12],
	"wood_light": [0.62, 0.38, 0.20],
	"foliage": [0.18, 0.34, 0.22],
	"foliage_light": [0.34, 0.50, 0.28],
	"slide": [0.80, 0.30, 0.16],
	"chalk": [0.78, 0.76, 0.62],
	"puddle": [0.20, 0.32, 0.37],
	"shadow": [0.06, 0.07, 0.065],
	"warm_light": [1.0, 0.66, 0.28],
	"ball": [0.83, 0.53, 0.18],
}

## Each: {x, z, half_x, half_z, camera_blocks} -- an axis-aligned box on the
## ground plane. `camera_blocks` (default false if absent) puts the box on
## the dedicated camera-collision layer too -- see
## _bootstrap_courtyard.gd's _wall_collider() doc comment. Explicit per
## entry rather than an index cutoff (the old "first 3 entries" convention)
## now that the perimeter is a real multi-room shape instead of one box:
## an index cutoff silently miscategorizes the moment entries get
## reordered or inserted, an explicit flag can't.
##
## Four places (2026-08-28 world expansion -- see GODOT_REBUILD_PLAN.md's
## successor task, "expand the world"): HOME (porch/doorway, x[-7,7]
## z[8,16]) -> LANE (narrow walled passage, x[-3,3] z[-4,8]) -> PLAYGROUND
## (open, x[-16,16] z[-20,-4], stepping in to x[-16,11] for z in [-16,-4]
## where the garden sits alongside it) -> GARDEN POCKET, through the wall
## gap (x[11,22] z[-16,-4]). Each place's own doc block below explains its
## colliders; read can_move_to()'s bound as a loose outer safety net, not
## the real shape -- these boxes carve the actual irregular footprint out
## of it, same mechanism the old single-room version used for its interior
## obstacles, just doing more of the work now that there are four rooms
## instead of one.
const COLLIDERS := [
	# --- HOME: porch + doorway (x[-7,7], z[8,16]) ---------------------------
	# Side walls, z 8..14 -- the doorway piers below close z 14..16.
	{"x": -7.0, "z": 11.0, "half_x": 0.6, "half_z": 3.0, "camera_blocks": true},
	{"x": 7.0, "z": 11.0, "half_x": 0.6, "half_z": 3.0, "camera_blocks": true},
	# Doorway piers, flush with the side walls above (no gap between them --
	# unlike the old single-room version, home is now narrow enough that the
	# player can actually walk sideways into the piers' own footprint, so
	# unlike that version's "no collider, purely decorative" doorway these
	# need real collision). 2.4 m opening between them, matching the old gap.
	{"x": -4.1, "z": 15.0, "half_x": 2.9, "half_z": 1.0, "camera_blocks": true},
	{"x": 4.1, "z": 15.0, "half_x": 2.9, "half_z": 1.0, "camera_blocks": true},
	# Back cap just past the piers -- same role as the old single-room
	# version's z=12.3 cap (a real collider at the world's true edge so the
	# camera's spring arm respects it too, not just can_move_to()).
	{"x": 0.0, "z": 16.3, "half_x": 7.2, "half_z": 0.05, "camera_blocks": true},

	# --- LANE: narrow passage (x[-3,3], z[-4,8]) -----------------------------
	# The rendered walls are a thin pair at x=+-3 (see
	# _bootstrap_courtyard.gd) -- split into two colliders per side, unlike
	# every other room's walls, because the two jobs need different camera
	# treatment here:
	#   - a THIN pair matching the visible wall's own footprint, camera_blocks
	#     true like every other real wall (the camera must not clip through
	#     rendered geometry).
	#   - a WIDE, purely invisible flank beyond it, camera_blocks FALSE. Its
	#     job is sealing the gap between the lane and the wider rooms it
	#     connects (home at x[-7,7], playground at x[-16,16]) so a player
	#     can't walk around the outside of the lane's visible walls -- but
	#     there is nothing rendered out there for a camera to clip through,
	#     and REVEAL zone's 10.5 m distance genuinely needs to swing a
	#     damped camera through this airspace when the player is near the
	#     garden-gap route (x up to ~14) while still z-blended toward the
	#     lane. Marking this camera_blocks true (tried first) failed
	#     test_camera_never_in_geometry.gd for exactly that reason -- not a
	#     real clip, the spring arm colliding with an invisible volume no
	#     one would ever see. ART_DIRECTION.md's own "collision geometry
	#     substantially simpler than render geometry" is the same principle
	#     the original file's `camera_blocks` doc comment already argues
	#     from for small in-courtyard obstacles; this applies it to a much
	#     bigger invisible volume for the same reason. Extended out to +-30
	#     (well past every other room's own extent) purely so no seam with
	#     a neighboring room's wall can leave a sliver gap.
	{"x": -3.0, "z": 2.0, "half_x": 0.3, "half_z": 6.0, "camera_blocks": true},
	{"x": 3.0, "z": 2.0, "half_x": 0.3, "half_z": 6.0, "camera_blocks": true},
	{"x": -16.5, "z": 2.0, "half_x": 13.2, "half_z": 6.0},
	{"x": 16.5, "z": 2.0, "half_x": 13.2, "half_z": 6.0},

	# --- PLAYGROUND: open ground (x[-16,16], z[-20,-4]) ----------------------
	{"x": -16.0, "z": -12.0, "half_x": 0.6, "half_z": 8.0, "camera_blocks": true},
	# East wall only covers the DEEP end (z -20..-16) -- south of that, the
	# garden wall below (x=11) is the real east boundary, stepping the
	# playground's usable width in by 5 m where the garden sits alongside
	# it. Garden's own north wall closes the corner this step leaves open.
	{"x": 16.0, "z": -18.0, "half_x": 0.6, "half_z": 2.0, "camera_blocks": true},
	{"x": 0.0, "z": -20.0, "half_x": 16.6, "half_z": 0.6, "camera_blocks": true},
	# Towers (unchanged footprint/size from the single-room version, just
	# relocated -- WorldAffordances.TOWER_X/TOWER_Z mirror these).
	{"x": -3.4, "z": -12.8, "half_x": 1.35, "half_z": 1.35},
	{"x": 3.4, "z": -12.8, "half_x": 1.35, "half_z": 1.35},
	# Trees flanking the lane's home-side mouth (only one of the two
	# matching visual trees gets a collider, same asymmetry the old
	# single-room version had for its own near-home trees).
	{"x": -6.0, "z": 9.5, "half_x": 0.65, "half_z": 0.65},
	# Deep garden tree.
	{"x": 13.9, "z": -13.4, "half_x": 1.0, "half_z": 1.0},

	# --- GARDEN POCKET, through the wall gap (x[11,22], z[-16,-4]) ----------
	# West wall (the shared boundary with the playground) in two segments
	# with a 2 m gap between -- same "wall with one discoverable opening"
	# construction the single-room version used, just relocated from
	# x=5.4 to x=11 and widened in z to match the pocket's own z[-16,-4]
	# span. (This wall used to double as WorldAffordances' balance-verb
	# geometry too; that affordance has since moved to a garden-bed edging
	# by the home threshold -- see world_affordances.gd's own doc comment
	# -- so this remains purely a boundary from here on.)
	{"x": 11.0, "z": -12.5, "half_x": 0.35, "half_z": 3.5, "camera_blocks": true},
	{"x": 11.0, "z": -5.5, "half_x": 0.35, "half_z": 1.5, "camera_blocks": true},
	# North/south/east walls seal the pocket everywhere except that gap --
	# "the garden gap must still be the only way through" (brief). North
	# wall's x-span [11,22] deliberately overlaps the playground's own deep
	# east wall (x=16, above) at their shared z=-16 corner, so there is no
	# seam gap at that corner regardless of float rounding.
	{"x": 16.5, "z": -16.0, "half_x": 5.5, "half_z": 0.35, "camera_blocks": true},
	{"x": 16.5, "z": -4.0, "half_x": 5.5, "half_z": 0.35, "camera_blocks": true},
	{"x": 22.0, "z": -10.0, "half_x": 0.35, "half_z": 6.0, "camera_blocks": true},
]


static func circle_intersects_box(x: float, z: float, radius: float, box: Dictionary) -> bool:
	var nearest_x := LensMath.clamp_value(x, box["x"] - box["half_x"], box["x"] + box["half_x"])
	var nearest_z := LensMath.clamp_value(z, box["z"] - box["half_z"], box["z"] + box["half_z"])
	var dx := x - nearest_x
	var dz := z - nearest_z
	return dx * dx + dz * dz < radius * radius


## A loose outer envelope, not the real shape of the world -- see the
## COLLIDERS doc comment above. Covers home[-7,7]/lane[-3,3]/
## playground[-16,16]/garden[11,22]'s combined x extent and
## playground[-20]/home[16]'s combined z extent, with a small margin
## outside every room's own wall so this check never fires before the
## real perimeter colliders do.
static func can_move_to(x: float, z: float, radius: float = 0.32) -> bool:
	if x < -16.6 or x > 22.6 or z < -20.3 or z > 16.3:
		return false
	for box in COLLIDERS:
		if circle_intersects_box(x, z, radius, box):
			return false
	return true
