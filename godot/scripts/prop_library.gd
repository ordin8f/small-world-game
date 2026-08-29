class_name PropLibrary
extends RefCounted
## Named lookup from a prop KIND ("tree", "bush", "fence_post"...) to a
## vendored CC0 model, plus the scale factor that makes that model come out
## the size this world's primitives already are.
##
## Why this exists: tools/_bootstrap_courtyard.gd used to name one glTF file
## per call site (`_kind(..., "res://assets/park/tree_large.gltf", ...)`), so
## every tree in the world was the same tree and adding variety meant editing
## coordinates. Kinds are named here instead; call sites ask for "a tree" and
## get one.
##
## THE FALLBACK IS THE POINT. spawn() returns null -- and path_for() returns
## "" -- whenever the model cannot be used, for any of four reasons:
##   * USE_MODELS is false                 (this file's own fast-test switch)
##   * AssetMode.use_detailed() is false   (the project-wide setting)
##   * the kind has no model at all        (see KINDS_WITHOUT_MODELS below)
##   * the file is missing from disk       (partial checkout, deleted kit)
## Callers must therefore ALWAYS have a primitive fallback ready. A missing
## asset degrades to boxes and cones; it never breaks the scene.
##
## Scale convention: every kind declares the size in metres that a caller
## scale of 1.0 should produce, and every model declares its own native size
## on that axis. scale_for() divides one by the other. That is what stops a
## swapped model coming out ten times too big -- the native sizes below are
## measured from each vendored .glb's POSITION accessor bounds composed
## through its node transforms, not eyeballed.
##
## Most kinds therefore use a target of 1.0, which makes a caller's `s` read
## straight off as "size in metres on that axis" -- the natural thing to write
## at a call site that is placing one specific prop. "tree" (5.0) and "bush"
## (1.3) are the exceptions, and deliberately so: their callers already pass a
## per-item multiplier (1.1 .. 1.6 for trees) that predates this file, and
## those targets are what keep those existing numbers meaning what they meant
## when one hardcoded .gltf path was the only model.
##
## Models are VISUAL ONLY. Collision in this world comes exclusively from
## scripts/logic/world_bounds.gd via _add_wall_colliders(); none of the
## vendored .glb files contain a -col/-colonly node, so importing them adds
## no physics bodies. Nothing here should ever change that.

## Flip to false for primitive-only runs (fast iteration, or to see what the
## fallback path actually looks like) without touching ProjectSettings.
## AssetMode's own project-wide setting is honoured on top of this -- either
## one being false means primitives.
const USE_MODELS := true

const NATURE_DIR := "res://assets/kenney_nature/"
## Kenney Fantasy Town Kit 2.0 (CC0). Unlike the Nature Kit these are TEXTURED
## -- one embedded `colormap` atlas per model, no baseColorFactor -- so the
## sRGB/linear palette rewrite that assets/kenney_nature/ needed does not
## apply and must not be attempted on them. Their stock terracotta/stone/wood
## reads close enough to this world's own warm palette to sit beside it.
const TOWN_DIR := "res://assets/kenney_town/"

## Kinds the world asks for that have no vendored model, listed so the gap is
## explicit rather than a typo silently falling back:
##   slide        -- deliberately NOT modelled, and no CC0 slide exists to
##                   model it with. Its geometry is derived from
##                   WorldAffordances.PLATFORM_TOP_Y and SLIDE_END so the
##                   visual plank and the scripted ride can never drift apart
##                   (see _slide_plank()); a stock model would break that
##                   link, and the bed/rails it is built from are aligned to
##                   those same two authored points instead.
##   swing_frame  -- no CC0 playground kit exists on kenney.nl or
##                   quaternius.com; both catalogues were checked in full.
##                   The swing is also not this file's to change: it is its
##                   own scene (tools/_bootstrap_swing_scene.gd).
const KINDS_WITHOUT_MODELS := ["slide", "swing_frame"]

## kind -> {
##   "axis":   which native dimension "target" describes. Documentation for
##             the reader; the maths only uses the numbers in "models".
##   "target": size in metres a caller scale of 1.0 should produce.
##   "models": [[resource path, that model's native size on "axis"], ...]
## }
const KINDS := {
	# Six species where there was one repeated tree_large.gltf. Normalised to
	# 5.0 m so a caller's existing per-tree scale (1.1 .. 1.6) keeps meaning
	# exactly what it meant when tree_large.gltf (~5 m tall) was the only tree.
	"tree": {
		"axis": "height", "target": 5.0,
		"models": [
			[NATURE_DIR + "tree_default.glb", 1.71],
			[NATURE_DIR + "tree_oak.glb", 1.23],
			[NATURE_DIR + "tree_detailed.glb", 1.33],
			[NATURE_DIR + "tree_thin.glb", 1.49],
			[NATURE_DIR + "tree_plateau.glb", 1.25],
			[NATURE_DIR + "tree_tall.glb", 1.69],
		],
	},
	# Normalised on WIDTH, not height: a bush reads as a footprint of ground
	# cover. 1.3 m is _primitive_bush()'s own X scale, so the sphere it
	# replaces and the model cover the same patch of ground.
	"bush": {
		"axis": "width", "target": 1.3,
		"models": [
			[NATURE_DIR + "plant_bushDetailed.glb", 0.60],
			[NATURE_DIR + "plant_bush.glb", 0.40],
			[NATURE_DIR + "plant_bushLarge.glb", 0.37],
		],
	},
	# Already vendored before this pass (assets/nature/), kept here so every
	# kind resolves through one registry. target/native reproduce _add_rock()'s
	# own ROCK_NATIVE_WIDTH 0.48 division exactly.
	"rock": {
		"axis": "width", "target": 1.0,
		"models": [
			["res://assets/nature/rock_smallFlatA.glb", 0.48],
			["res://assets/nature/rock_smallFlatB.glb", 0.48],
			["res://assets/nature/rock_smallFlatC.glb", 0.48],
		],
	},
	# A 1 m panel, so a run of N panels spans N metres and callers can tile
	# them along an existing fence line without moving its endpoints.
	"fence_post": {
		"axis": "width", "target": 1.0,
		"models": [
			[NATURE_DIR + "fence_simple.glb", 1.00],
			[NATURE_DIR + "fence_planks.glb", 1.00],
		],
	},
	"planter": {
		"axis": "width", "target": 1.0,
		"models": [[NATURE_DIR + "pot_large.glb", 0.56]],
	},
	"flowerpot": {
		"axis": "width", "target": 1.0,
		"models": [[NATURE_DIR + "pot_small.glb", 0.32]],
	},
	"flower": {
		"axis": "height", "target": 1.0,
		"models": [
			[NATURE_DIR + "flower_redA.glb", 0.29],
			[NATURE_DIR + "flower_yellowA.glb", 0.19],
			[NATURE_DIR + "flower_purpleA.glb", 0.24],
		],
	},
	"grass_tuft": {
		"axis": "height", "target": 1.0,
		"models": [
			[NATURE_DIR + "grass.glb", 0.25],
			[NATURE_DIR + "grass_large.glb", 0.25],
		],
	},
	"stump": {
		"axis": "width", "target": 0.32,
		"models": [[NATURE_DIR + "stump_round.glb", 0.32]],
	},
	"log": {
		"axis": "width", "target": 0.71,
		"models": [[NATURE_DIR + "log.glb", 0.71]],
	},
	# Built structures, from the Fantasy Town Kit. Normalised on WIDTH because
	# each replaces a primitive whose footprint is the thing that has to match
	# -- a roof has to cap the tower it sits on, a door has to fill its opening.
	"roof_point": {
		"axis": "width", "target": 1.0,
		"models": [[TOWN_DIR + "roof-high-point.glb", 1.10]],
	},
	# Modular 1x1 m wall TILES, not standalone frames: 1 m square in Y/Z with
	# their ~0.1 m thickness along X, so a caller has to yaw them 90 degrees to
	# face a player approaching down -Z. `s` is their edge length in metres.
	"door": {
		"axis": "edge", "target": 1.0,
		"models": [[TOWN_DIR + "wall-door.glb", 1.00]],
	},
	"window": {
		"axis": "edge", "target": 1.0,
		"models": [[TOWN_DIR + "wall-window-shutters.glb", 1.00]],
	},
	# A staircase, used as the play tower's way up. Normalised on HEIGHT: what
	# matters is that it reaches the deck, and its tread depth follows.
	"stairs": {
		"axis": "height", "target": 1.0,
		"models": [[TOWN_DIR + "stairs-wood-handrail.glb", 1.45]],
	},
	# Tiny Treats props, authored at world scale already: native == target, so
	# scale_for() is the identity and callers keep passing 1.0 as they do now.
	"bench": {
		"axis": "width", "target": 1.0,
		"models": [["res://assets/park/bench.gltf", 1.0]],
	},
	"lamp_post": {
		"axis": "height", "target": 1.0,
		"models": [["res://assets/park/street_lantern.gltf", 1.0]],
	},
}


## True only when models are wanted at all -- this file's switch AND the
## project-wide setting. Kept separate from a missing FILE so callers can tell
## "primitives were asked for" from "an asset went missing", and warn loudly
## about only the second (see _bootstrap_courtyard.gd's _kind()).
static func models_enabled() -> bool:
	return USE_MODELS and AssetMode.use_detailed()


static func variant_count(kind: String) -> int:
	if not KINDS.has(kind):
		return 0
	return (KINDS[kind]["models"] as Array).size()


## Resource path for a kind's `variant`-th model, or "" when it cannot be
## used. `variant` wraps, so callers can pass a loop index or a position hash
## without bounds-checking it.
static func path_for(kind: String, variant: int = 0) -> String:
	if not models_enabled():
		return ""
	if not KINDS.has(kind):
		return ""
	var models: Array = KINDS[kind]["models"]
	if models.is_empty():
		return ""
	var entry: Array = models[posmod(variant, models.size())]
	var path: String = entry[0]
	if not ResourceLoader.exists(path):
		return ""
	return path


## The uniform scale that makes this kind's `variant`-th model come out `s` x
## its kind's target size. Returns 0.0 for an unknown kind, which a caller
## should never reach -- path_for() returns "" for the same input and sends
## them down the primitive branch first.
static func scale_for(kind: String, s: float = 1.0, variant: int = 0) -> float:
	if not KINDS.has(kind):
		return 0.0
	var models: Array = KINDS[kind]["models"]
	if models.is_empty():
		return 0.0
	var entry: Array = models[posmod(variant, models.size())]
	var native: float = entry[1]
	if native <= 0.0:
		return 0.0
	return float(KINDS[kind]["target"]) * s / native


## An instanced model for `kind`, already scaled so it is `s` x the kind's
## target size -- or null, which means "build your primitive instead". The
## caller owns positioning, rotation, naming and owner assignment.
static func spawn(kind: String, s: float = 1.0, variant: int = 0) -> Node3D:
	var path := path_for(kind, variant)
	if path == "":
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		return null
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return null
	inst.scale = Vector3.ONE * scale_for(kind, s, variant)
	return inst
